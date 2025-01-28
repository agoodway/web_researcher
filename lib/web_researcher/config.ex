defmodule WebResearcher.Config do
  @moduledoc """
  Configuration module for WebResearcher.
  Handles configuration for LLM models and Instructor settings.
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
  Gets the complete Instructor configuration options.
  These are used to configure the Instructor client itself.
  """
  def get_instructor_config(opts \\ []) do
    base = [
      provider: llm_provider(),
      api_key: llm_api_key(),
      max_retries: max_retries(),
      min_retries: min_retries()
    ]

    base =
      if org_id = llm_organization_id() do
        Keyword.put(base, :organization_id, org_id)
      else
        base
      end

    base =
      if url = llm_api_base_url() do
        Keyword.put(base, :api_base_url, url)
      else
        base
      end

    Keyword.merge(
      base,
      Keyword.take(opts, [:provider, :api_key, :organization_id, :api_base_url])
    )
  end

  @doc """
  Gets the request options to be sent to the LLM API.
  These are the options that will be included in the API request.
  """
  def get_request_opts(opts \\ []) do
    base = [
      model: llm_model(),
      temperature: 0.7,
      # Only include max_retries, not min_retries
      max_retries: max_retries()
    ]

    base
    |> Keyword.merge(instructor_opts())
    # Ensure min_retries is not included in API request
    |> Keyword.drop([:min_retries])
    |> Keyword.merge(Keyword.drop(opts, [:provider, :api_key, :organization_id, :api_base_url]))
  end
end
