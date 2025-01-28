defmodule WebResearcher.Summarizer do
  @moduledoc """
  Provides LLM-powered webpage summarization functionality.
  """

  alias WebResearcher.{WebPage, Config}
  use Instructor

  defmodule WebPageSummary do
    @moduledoc false
    use Ecto.Schema
    use Instructor.Validator
    import Ecto.Changeset

    @llm_doc """
    ## Field Descriptions:
    - summary: A comprehensive, detailed summary of the webpage's content that captures all key points, main ideas, and supporting information. Should be thorough and well-structured.
    - keywords: A list of relevant keywords and key phrases that represent the main topics, themes, and concepts discussed.
    - metadata: A structured map containing any tables, lists, data points, or other structured information found in the content. Tables and structured data should be preserved in their original format and structure.
    """
    @primary_key false
    embedded_schema do
      field(:summary, :string)
      field(:keywords, {:array, :string})
      field(:metadata, :map)
    end

    @type t :: %__MODULE__{
            summary: String.t(),
            keywords: [String.t()],
            metadata: map()
          }

    @impl true
    def validate_changeset(changeset) do
      changeset
      |> validate_required([:summary, :keywords])
      |> validate_length(:summary, min: 500, max: 20_000)
      |> validate_length(:keywords, min: 3, max: 15)
    end

    def system_prompt do
      """
      You are a highly detailed web page data extractor and summarizer.
      Your task is to analyze the provided web page content and extract comprehensive information into a structured format.
      Focus on thoroughness, accuracy, and preserving all important information.

      SUMMARY REQUIREMENTS:
      - Write an extensive, well-structured summary (minimum 2000 words)
      - Start with direct, factual statements about the subject matter
      - NEVER use phrases like:
        * "The web page focuses on..."
        * "This article discusses..."
        * "The content describes..."
        * "The page explains..."
        * "This website..."
      - Instead, write directly about the subject matter, for example:
        * "Appraisal Inbox is a software that..."
        * "The automated system provides..."
        * "Users can access..."
      - Present information in a clear narrative structure
      - Include all important facts, figures, statistics, and examples
      - Organize content into logical sections with clear transitions
      - Maintain professional, journalistic tone throughout
      - Use active voice and present tense
      - Never truncate or omit important information
      - Ensure comprehensive coverage of all key points
      - Provide specific details and concrete examples
      - Explain relationships between different concepts
      - Include relevant context and background information

      STRUCTURED DATA EXTRACTION:
      - Carefully identify all tables, lists, data structures in the content
      - Extract and preserve them in their exact original format
      - Convert tables into proper JSON format that will be cast to a map
      - Preserve all columns, rows, and relationships in table data
      - Include any relevant headers or metadata about the structured data
      - Format lists with their original hierarchy and structure
      - Extract any key-value pairs or structured data points

      KEYWORDS:
      - Extract 3-15 highly relevant keywords/phrases
      - Focus on main topics and core concepts
      - Include technical terms and important nomenclature
      - Ensure keywords reflect the full scope of content

      METADATA:
      - Store all structured data (tables, lists) as properly formatted JSON
      - Include any dates, authors, categories found
      - Preserve data types (numbers, dates, etc.)
      - Maintain hierarchical relationships in data

      Remember: Write directly about the subject matter. Never reference the webpage, article, or content itself.
      Focus on delivering comprehensive, accurate information in a clear, direct style.
      """
    end
  end

  @doc """
  Fetches a webpage and generates an LLM-powered summary.

  ## Options
  All options are passed to both the webpage fetcher and the summarizer.
  See `WebResearcher.fetch_page/2` for fetcher options.

  Summarizer specific options:
    * `:model` - The LLM model to use (defaults to config value)
    * `:max_retries` - Number of retries for LLM calls (defaults to config value)
    * Any other options supported by Instructor
  """
  def fetch_page_and_summarize(url, opts \\ []) do
    with {:ok, webpage} <- WebResearcher.fetch_page(url, opts),
         {:ok, summary} <- summarize(webpage, opts) do
      {:ok, webpage |> Map.merge(summary)}
    end
  end

  @doc """
  Generates a summary for an existing WebPage struct.

  ## Options
    * `:model` - The LLM model to use (defaults to config value)
    * `:max_retries` - Number of retries for LLM calls (defaults to config value)
    * Any other options supported by Instructor
  """
  @spec summarize(WebPage.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def summarize(webpage, opts \\ [])

  def summarize(%WebPage{markdown: markdown}, opts) when is_binary(markdown) do
    # Configure Instructor with API credentials and retry settings
    Application.put_env(:instructor, :config, Config.get_instructor_config(opts))

    # Get request options without min_retries
    request_opts = Config.get_request_opts(opts)

    # Make the chat completion request
    case Instructor.chat_completion(
           [
             model: request_opts[:model],
             response_model: WebPageSummary,
             max_retries: request_opts[:max_retries],
             messages: [
               %{role: "system", content: WebPageSummary.system_prompt()},
               %{
                 role: "user",
                 content: """
                 Please analyze and extract information from the following web page content.
                 Focus on providing a thorough summary and properly extracting any structured data (tables, lists) into the metadata field.

                 Web page content:
                 #{markdown}
                 """
               }
             ]
           ] ++ Keyword.drop(request_opts, [:model, :max_retries])
         ) do
      {:ok, summary} ->
        {:ok,
         %{
           summary: summary.summary,
           keywords: summary.keywords,
           metadata: summary.metadata
         }}

      error ->
        error
    end
  end

  def summarize(%WebPage{status: :failed}, _opts), do: {:error, :page_failed}
  def summarize(%WebPage{markdown: nil}, _opts), do: {:error, :no_content}
end
