defmodule WebResearcher do
  @moduledoc """
  Documentation for `WebResearcher`.
  """

  alias WebResearcher.Search.Summarizer

  @doc """
  Fetches a webpage and returns a WebPage struct
  """
  def fetch_page(url, opts \\ []) do
    WebResearcher.Retriever.fetch_page(url, opts)
  end

  @doc """
  Fetches a webpage and generates an LLM-powered summary
  """
  def fetch_page_and_summarize(url, opts \\ []) do
    WebResearcher.Summarizer.fetch_page_and_summarize(url, opts)
  end

  @doc """
  Performs a web search and returns search results
  """
  def search_web(search_term, opts \\ []) do
    case WebResearcher.Retriever.search_web(search_term, opts) do
      %WebResearcher.Search.Result{} = result -> {:ok, result}
      error -> error
    end
  end

  @doc """
  Performs a web search and fetches each result page
  """
  def search_web_and_fetch_pages(search_term, opts \\ []) do
    case WebResearcher.Retriever.search_web_and_fetch_pages(search_term, opts) do
      %WebResearcher.Search.Result{} = result -> {:ok, result}
      error -> error
    end
  end

  @doc """
  Performs a web search, fetches and summarizes relevant pages, and generates a consolidated summary.

  ## Options
    * `:relevancy_threshold` - Minimum relevancy score (0.0-1.0) for pages to be included (default: 0.6)
    * `:model` - The LLM model to use (defaults to config value)
    * `:max_retries` - Number of retries for LLM calls (defaults to config value)
    * `:timeout` - Timeout for parallel operations in milliseconds (default: 10_000)
    * `:max_concurrency` - Maximum number of concurrent tasks (default: system schedulers)
    * Any other options supported by the search adapter

  ## Returns
    * `{:ok, search_summary}` - A Search.Summary struct containing:
      - Comprehensive summary of all relevant pages
      - Individual page summaries with relevancy scores
      - Structured data extracted from pages
      - Key themes and contradictions found
      - Source quality assessment
      - Overall confidence score
    * `{:error, reason}` - If the search or summarization fails

  ## Example
      iex> WebResearcher.search_web_and_summarize("elixir concurrency patterns")
      {:ok, %Search.Summary{
        summary: "Comprehensive overview of Elixir concurrency...",
        total_pages_found: 10,
        total_pages_summarized: 6,
        confidence_score: 0.85,
        ...
      }}
  """
  def search_web_and_summarize(search_term, opts \\ []) do
    Summarizer.search_web_and_summarize(search_term, opts)
  end
end
