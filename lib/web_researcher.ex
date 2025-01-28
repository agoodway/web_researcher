defmodule WebResearcher do
  @moduledoc """
  Documentation for `WebResearcher`.
  """

  @doc """
  Fetches a webpage and returns a WebPage struct
  """
  def fetch_page(url, opts \\ []) do
    WebResearcher.Retriever.fetch_page(url, opts)
  end

  def fetch_page_and_summarize(url, opts \\ []) do
    WebResearcher.Summarizer.fetch_page_and_summarize(url, opts)
  end

  def search_web(search_term, opts \\ []) do
    WebResearcher.Retriever.search_web(search_term, opts)
  end

  def search_web_and_fetch_pages(search_term, opts \\ []) do
    WebResearcher.Retriever.search_web_and_fetch_pages(search_term, opts)
  end
end
