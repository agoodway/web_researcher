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
  Gets task supervisor configuration.
  """
  def get_task_config(opts \\ []) do
    [
      max_concurrency: get_in_opts_or_config(opts, :max_concurrency, 4),
      timeout: get_in_opts_or_config(opts, :timeout, 10_000),
      shutdown: get_in_opts_or_config(opts, :task_shutdown, 5_000)
    ]
  end

  @doc """
  Gets instructor configuration for LLM operations.
  """
  def get_instructor_config(opts \\ []) do
    %{
      api_key: get_in_opts_or_config(opts, :api_key),
      model: get_in_opts_or_config(opts, :model, "gpt-4-turbo"),
      api_base: get_in_opts_or_config(opts, :api_base),
      organization_id: get_in_opts_or_config(opts, :organization_id)
    }
  end

  @doc """
  Gets request configuration for LLM operations.
  """
  def get_request_opts(opts \\ []) do
    Keyword.merge(
      [
        model: get_in_opts_or_config(opts, :model, "gpt-4-turbo"),
        max_retries: get_in_opts_or_config(opts, :max_retries, 3)
      ],
      Application.get_env(:web_researcher, :instructor_opts, [])
    )
  end

  @doc """
  Gets search adapter configuration.
  """
  def get_search_config(opts \\ []) do
    [
      adapter: get_in_opts_or_config(opts, :search_adapter, WebResearcher.Search.Adapters.Brave)
    ]
  end

  @doc """
  Gets Playwright configuration.
  """
  def get_playwright_config(opts \\ []) do
    [
      enabled: get_in_opts_or_config(opts, :use_playwright, true)
    ]
  end

  # Helper to get value from opts, config, or default
  defp get_in_opts_or_config(opts, key, default \\ nil) do
    Keyword.get(opts, key) ||
      Application.get_env(:web_researcher, key, default)
  end
end
