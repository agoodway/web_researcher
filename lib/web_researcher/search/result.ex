defmodule WebResearcher.Search.Result do
  @moduledoc """
  Struct representing web search results including the search query and retrieved pages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias WebResearcher.{WebPage, Search.ResultItem}

  @primary_key false
  embedded_schema do
    field(:query, :string)
    field(:total_results, :integer)
    field(:provider, :string)
    field(:provider_metadata, :map, default: %{})
    embeds_many(:result_items, ResultItem)
    embeds_many(:pages, WebPage)
  end

  @type t :: %__MODULE__{
          query: String.t(),
          total_results: non_neg_integer(),
          provider: String.t(),
          provider_metadata: map(),
          result_items: [ResultItem.t()],
          pages: [WebPage.t()]
        }

  def changeset(result, attrs) do
    result
    |> cast(attrs, [:query, :total_results, :provider, :provider_metadata, :pages])
    |> cast_embed(:result_items)
    |> cast_embed(:pages)
    |> validate_required([:query, :provider])
  end

  @doc """
  Creates a new search result from the given attributes.
  """
  def new(attrs) do
    # Convert any structs to maps
    attrs =
      attrs
      |> Map.update(:pages, [], fn pages ->
        Enum.map(pages, fn
          %WebResearcher.WebPage{} = page -> Map.from_struct(page)
          page -> page
        end)
      end)
      |> Map.update(:result_items, [], fn items ->
        Enum.map(items, fn
          %ResultItem{} = item -> Map.from_struct(item)
          item -> item
        end)
      end)

    %__MODULE__{}
    |> cast(attrs, [:query, :total_results, :provider, :provider_metadata])
    |> cast_embed(:result_items)
    |> cast_embed(:pages)
    |> validate_required([:query])
    # Apply the changeset to get a clean struct
    |> apply_action!(:insert)
  end
end
