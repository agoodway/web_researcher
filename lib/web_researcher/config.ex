defmodule WebResearcher.Config do
  @moduledoc """
  Handles configuration for WebResearcher, providing defaults and runtime configuration.
  """

  @doc """
  Gets the LLM provider to use.
  Defaults to :openai if not configured.
  """
  def llm_provider do
    Application.get_env(:web_researcher, :llm_provider, :openai)
  end

  @doc """
  Gets the LLM model to use for summarization.
  Defaults to "gpt-3.5-turbo" if not configured.
  """
  def llm_model do
    Application.get_env(:web_researcher, :llm_model, "gpt-3.5-turbo")
  end

  @doc """
  Gets the API key for the configured LLM provider.
  Checks environment variables based on provider name.
  """
  def llm_api_key do
    env_var = "#{llm_provider() |> to_string() |> String.upcase()}_API_KEY"

    System.get_env(env_var) ||
      Application.get_env(:web_researcher, :llm_api_key)
  end

  @doc """
  Gets the organization ID for the configured LLM provider.
  Checks environment variables based on provider name.
  """
  def llm_organization_id do
    env_var = "#{llm_provider() |> to_string() |> String.upcase()}_ORGANIZATION_ID"

    System.get_env(env_var) ||
      Application.get_env(:web_researcher, :llm_organization_id)
  end

  @doc """
  Gets the base URL for the LLM API if using a custom endpoint.
  Checks environment variables based on provider name.
  """
  def llm_api_base_url do
    env_var = "#{llm_provider() |> to_string() |> String.upcase()}_API_BASE_URL"

    System.get_env(env_var) ||
      Application.get_env(:web_researcher, :llm_api_base_url)
  end

  @doc """
  Gets the maximum number of retries for LLM calls.
  Defaults to 3 if not configured.
  """
  def max_retries do
    Application.get_env(:web_researcher, :max_retries, 3)
  end

  @doc """
  Gets the minimum number of retries for LLM calls.
  Defaults to 3 if not configured.
  """
  def min_retries do
    Application.get_env(:web_researcher, :min_retries, 3)
  end

  @doc """
  Gets additional Instructor options to be merged with defaults.
  """
  def instructor_opts do
    Application.get_env(:web_researcher, :instructor_opts, [])
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
      timeout: get_in_opts_or_config(opts, base_config, :timeout, 10_000),
      shutdown: get_in_opts_or_config(opts, base_config, :shutdown, 5_000)
    }
  end

  @doc """
  Gets instructor configuration for LLM operations.
  """
  def get_instructor_config(opts \\ []) do
    base_config = Application.get_env(:web_researcher, :instructor, [])

    %{
      api_key: get_in_opts_or_config(opts, base_config, :api_key),
      model: get_in_opts_or_config(opts, base_config, :model, "gpt-4-turbo"),
      api_base: get_in_opts_or_config(opts, base_config, :api_base),
      organization_id: get_in_opts_or_config(opts, base_config, :organization_id)
    }
  end

  @doc """
  Gets request configuration for LLM operations.
  """
  def get_request_opts(opts \\ []) do
    base_config = Application.get_env(:web_researcher, :instructor_opts, [])

    Keyword.merge(
      [
        model: get_in_opts_or_config(opts, base_config, :model, "gpt-4-turbo"),
        max_retries: get_in_opts_or_config(opts, base_config, :max_retries, 3)
      ],
      base_config
    )
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

  # Helper to get value from opts, config, or default
  defp get_in_opts_or_config(opts, config, key, default \\ nil) do
    Keyword.get(opts, key, Keyword.get(config, key, default))
  end
end
