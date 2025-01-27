defmodule WebResearcher do
  @moduledoc """
  Documentation for `WebResearcher`.
  """

  @doc """
  Fetches a webpage and returns a WebPage struct
  """
  def fetch_page(url, opts \\ []) do
    WebResearcher.Retriever.fetch(url, opts)
  end
end
