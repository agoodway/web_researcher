defmodule WebResearcher.Retriever.Playwright do
  @moduledoc """
  Provides Playwright-based web page retrieval for JavaScript-heavy pages.

  This module uses a shared browser instance from PlaywrightPool for efficient
  resource usage. Each request creates a new page in the shared browser,
  properly cleaning up resources after use.
  """
  require Logger
  alias WebResearcher.Retriever.{Response, PlaywrightPool}

  @doc """
  Fetches a webpage using Playwright headless browser and returns the HTML content.

  ## Options

    * `:responder` - A function to process the response (defaults to Response.default_responder/1)

  ## Returns

  Returns the result of calling the responder with a Response struct containing:
    * `:status` - `:ok` on success, `:failed` on error
    * `:content` - The HTML content on success, error message on failure
  """
  def get(url, opts \\ []) do
    responder = Keyword.get(opts, :responder, &Response.default_responder/1)

    case PlaywrightPool.get_browser() do
      {:error, reason} ->
        Logger.error("Failed to get Playwright browser: #{inspect(reason)}")
        responder.(%Response{status: :failed, content: "Failed to get Playwright browser"})

      browser ->
        page = nil

        try do
          with {:ok, new_page} <- {:ok, Playwright.Browser.new_page(browser)},
               page = new_page,
               {:ok, _response} <- {:ok, Playwright.Page.goto(page, url)},
               {:ok, _} <- {:ok, Playwright.Page.wait_for_load_state(page, "domcontentloaded")},
               {:ok, html_locator} <- {:ok, Playwright.Page.locator(page, "html")},
               {:ok, html} <- {:ok, Playwright.Locator.inner_html(html_locator)} do
            # Close page but keep browser
            Playwright.Page.close(page)
            responder.(%Response{status: :ok, content: html})
          else
            {:error, error} ->
              if page, do: Playwright.Page.close(page)
              Logger.error("Playwright error: #{inspect(error)}")

              responder.(%Response{
                status: :failed,
                content: "Failed to fetch page: #{inspect(error)}"
              })

            error ->
              if page, do: Playwright.Page.close(page)
              Logger.error("Unexpected Playwright error: #{inspect(error)}")

              responder.(%Response{
                status: :failed,
                content: "Unexpected error while fetching page"
              })
          end
        rescue
          error ->
            Logger.error("Playwright exception: #{Exception.message(error)}")
            # Attempt to close the page in case of error
            if page do
              try do
                Playwright.Page.close(page)
              rescue
                _ -> :ok
              end
            end

            responder.(%Response{
              status: :failed,
              content: "Browser error: #{Exception.message(error)}"
            })
        end
    end
  end
end
