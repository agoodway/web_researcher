defmodule WebResearcher.Retriever.Playwright do
  require Logger
  alias WebResearcher.Retriever.Response

  @doc """
  Fetches a webpage using Playwright headless browser and returns the HTML content.
  """
  def get(url, opts \\ []) do
    responder = Keyword.get(opts, :responder, &Response.default_responder/1)

    with {:ok, browser} <- Playwright.launch(:chromium),
         {:ok, page} <- {:ok, Playwright.Browser.new_page(browser)},
         {:ok, _response} <- {:ok, Playwright.Page.goto(page, url)},
         {:ok, _} <- {:ok, Playwright.Page.wait_for_load_state(page, "domcontentloaded")},
         {:ok, html_locator} <- {:ok, Playwright.Page.locator(page, "html")},
         {:ok, html} <- {:ok, Playwright.Locator.inner_html(html_locator)} do
      Playwright.Browser.close(browser)
      responder.(%Response{status: :ok, content: html})
    else
      {:error, error} ->
        Logger.error("Playwright error: #{inspect(error)}")

        responder.(%Response{
          status: :failed,
          content: "Failed to fetch page: #{inspect(error)}"
        })

      error ->
        Logger.error("Unexpected Playwright error: #{inspect(error)}")
        responder.(%Response{status: :failed, content: "Unexpected error while fetching page"})
    end
  end
end
