defmodule WebResearcher.Retriever do
  @moduledoc false

  alias WebResearcher.Retriever.{Req, Playwright, Response}
  alias WebResearcher.WebPage
  alias WebResearcher.Search.Result
  require Logger

  @doc """
  Fetches a webpage using Req first, falling back to Playwright if needed.
  Returns {:ok, %WebPage{}} on success or {:error, term()} on failure.

  ## Configuration

  The Playwright fallback can be disabled by setting the following in your config:

      config :web_researcher, :use_playwright, false

  It can also be overridden per-request by passing the `:use_playwright` option:

      WebResearcher.Retriever.fetch_page(url, use_playwright: false)
  """
  def fetch_page(url, opts \\ []) do
    case fetch_with_req(url, opts) do
      {:ok, :needs_playwright} ->
        if playwright_enabled?(opts) do
          Logger.info(
            "WebResearcher - Content appears to be a SPA/dynamic page, using Playwright for #{url}"
          )

          fetch_with_playwright(url, opts)
        else
          Logger.info(
            "WebResearcher - Content appears to be a SPA/dynamic page but Playwright is disabled"
          )

          {:error, :playwright_disabled}
        end

      {:ok, response} ->
        WebPage.from_response(url, response)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Performs a web search using the configured search adapter.
  Returns {:ok, %Search.Result{}} containing just the search results.

  ## Options

    * `:adapter` - The search adapter to use (defaults to configured adapter)
    * `:limit` - Maximum number of search results to return (default: 10)
    * Any other options are passed to the search adapter

  ## Example

      iex> WebResearcher.Retriever.search_web("elixir programming", limit: 5)
      {:ok, %Search.Result{query: "elixir programming", total_results: 5, result_items: [...]}}
  """
  def search_web(query, opts \\ []) do
    adapter = get_search_adapter(opts)
    limit = Keyword.get(opts, :limit, 10)

    with {:ok, {results, total, metadata}} <-
           adapter.search(query, Keyword.put(opts, :limit, limit)) do
      Result.new(%{
        query: query,
        total_results: total,
        provider: adapter.provider_name(),
        provider_metadata: metadata,
        result_items: results,
        pages: []
      })
    end
  end

  @doc """
  Performs a web search and fetches each result page in parallel.
  Returns {:ok, %Search.Result{}} containing both search results and fetched pages.

  ## Options

    * `:adapter` - The search adapter to use (defaults to configured adapter)
    * `:limit` - Maximum number of search results to return (default: 10)
    * `:timeout` - Timeout for parallel page fetching in milliseconds (default: 10_000)
    * Any other options are passed to both the search adapter and page fetcher

  ## Example

      iex> WebResearcher.Retriever.search_web_and_fetch_pages("elixir programming", limit: 5)
      {:ok, %Search.Result{query: "elixir programming", total_results: 5, result_items: [...], pages: [...]}}
  """
  def search_web_and_fetch_pages(query, opts \\ []) do
    adapter = get_search_adapter(opts)

    timeout =
      Keyword.get(opts, :timeout, Application.get_env(:web_researcher, :task_timeout, 10_000))

    max_concurrency =
      Keyword.get(
        opts,
        :max_concurrency,
        Application.get_env(:web_researcher, :max_concurrency, System.schedulers_online())
      )

    limit = Keyword.get(opts, :limit, 10)

    with {:ok, {results, total, metadata}} <-
           adapter.search(query, Keyword.put(opts, :limit, limit)) do
      # Fetch all pages in parallel and associate with their result items
      results_with_pages =
        Task.Supervisor.async_stream_nolink(
          WebResearcher.TaskSupervisor,
          results,
          fn result ->
            try do
              case fetch_page(result.url) do
                {:ok, page} ->
                  # Convert the page to a map for embedding
                  page_map = Map.from_struct(page)
                  Map.put(result, :web_page, page_map)

                {:error, _} ->
                  result
              end
            rescue
              _e ->
                # Logger.error("Failed to fetch page #{result.url}: #{inspect(e)}")
                result
            end
          end,
          ordered: true,
          timeout: timeout,
          on_timeout: :kill_task,
          max_concurrency: max_concurrency
        )
        |> Enum.reduce([], fn
          {:ok, result}, acc -> [result | acc]
          _, acc -> acc
        end)
        |> Enum.reverse()

      # Return the search result with pages embedded in result items
      Result.new(%{
        query: query,
        total_results: total,
        provider: adapter.provider_name(),
        provider_metadata: metadata,
        result_items: results_with_pages
      })
    end
  end

  defp get_search_adapter(opts) do
    Keyword.get(opts, :adapter) ||
      Application.get_env(:web_researcher, :search_adapter, WebResearcher.Search.Adapters.SearXNG)
  end

  defp playwright_enabled?(opts) do
    Keyword.get(
      opts,
      :use_playwright,
      Application.get_env(:web_researcher, :use_playwright, true)
    )
  end

  defp fetch_with_req(url, opts) do
    case Req.get(url, opts) do
      {:error, %Response{status: :failed, content: nil}} ->
        Logger.warning("WebResearcher - Failed to fetch: #{url}")
        {:error, :fetch_failed}

      {:error, %Response{status: 429}} ->
        Logger.warning(
          "WebResearcher - Rate limited by #{url}, consider adding delay between requests"
        )

        {:error, :rate_limited}

      {:error, %Response{status: status}} when status in [403, 401] ->
        Logger.warning("WebResearcher - Access denied (#{status}) for #{url}")
        {:error, :access_denied}

      {:ok, %Response{content: content} = response} when is_binary(content) ->
        if use_playwright?(content) do
          {:ok, :needs_playwright}
        else
          {:ok, response}
        end

      error ->
        error
    end
  end

  defp fetch_with_playwright(url, opts) do
    case Playwright.get(url, opts) do
      {:ok, response} ->
        WebPage.from_response(url, response)

      {:error, _} = error ->
        Logger.error("WebResearcher - Playwright request failed #{inspect(error)}.")
        error
    end
  end

  # Detect if content likely needs JavaScript rendering
  defp use_playwright?(content) do
    cond do
      # Empty or near-empty body content
      !content || String.length(content) < 50 ->
        true

      has_empty_root_div?(content) ->
        true

      is_likely_spa?(content) ->
        true

      true ->
        false
    end
  end

  # Detect if content is likely a SPA (single-page application)
  defp is_likely_spa?(content) do
    indicators = [
      # React root
      ~r/<div\s+id=["']root["']\s*>/i,
      # Vue/general SPA root
      ~r/<div\s+id=["']app["']\s*>/i,
      # Bundled JS
      ~r/<script[^>]*src=["'][^"']*bundle\.js["']/i,
      # Chunked JS (webpack)
      ~r/<script[^>]*src=["'][^"']*chunk\.js["']/i,
      # Redux/state management
      ~r/window\.__INITIAL_STATE__/,
      # Nuxt.js
      ~r/window\.__NUXT__/,
      # Hashed bundles
      ~r/<script[^>]*src=["'][^"']*main\.[a-f0-9]+\.js["']/i
    ]

    Enum.any?(indicators, &Regex.match?(&1, content))
  end

  # Check for empty root div (common in React/Vue apps)
  defp has_empty_root_div?(content) do
    case Regex.run(~r/<div\s+id=["'](root|app)["'][^>]*>([\s\n]*)<\/div>/i, content) do
      [_, _, inner] -> String.trim(inner) == ""
      _ -> false
    end
  end
end
