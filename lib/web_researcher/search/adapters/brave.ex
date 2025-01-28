defmodule WebResearcher.Search.Adapters.Brave do
  @moduledoc """
  Brave Search adapter with support for native summarization.
  Implements search with optional AI-powered summaries via Brave's API.
  """
  @behaviour WebResearcher.Search.Adapter

  alias WebResearcher.Search.ResultItem
  require Logger
  import Ecto.Changeset, only: [apply_changes: 1]

  @brave_search_url "https://api.search.brave.com/res/v1/web/search"
  @brave_summarizer_url "https://api.search.brave.com/res/v1/summarizer/search"

  @impl true
  def provider_name, do: "brave"

  @impl true
  def supports_summarization?, do: true

  @impl true
  def search(query, opts \\ []) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, search_response} <- do_search(query, api_key, opts) do
      case get_summarization_type(opts) do
        :provider ->
          with {:ok, summarizer_key} <- extract_summarizer_key(search_response),
               {:ok, summary_response} <- get_summary(summarizer_key, api_key) do
            parse_response(search_response, summary_response)
          end

        _ ->
          # For :none or :app, just return the search results
          parse_response(search_response, nil)
      end
    end
  end

  defp do_search(query, api_key, opts) do
    count = Keyword.get(opts, :limit, 20)
    summarize = get_summarization_type(opts) == :provider

    headers = [
      {"Accept", "application/json"},
      {"Accept-Encoding", "gzip"},
      {"X-Subscription-Token", api_key},
      {"User-Agent", get_user_agent()},
      {"Cache-Control", "no-cache"}
    ]

    params = %{
      q: query,
      count: count,
      summary: if(summarize, do: 1, else: 0)
    }

    case Req.get(@brave_search_url, headers: headers, params: params) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status} = response} ->
        Logger.error("Brave search failed with status #{status}: #{inspect(response)}")
        {:error, response}

      {:error, reason} ->
        Logger.error("Brave search request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_summary(summarizer_key, api_key) do
    headers = [
      {"Accept", "application/json"},
      {"Accept-Encoding", "gzip"},
      {"X-Subscription-Token", api_key},
      {"User-Agent", get_user_agent()}
    ]

    params = %{
      key: summarizer_key,
      entity_info: 1
    }

    case Req.get(@brave_summarizer_url, headers: headers, params: params) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_summarizer_key(%{"summarizer" => %{"key" => key}}), do: {:ok, key}
  defp extract_summarizer_key(_), do: {:error, :no_summarizer_key}

  defp parse_response(%{"web" => %{"results" => results}} = search_response, summary_response) do
    parsed_results =
      results
      |> Enum.with_index(1)
      |> Enum.map(fn {result, index} ->
        attrs = %{
          title: result["title"],
          description: result["description"],
          url: result["url"],
          page_age: result["age"],
          rank: index,
          language: result["language"],
          family_friendly: result["family_friendly"],
          provider_metadata: build_metadata(result, summary_response)
        }

        case ResultItem.changeset(%ResultItem{}, attrs) do
          %{valid?: true} = changeset -> apply_changes(changeset)
          invalid -> {:error, invalid}
        end
      end)

    case Enum.split_with(parsed_results, &match?(%ResultItem{}, &1)) do
      {valid_results, []} ->
        total_results = search_response["web"]["total"] || length(valid_results)

        metadata = %{
          query: search_response["query"],
          mixed: search_response["mixed"],
          type: search_response["type"],
          language: search_response["language"],
          summary: extract_summary_metadata(summary_response)
        }

        {:ok, {valid_results, total_results, metadata}}

      {_valid, invalid} ->
        {:error, {:invalid_results, invalid}}
    end
  end

  defp parse_response(response, _), do: {:error, {:invalid_response, response}}

  defp build_metadata(result, summary_response) do
    base_metadata = %{
      deep_results: result["deep_results"]
    }

    if summary_response do
      Map.put(base_metadata, :summary_info, extract_summary_info(summary_response, result["url"]))
    else
      base_metadata
    end
  end

  defp extract_summary_info(%{"entities_infos" => entities_infos}, url) do
    # Extract entity info relevant to this URL
    entities_infos
    |> Enum.filter(fn {_key, info} ->
      info["url"] == url
    end)
    |> Map.new()
  end

  defp extract_summary_info(_, _), do: %{}

  defp extract_summary_metadata(%{
         "title" => title,
         "summary" => summary,
         "enrichments" => enrichments,
         "followups" => followups
       }) do
    %{
      title: title,
      summary: summary,
      enrichments: enrichments,
      followups: followups
    }
  end

  defp extract_summary_metadata(_), do: %{}

  defp get_api_key do
    case Application.get_env(:web_researcher, :brave_api_key) do
      nil ->
        case System.get_env("BRAVE_API_KEY") do
          nil -> {:error, :missing_brave_api_key}
          key -> {:ok, key}
        end

      {:system, var} ->
        case System.get_env(var) do
          nil -> {:error, :missing_brave_api_key_env_var}
          key -> {:ok, key}
        end

      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, key}

      _ ->
        {:error, :invalid_brave_api_key}
    end
  end

  defp get_user_agent do
    "WebResearcher/1.0 (Elixir; +https://github.com/your-username/web_researcher)"
  end

  defp get_summarization_type(opts) do
    case Keyword.get(opts, :summarize, :none) do
      # For backward compatibility
      true -> :provider
      # For backward compatibility
      false -> :none
      type when type in [:none, :provider, :app] -> type
      _ -> :none
    end
  end
end
