defmodule WebResearcher.Retriever.Playwright do
  require Logger
  alias WebResearcher.Retriever.Response

  @doc """
  Fetches a webpage using Playwright browser automation
  """
  def get(url, opts \\ []) do
    responder = Keyword.get(opts, :responder, &Response.default_responder/1)

    case Playwright.launch(:chromium) do
      {:ok, browser} ->
        page = Playwright.Browser.new_page(browser)

        Playwright.Page.goto(page, url)
        Playwright.Page.wait_for_load_state(page, "domcontentloaded")

        html =
          page
          |> Playwright.Page.locator("html")
          |> Playwright.Locator.inner_html()

        Playwright.Browser.close(browser)

        responder.(%Response{status: :ok, content: html})
    end
  end
end
