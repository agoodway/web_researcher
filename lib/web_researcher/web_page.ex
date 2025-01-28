defmodule WebResearcher.WebPage do
  @moduledoc """
  Schema for representing a retrieved webpage with both HTML content and markdown conversion.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias WebResearcher.{Retriever.Response, Parser}

  @primary_key false
  embedded_schema do
    field(:url, :string)
    field(:content, :string)
    field(:markdown, :string)
    field(:title, :string)
    field(:description, :string)
    field(:summary, :string)
    field(:keywords, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})
    field(:links, {:array, :map}, default: [])
    field(:status, Ecto.Enum, values: [:ok, :failed])
  end

  @type t :: %__MODULE__{
          url: String.t() | nil,
          content: String.t() | nil,
          markdown: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          summary: String.t() | nil,
          keywords: [String.t()],
          metadata: map(),
          links: [%{title: String.t(), url: String.t()}],
          status: :ok | :failed
        }

  @doc """
  Creates a new WebPage struct from a Retriever.Response.
  """
  def from_response(url, %Response{status: status, content: content}) do
    parsed_content =
      case Parser.parse_content(content) do
        {:ok, parsed} -> parsed
        _ -> %{markdown: nil, title: nil, description: nil, links: []}
      end

    attrs =
      %{
        url: url,
        content: content,
        status: status
      }
      |> Map.merge(parsed_content)

    %__MODULE__{}
    |> cast(attrs, [:url, :content, :markdown, :status, :title, :description, :links])
    |> validate_required([:url, :status])
    |> apply_action(:insert)
  end
end
