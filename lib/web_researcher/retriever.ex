defmodule WebResearcher.Retriever do
  @moduledoc false

  alias WebResearcher.Retriever.{Req, Playwright, Response}
  alias WebResearcher.WebPage
  require Logger

  @doc """
  Fetches a webpage using Req first, falling back to Playwright if needed.
  Returns {:ok, %WebPage{}} on success or {:error, %WebPage{}} on failure.

  ## Configuration

  The Playwright fallback can be disabled by setting the following in your config:

      config :web_researcher, :use_playwright, false

  It can also be overridden per-request by passing the `:use_playwright` option:

      WebResearcher.Retriever.fetch(url, use_playwright: false)
  """
  def fetch(url, opts \\ []) do
    case fetch_with_req(url, opts) do
      {:ok, :needs_playwright} ->
        if use_playwright_enabled?(opts) do
          Logger.info(
            "Web Researcher - Content appears to be a SPA/dynamic page, using Playwright for #{url}"
          )

          fetch_with_playwright(url, opts)
        else
          Logger.info(
            "Web Researcher - Content appears to need JavaScript but Playwright is disabled for #{url}"
          )

          {:error, :playwright_disabled}
        end

      {:ok, response} ->
        WebPage.from_response(url, response)

      {:error, _} = error ->
        error
    end
  end

  defp use_playwright_enabled?(opts) do
    Keyword.get(
      opts,
      :use_playwright,
      Application.get_env(:web_researcher, :use_playwright, true)
    )
  end

  defp fetch_with_req(url, opts) do
    case Req.get(url, opts) do
      {:ok, %Response{content: content} = response} when is_binary(content) ->
        if use_playwright?(content) do
          {:ok, :needs_playwright}
        else
          {:ok, response}
        end

      error ->
        Logger.error("Web Researcher - Req request failed #{inspect(error)}.")
        error
    end
  end

  defp fetch_with_playwright(url, opts) do
    case Playwright.get(url, opts) do
      {:ok, response} ->
        WebPage.from_response(url, response)

      {:error, _} = error ->
        Logger.error("Web Researcher - Playwright request failed #{inspect(error)}.")
        error
    end
  end

  # Detect if content likely needs JavaScript rendering
  defp use_playwright?(content) do
    cond do
      # Empty or near-empty body content
      !content || String.length(content) < 50 ->
        true

      has_empty_root_div?(content) ->
        true

      is_likely_spa?(content) ->
        true

      true ->
        false
    end
  end

  # Detect if content is likely a SPA (single-page application)
  defp is_likely_spa?(content) do
    indicators = [
      # React root
      ~r/<div\s+id=["']root["']\s*>/i,
      # Vue/general SPA root
      ~r/<div\s+id=["']app["']\s*>/i,
      # Bundled JS
      ~r/<script[^>]*src=["'][^"']*bundle\.js["']/i,
      # Chunked JS (webpack)
      ~r/<script[^>]*src=["'][^"']*chunk\.js["']/i,
      # Redux/state management
      ~r/window\.__INITIAL_STATE__/,
      # Nuxt.js
      ~r/window\.__NUXT__/,
      # Hashed bundles
      ~r/<script[^>]*src=["'][^"']*main\.[a-f0-9]+\.js["']/i
    ]

    Enum.any?(indicators, &Regex.match?(&1, content))
  end

  # Check for empty root div (common in React/Vue apps)
  defp has_empty_root_div?(content) do
    case Regex.run(~r/<div\s+id=["'](root|app)["'][^>]*>([\s\n]*)<\/div>/i, content) do
      [_, _, inner] -> String.trim(inner) == ""
      _ -> false
    end
  end
end
