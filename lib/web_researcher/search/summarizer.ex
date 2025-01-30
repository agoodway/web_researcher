defmodule WebResearcher.Search.Summarizer do
  @moduledoc """
  Handles the parallel processing of search results, including page fetching,
  relevancy scoring, and final summary generation.
  """

  require Logger
  alias WebResearcher.{Config, Retriever, Summarizer, StructuredDataExtractor}
  alias WebResearcher.Search.Summary
  use Instructor

  @doc """
  Performs a web search, fetches and summarizes relevant pages, and generates a consolidated summary.
  """
  def search_web_and_summarize(query, opts \\ []) do
    search_results = Retriever.search_web(query, opts)

    with %WebResearcher.Search.Result{} = results <- search_results,
         true <- has_results?(results),
         # Fetch and summarize pages with relevancy scoring
         {:ok, page_summaries} <- fetch_and_summarize_pages(results.result_items, query, opts),
         # Filter out low relevancy pages
         {:ok, relevant_summaries} <- filter_by_relevancy(page_summaries, opts),
         # Generate the consolidated summary
         {:ok, final_summary} <- generate_consolidated_summary(relevant_summaries, query, opts) do
      {:ok, final_summary}
    else
      false -> {:error, "No search results found"}
      {:error, reason} -> {:error, format_error(reason)}
      error -> {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp has_results?(%{result_items: items}) when is_list(items) and length(items) > 0, do: true
  defp has_results?(_), do: false

  defp fetch_and_summarize_pages(result_items, query, opts)
       when is_list(result_items) and length(result_items) > 0 do
    task_config = Config.get_task_config()

    # Get max results from config or opts
    max_results = Keyword.get(opts, :max_search_results, Config.max_search_results())

    # Sort by score (if available) and take top results
    top_results =
      result_items
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(max_results)

    # Add search query to options for relevancy scoring
    summarize_opts = Keyword.put(opts, :search_query, query)

    top_results
    |> Task.async_stream(
      fn item ->
        try do
          with {:ok, webpage} <- Retriever.fetch_page(item.url),
               {:ok, summary} <- Summarizer.summarize(webpage, summarize_opts) do
            # Extract structured data from the summary
            structured_data = StructuredDataExtractor.extract_structured_data(summary.summary)

            {:ok,
             Map.merge(summary, %{
               url: item.url,
               page_age: item.page_age,
               source_name: item.source_name,
               structured_data: structured_data
             })}
          else
            {:error, reason} ->
              {:error, "Failed to process #{item.url}: #{inspect(reason)}"}

            error ->
              {:error, "Unexpected error processing #{item.url}: #{inspect(error)}"}
          end
        rescue
          e -> {:error, "Exception processing #{item.url}: #{Exception.message(e)}"}
        catch
          :exit, {:timeout, _} -> {:error, "Timeout processing #{item.url}"}
          _, reason -> {:error, "Caught error processing #{item.url}: #{inspect(reason)}"}
        end
      end,
      ordered: false,
      timeout: task_config.timeout,
      max_concurrency: task_config.max_concurrency,
      on_timeout: :kill_task
    )
    |> collect_results()
    |> case do
      {:ok, []} -> {:error, "No pages were successfully processed"}
      other -> other
    end
  end

  defp fetch_and_summarize_pages(_result_items, _query, _opts) do
    {:error, "Invalid or empty result items"}
  end

  defp filter_by_relevancy(summaries, opts) do
    threshold = Keyword.get(opts, :relevancy_threshold, 0.6)

    filtered =
      Enum.filter(summaries, fn summary ->
        summary.relevancy_score >= threshold
      end)

    {:ok, filtered}
  end

  defp generate_consolidated_summary(summaries, query, _opts) do
    # Sort summaries by relevancy score in descending order
    sorted_summaries = Enum.sort_by(summaries, & &1.relevancy_score, :desc)

    # Extract all keywords and themes
    all_keywords =
      summaries
      |> Enum.flat_map(& &1.keywords)
      |> Enum.uniq()

    # Create individual page summaries as maps for embedding
    page_summaries =
      Enum.map(sorted_summaries, fn summary ->
        %{
          url: summary.url,
          title: Map.get(summary, :title),
          summary: summary.summary,
          page_age: summary.page_age,
          source_name: summary.source_name,
          relevancy_score: summary.relevancy_score,
          relevancy_explanation: summary.relevancy_explanation,
          key_matches: summary.key_matches
        }
      end)

    # Extract structured data
    structured_data = Enum.flat_map(sorted_summaries, &(&1.structured_data || []))

    # Create the search summary struct
    attrs = %{
      summary: Enum.map_join(sorted_summaries, "\n\n", & &1.summary),
      query: query,
      total_pages_found: length(summaries),
      total_pages_summarized: length(sorted_summaries),
      key_themes: all_keywords,
      contradictions: [],
      confidence_score:
        Enum.reduce(sorted_summaries, 0, &(&1.relevancy_score + &2)) / length(sorted_summaries),
      individual_summaries: page_summaries,
      structured_data: structured_data
    }

    case Summary.changeset(%Summary{}, attrs) do
      %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      %{valid?: false} = changeset -> {:error, changeset}
    end
  end

  defp collect_results(stream) do
    try do
      results =
        stream
        |> Enum.reduce([], fn
          {:ok, {:ok, result}}, acc ->
            [result | acc]

          {:ok, {:error, _reason}}, acc ->
            # Logger.warning("Failed to process page: #{inspect(reason)}")
            acc

          {:exit, _reason}, acc ->
            # Logger.warning("Task exited: #{inspect(reason)}")
            acc

          _, acc ->
            acc
        end)
        |> Enum.reverse()

      case results do
        [] -> {:error, "No successful results"}
        results -> {:ok, results}
      end
    catch
      :exit, {:timeout, _} = reason ->
        Logger.error("Timeout while collecting results: #{inspect(reason)}")
        {:error, "Operation timed out while processing pages"}

      _kind, reason ->
        Logger.error("Error collecting results: #{inspect(reason)}")
        {:error, "Failed to process search results: #{inspect(reason)}"}
    end
  end

  # Format error messages for better user experience
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%{errors: errors}) when is_list(errors), do: format_validation_errors(errors)
  defp format_error(reason), do: "Error: #{inspect(reason)}"

  defp format_validation_errors(errors) do
    errors
    |> Enum.map(fn
      {field, {_msg, [validation: :length, count: count]}} when field == :summary ->
        "Summary is too short. Required minimum length: #{count} characters"

      {field, {_msg, [validation: :length]}} when field == :key_themes ->
        "At least one key theme is required"

      {:confidence_score, {_msg, _opts}} ->
        "Invalid confidence score. Must be between 0.0 and 1.0"

      {field, {msg, _opts}} ->
        "#{field}: #{msg}"

      {field, msg} when is_binary(msg) ->
        "#{field}: #{msg}"

      error ->
        inspect(error)
    end)
    |> Enum.join(", ")
  end
end
