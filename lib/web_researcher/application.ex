defmodule WebResearcher.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if playwright_enabled?() do
        [WebResearcher.Retriever.PlaywrightPool]
      else
        []
      end

    opts = [strategy: :one_for_one, name: WebResearcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp playwright_enabled? do
    Application.get_env(:web_researcher, :use_playwright, true)
  end
end
