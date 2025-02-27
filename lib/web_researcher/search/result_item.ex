defmodule WebResearcher.Search.ResultItem do
  @moduledoc """
  Represents a single search result with standardized fields across providers.
  Includes common metadata like title, URL, and provider-specific data.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WebResearcher.WebPage

  @primary_key false
  embedded_schema do
    field(:title, :string)
    field(:description, :string)
    field(:url, :string)
    field(:page_age, :string)
    field(:rank, :integer)
    field(:language, :string)
    field(:family_friendly, :boolean, default: true)
    field(:provider_metadata, :map, default: %{})
    field(:thumbnail_url, :string)
    field(:source_name, :string)
    field(:source_favicon, :string)
    field(:category, :string)
    field(:score, :float)
    field(:position, :integer)
    field(:content_type, :string)
    field(:extra_snippets, {:array, :string}, default: [])
    field(:source_engines, {:array, :string}, default: [])
    embeds_one(:web_page, WebPage)
  end

  @type t :: %__MODULE__{
          title: String.t(),
          description: String.t(),
          url: String.t(),
          page_age: String.t() | nil,
          rank: integer() | nil,
          language: String.t() | nil,
          family_friendly: boolean(),
          provider_metadata: map(),
          thumbnail_url: String.t() | nil,
          source_name: String.t() | nil,
          source_favicon: String.t() | nil,
          category: String.t() | nil,
          score: float() | nil,
          position: integer() | nil,
          content_type: String.t() | nil,
          extra_snippets: [String.t()],
          source_engines: [String.t()],
          web_page: WebPage.t() | nil
        }

  @doc """
  Creates or updates a result item with the given attributes.
  Validates required fields and URL format.
  """
  def changeset(result_item, attrs) do
    result_item
    |> cast(attrs, [
      :title,
      :description,
      :url,
      :page_age,
      :rank,
      :language,
      :family_friendly,
      :provider_metadata,
      :thumbnail_url,
      :source_name,
      :source_favicon,
      :category,
      :score,
      :position,
      :content_type,
      :extra_snippets,
      :source_engines
    ])
    |> validate_required([:title, :url])
    |> validate_url(:url)
    |> validate_list_type(:extra_snippets, :string)
    |> validate_list_type(:source_engines, :string)
    |> cast_embed(:web_page, required: false)
  end

  # Ensures URL has a valid scheme and host
  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host} when not is_nil(scheme) and not is_nil(host) -> []
        _ -> [{field, "must be a valid URL"}]
      end
    end)
  end

  # Validates that a list field contains only elements of the specified type
  defp validate_list_type(changeset, field, type) do
    case get_change(changeset, field) do
      nil -> changeset
      value when not is_list(value) -> add_error(changeset, field, "must be a list")
      list -> validate_list_elements(changeset, field, list, type)
    end
  end

  defp validate_list_elements(changeset, field, list, :string) do
    if Enum.all?(list, &is_binary/1) do
      changeset
    else
      add_error(changeset, field, "must contain only strings")
    end
  end
end
