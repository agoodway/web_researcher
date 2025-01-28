defmodule WebResearcher.Search.Adapters.SearXNG do
  @moduledoc """
  SearXNG search adapter implementation.

  ## Configuration

  The following configuration options are available:

      config :web_researcher, :searxng,
        base_url: "https://searx.be",
        timeout: 10_000,
        format: "json",
        language: "en",
        safesearch: 1,
        categories: "general",
        engines: "duckduckgo,brave,google,bing,qwant,mojeek",
        headers: [
          {"User-Agent", "WebResearcher/1.0.0"}
        ]

  Options can also be overridden per-request:

      WebResearcher.search_web("query", adapter: WebResearcher.Search.Adapters.SearXNG,
        language: "fr", safesearch: 0)
  """

  @behaviour WebResearcher.Search.Adapter

  alias WebResearcher.Search.ResultItem
  import Ecto.Changeset, only: [apply_changes: 1]

  @impl true
  def provider_name, do: "SearXNG"

  @impl true
  def supports_summarization?, do: false

  @impl true
  def search(query, opts \\ []) do
    config = get_config(opts)
    url = build_url(config.base_url, query, config)

    case Req.get(url, headers: config.headers, receive_timeout: config.timeout) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body, query)

      {:ok, %{status: status}} ->
        {:error, "Search failed with status #{status}"}

      {:error, error} ->
        {:error, "Search request failed: #{inspect(error)}"}
    end
  end

  defp get_config(opts) do
    base_config = Application.get_env(:web_researcher, :providers, [])
    searxng_config = get_in(base_config, [:searxng]) || []

    %{
      base_url:
        Keyword.get(
          opts,
          :base_url,
          Keyword.get(searxng_config, :base_url, "http://localhost:8080")
        ),
      timeout: Keyword.get(opts, :timeout, Keyword.get(searxng_config, :timeout, 10_000)),
      format: Keyword.get(opts, :format, Keyword.get(searxng_config, :format, "json")),
      language: Keyword.get(opts, :language, Keyword.get(searxng_config, :language, "en")),
      safesearch: Keyword.get(opts, :safesearch, Keyword.get(searxng_config, :safesearch, 1)),
      categories:
        Keyword.get(opts, :categories, Keyword.get(searxng_config, :categories, "general")),
      engines:
        Keyword.get(
          opts,
          :engines,
          Keyword.get(searxng_config, :engines, "duckduckgo,brave,google,bing,qwant,mojeek")
        ),
      headers:
        Keyword.get(
          opts,
          :headers,
          Keyword.get(searxng_config, :headers, default_headers())
        )
    }
  end

  defp default_headers do
    [
      {"User-Agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"},
      {"Accept", "application/json"},
      {"Accept-Language", "en-US,en;q=0.9"},
      {"Accept-Encoding", "gzip, deflate"},
      {"Connection", "keep-alive"},
      {"Cache-Control", "no-cache"},
      {"Pragma", "no-cache"}
    ]
  end

  defp build_url(base_url, query, config) do
    params = [
      q: query,
      format: config.format,
      language: config.language,
      safesearch: config.safesearch,
      categories: config.categories,
      engines: config.engines
    ]

    uri = URI.parse(base_url)
    query_string = URI.encode_query(params)

    "#{uri}/search?#{query_string}"
  end

  defp parse_response(%{"results" => results, "answers" => answers} = response, _query) do
    # Convert results to our common format
    parsed_results =
      results
      |> Enum.with_index(1)
      |> Enum.map(fn {result, index} ->
        attrs = %{
          title: result["title"],
          description: result["content"],
          url: result["url"],
          page_age: result["publishedDate"],
          rank: index,
          language: result["language"],
          family_friendly: true,
          provider_metadata: %{
            category: result["category"],
            engines: result["engines"],
            positions: result["positions"],
            score: result["score"],
            template: result["template"],
            parsed_url: result["parsed_url"],
            engine: result["engine"]
          },
          thumbnail_url: result["thumbnail"],
          source_name: result["engine"],
          source_favicon: nil,
          category: result["category"],
          score: result["score"],
          position: List.first(result["positions"]),
          content_type: nil,
          extra_snippets: answers,
          source_engines: result["engines"]
        }

        case ResultItem.changeset(%ResultItem{}, attrs) do
          %{valid?: true} = changeset -> apply_changes(changeset)
          invalid -> {:error, invalid}
        end
      end)

    case Enum.split_with(parsed_results, &match?(%ResultItem{}, &1)) do
      {valid_results, []} ->
        metadata = %{
          unresponsive_engines: response["unresponsive_engines"],
          suggestions: response["suggestions"],
          corrections: response["corrections"],
          infoboxes: response["infoboxes"]
        }

        {:ok, {valid_results, length(results), metadata}}

      {_valid, invalid} ->
        {:error, {:invalid_results, invalid}}
    end
  end

  defp parse_response(_, _) do
    {:error, "Invalid response format"}
  end
end
