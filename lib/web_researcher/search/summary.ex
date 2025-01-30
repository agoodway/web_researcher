defmodule WebResearcher.Search.Summary do
  @moduledoc """
  Schema for representing a consolidated search result summary with metadata and individual page summaries.
  """

  use Ecto.Schema
  use Instructor.Validator
  import Ecto.Changeset

  defmodule PageSummary do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:url, :string)
      field(:title, :string)
      field(:summary, :string)
      field(:page_age, :string)
      field(:source_name, :string)
      field(:relevancy_score, :float)
      field(:relevancy_explanation, :string)
      field(:key_matches, {:array, :string})
    end

    def changeset(page_summary, attrs) do
      page_summary
      |> cast(attrs, [
        :url,
        :title,
        :summary,
        :page_age,
        :source_name,
        :relevancy_score,
        :relevancy_explanation,
        :key_matches
      ])
      |> validate_required([:url, :summary, :relevancy_score])
      |> validate_number(:relevancy_score,
        greater_than_or_equal_to: 0.0,
        less_than_or_equal_to: 1.0
      )
    end
  end

  defmodule StructuredData do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      # "table", "list", "key_value", etc.
      field(:type, :string)
      # Description of what this data represents
      field(:label, :string)
      # The actual structured data
      field(:data, :map)
    end

    def changeset(structured_data, attrs) do
      structured_data
      |> cast(attrs, [:type, :label, :data])
      |> validate_required([:type, :label, :data])
      |> validate_inclusion(:type, ["table", "list", "key_value", "code_block"])
    end
  end

  @llm_doc """
  ## Field Descriptions:
  - summary: A comprehensive synthesis of all relevant page summaries, focusing on key insights, patterns, and conclusions. Should be thorough (2000+ words) and well-structured.
  - query: The original search query that was used to find these pages.
  - total_pages_found: The total number of pages found in the initial search.
  - total_pages_summarized: The number of pages that passed relevancy checks and were included in the final summary.
  - individual_summaries: List of page summaries with their relevancy scores and metadata.
  - key_themes: List of main themes and concepts found across all summaries.
  - contradictions: List of any conflicting information found between sources.
  - structured_data: List of tables, lists, or other structured data extracted and merged from the sources.
  - source_quality: Assessment of source quality and reliability.
  - confidence_score: Overall confidence in the summary (0.0-1.0).
  """
  @primary_key false
  embedded_schema do
    field(:summary, :string)
    field(:query, :string)
    field(:total_pages_found, :integer)
    field(:total_pages_summarized, :integer)
    field(:key_themes, {:array, :string})
    field(:contradictions, {:array, :string})
    field(:confidence_score, :float)

    embeds_many(:individual_summaries, PageSummary)
    embeds_many(:structured_data, StructuredData)
  end

  @doc """
  Creates a changeset for manual creation/updates of the SearchSummary.
  """
  def changeset(search_summary, attrs) do
    search_summary
    |> cast(attrs, [
      :summary,
      :query,
      :total_pages_found,
      :total_pages_summarized,
      :key_themes,
      :contradictions,
      :confidence_score
    ])
    |> validate_required([
      :summary,
      :query,
      :total_pages_found,
      :total_pages_summarized,
      :key_themes,
      :confidence_score
    ])
    |> validate_length(:summary, min: 500)
    |> validate_number(:confidence_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_length(:key_themes, min: 1)
    |> cast_embed(:individual_summaries, required: true)
    |> cast_embed(:structured_data)
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> validate_required([
      :summary,
      :query,
      :total_pages_found,
      :total_pages_summarized,
      :key_themes,
      :confidence_score
    ])
    # |> validate_length(:summary, min: 2000)
    |> validate_length(:summary, min: 500)
    |> validate_number(:confidence_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_length(:key_themes, min: 1)
    |> cast_embed(:individual_summaries, required: true)
    |> cast_embed(:structured_data)
  end
end
