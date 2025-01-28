defmodule WebResearcher.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Task supervisor for parallel operations
        {Task.Supervisor, name: WebResearcher.TaskSupervisor}
      ] ++ maybe_start_playwright()

    opts = [strategy: :one_for_one, name: WebResearcher.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_start_playwright do
    if playwright_enabled?() do
      [WebResearcher.Retriever.PlaywrightPool]
    else
      []
    end
  end

  defp playwright_enabled? do
    Application.get_env(:web_researcher, :use_playwright, true)
  end
end
