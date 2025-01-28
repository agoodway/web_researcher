defmodule WebResearcher.Search.Adapter do
  @moduledoc """
  Behaviour for implementing search engine adapters.
  Defines the contract for search operations and summarization capabilities.
  """

  alias WebResearcher.Search.ResultItem

  @type search_opts :: keyword()
  @type summarization_type :: :none | :provider | :app

  @doc """
  Performs a search and returns results with metadata.
  Options are adapter-specific but commonly include:
    * `:limit` - Maximum results to return
    * `:summarize` - Summarization type (:none, :provider, :app)
  """
  @callback search(query :: String.t(), opts :: search_opts()) ::
              {:ok, {[ResultItem.t()], total_results :: non_neg_integer(), metadata :: map()}}
              | {:error, term()}

  @doc """
  Returns the unique identifier for this search provider.
  """
  @callback provider_name() :: String.t()

  @doc """
  Indicates if the provider has native summarization capabilities.
  """
  @callback supports_summarization?() :: boolean()
end
