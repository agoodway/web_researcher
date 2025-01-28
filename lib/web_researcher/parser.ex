defmodule WebResearcher.Parser do
  @moduledoc """
  Handles HTML parsing and metadata extraction from web pages.
  Uses Floki to parse HTML and extract structured data like titles and descriptions.
  """

  @doc """
  Parses HTML content and extracts metadata.
  Returns a map with :title, :description, :markdown, and :links.

  ## Examples

      iex> Parser.parse_content(html_content)
      {:ok, %{
        title: "Page Title",
        description: "Meta description",
        markdown: "# Content",
        links: [%{title: "Link Text", url: "https://example.com"}]
      }}

  """
  def parse_content(nil), do: {:ok, %{}}

  def parse_content(content) when is_binary(content) do
    with {:ok, document} <- Floki.parse_document(content) do
      {:ok,
       %{
         title: extract_title(document),
         description: extract_description(document),
         markdown: Html2Markdown.convert(content),
         links: extract_links(document)
       }}
    else
      error -> {:error, error}
    end
  end

  @doc """
  Extracts all links from the document, returning a list of maps with :title and :url keys.
  Filters out empty links, anchor tags, and normalizes URLs.
  """
  def extract_links(document) do
    document
    |> Floki.find("a[href]")
    |> Enum.map(fn {"a", attrs, children} ->
      href = get_attr(attrs, "href")
      title = get_link_title(children)

      if valid_link?(href) do
        %{
          title: title,
          url: href
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1.title == "" && &1.url == ""))
    |> Enum.uniq_by(& &1.url)
  end

  # Gets the text content of link children, handling nested elements
  defp get_link_title(children) do
    children
    |> Floki.text()
    |> String.trim()
  end

  # Gets an attribute value from a list of attributes
  defp get_attr(attrs, name) do
    case List.keyfind(attrs, name, 0) do
      {^name, value} -> value
      nil -> ""
    end
  end

  # Validates if a link is worth including (not empty, not just anchor)
  defp valid_link?(href) do
    href != "" && !String.starts_with?(href, "#") && !String.starts_with?(href, "javascript:")
  end

  @doc """
  Extracts the page title from meta tags or title tag.
  Tries multiple sources in order:
  1. OpenGraph og:title
  2. Twitter Card twitter:title
  3. Regular HTML title tag
  """
  def extract_title(document) do
    # First try og:title
    case Floki.find(document, "meta[property='og:title']") |> Floki.attribute("content") do
      [title | _] ->
        title

      [] ->
        # Then try twitter:title
        case Floki.find(document, "meta[name='twitter:title']") |> Floki.attribute("content") do
          [title | _] ->
            title

          [] ->
            # Finally fall back to regular title tag
            case Floki.find(document, "title") |> Floki.text() do
              "" -> nil
              title -> String.trim(title)
            end
        end
    end
  end

  @doc """
  Extracts the page description from meta tags.
  Tries multiple sources in order:
  1. OpenGraph og:description
  2. Twitter Card twitter:description
  3. Regular meta description
  """
  def extract_description(document) do
    # First try og:description
    case Floki.find(document, "meta[property='og:description']") |> Floki.attribute("content") do
      [desc | _] ->
        desc

      [] ->
        # Then try twitter:description
        case Floki.find(document, "meta[name='twitter:description']")
             |> Floki.attribute("content") do
          [desc | _] ->
            desc

          [] ->
            # Finally fall back to regular meta description
            case Floki.find(document, "meta[name='description']") |> Floki.attribute("content") do
              [desc | _] -> String.trim(desc)
              [] -> nil
            end
        end
    end
  end
end
