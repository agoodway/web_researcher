defmodule WebResearcher.Config do
  @moduledoc """
  Handles configuration for WebResearcher, providing defaults and runtime configuration.
  """

  @doc """
  Gets additional Instructor options to be merged with defaults.
  """
  def instructor_opts do
    Application.get_env(:web_researcher, :instructor_opts, [])
  end

  @doc """
  Gets the model to use with Instructor.
  Must be configured in config.exs.
  """
  def instructor_model do
    model = Application.get_env(:web_researcher, :instructor_model)

    model ||
      raise "No model configured for Instructor. Please set :instructor_model in your config."
  end

  @doc """
  Gets the maximum number of search results to process for summarization.
  Defaults to 12 if not configured.
  """
  def max_search_results do
    Application.get_env(:web_researcher, :max_search_results, 12)
  end

  @doc """
  Gets the search adapter configuration.
  """
  def get_search_config(opts \\ []) do
    adapter = get_search_adapter(opts)
    adapter_config = get_adapter_config(adapter, opts)

    %{
      adapter: adapter,
      adapter_config: adapter_config
    }
  end

  @doc """
  Gets the configured search adapter.
  """
  def get_search_adapter(opts) do
    Keyword.get(
      opts,
      :adapter,
      Application.get_env(:web_researcher, :search_adapter, WebResearcher.Search.Adapters.SearXNG)
    )
  end

  @doc """
  Gets the adapter-specific configuration.
  """
  def get_adapter_config(WebResearcher.Search.Adapters.SearXNG, opts) do
    base_config = get_in(Application.get_env(:web_researcher, :providers, []), [:searxng]) || []

    %{
      base_url: get_in_opts_or_config(opts, base_config, :base_url, "http://localhost:8080"),
      timeout: get_in_opts_or_config(opts, base_config, :timeout, 10_000),
      format: get_in_opts_or_config(opts, base_config, :format, "json"),
      language: get_in_opts_or_config(opts, base_config, :language, "en"),
      safesearch: get_in_opts_or_config(opts, base_config, :safesearch, 1),
      categories: get_in_opts_or_config(opts, base_config, :categories, "general"),
      engines: get_in_opts_or_config(opts, base_config, :engines, "duckduckgo,brave,google"),
      headers: get_in_opts_or_config(opts, base_config, :headers, default_headers())
    }
  end

  def get_adapter_config(WebResearcher.Search.Adapters.Brave, opts) do
    base_config = get_in(Application.get_env(:web_researcher, :providers, []), [:brave]) || []

    %{
      api_key: get_in_opts_or_config(opts, base_config, :api_key),
      timeout: get_in_opts_or_config(opts, base_config, :timeout, 10_000)
    }
  end

  defp default_headers do
    [
      {"User-Agent",
       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"},
      {"Accept", "application/json"},
      {"Accept-Language", "en-US,en;q=0.9"},
      {"Accept-Encoding", "gzip, deflate"},
      {"Connection", "keep-alive"},
      {"Cache-Control", "no-cache"},
      {"Pragma", "no-cache"}
    ]
  end

  @doc """
  Gets task supervisor configuration.
  """
  def get_task_config(opts \\ []) do
    base_config = Application.get_env(:web_researcher, :task, [])

    %{
      max_concurrency:
        get_in_opts_or_config(opts, base_config, :max_concurrency, System.schedulers_online()),
      timeout: get_in_opts_or_config(opts, base_config, :timeout, 30_000),
      shutdown: get_in_opts_or_config(opts, base_config, :shutdown, 5_000)
    }
  end

  @doc """
  Gets request options for Instructor operations.
  """
  def get_request_opts(opts \\ []) do
    base_config = Application.get_env(:web_researcher, :instructor_opts, [])

    # Merge options in this order:
    # 1. Base config from instructor_opts
    # 2. Model from instructor_model (can be overridden by opts)
    # 3. Any additional opts passed to the function
    base_config
    |> Keyword.put(:model, instructor_model())
    |> Keyword.merge(opts)
  end

  @doc """
  Gets Playwright configuration.
  """
  def get_playwright_config(opts \\ []) do
    base_config = Application.get_env(:web_researcher, :playwright, [])

    %{
      enabled: get_in_opts_or_config(opts, base_config, :enabled, true),
      timeout: get_in_opts_or_config(opts, base_config, :timeout, 30_000)
    }
  end

  @doc """
  Gets Req HTTP client configuration.
  """
  def get_req_config(opts \\ []) do
    base_config = Application.get_env(:web_researcher, :req, [])

    %{
      max_retries: get_in_opts_or_config(opts, base_config, :max_retries, 0),
      retry_delay: get_in_opts_or_config(opts, base_config, :retry_delay, 1000)
    }
  end

  # Helper to get value from opts, config, or default
  defp get_in_opts_or_config(opts, config, key, default \\ nil) do
    Keyword.get(opts, key, Keyword.get(config, key, default))
  end
end
