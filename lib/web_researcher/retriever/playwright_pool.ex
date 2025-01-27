defmodule WebResearcher.Retriever.PlaywrightPool do
  @moduledoc """
  Manages a shared Playwright browser instance,

  This pool maintains a single browser instance that is shared across requests,
  automatically handling browser crashes and restarts. The pool is only started
  if Playwright support is enabled in the configuration.
  """
  use GenServer
  require Logger

  @name __MODULE__

  @doc """
  Starts the Playwright browser pool.
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @doc """
  Gets the current browser instance, starting one if needed.
  Returns either a browser instance or `{:error, reason}`.
  """
  def get_browser do
    GenServer.call(@name, :get_browser)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, nil, {:continue, :start_browser}}
  end

  @impl true
  def handle_continue(:start_browser, _state) do
    case start_browser() do
      {:ok, browser} ->
        Process.monitor(self())
        {:noreply, browser}

      {:error, reason} ->
        Logger.error("Failed to start Playwright browser: #{inspect(reason)}")
        # Retry after a delay
        Process.send_after(self(), :retry_start_browser, 5000)
        {:noreply, nil}
    end
  end

  @impl true
  def handle_call(:get_browser, _from, nil) do
    case start_browser() do
      {:ok, browser} ->
        Process.monitor(self())
        {:reply, browser, browser}

      {:error, reason} ->
        {:reply, {:error, reason}, nil}
    end
  end

  def handle_call(:get_browser, _from, browser) do
    {:reply, browser, browser}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, _state) do
    Logger.warning("Playwright browser crashed: #{inspect(reason)}")
    {:noreply, nil, {:continue, :start_browser}}
  end

  def handle_info(:retry_start_browser, _state) do
    {:noreply, nil, {:continue, :start_browser}}
  end

  @impl true
  def terminate(_reason, browser) do
    if browser do
      Logger.info("Shutting down Playwright browser")

      try do
        Playwright.Browser.close(browser)
      rescue
        _ -> :ok
      end
    end
  end

  defp start_browser do
    Logger.info("Starting Playwright browser")
    Playwright.launch(:chromium)
  end
end
