defmodule WebResearcher do
  @moduledoc """
  Documentation for `WebResearcher`.
  """

  @doc """
  Fetches a webpage and returns a WebPage struct
  """
  def get(url, opts \\ []) do
    WebResearcher.Retriever.get(url, opts)
  end
end
