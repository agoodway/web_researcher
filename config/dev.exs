import Config

config :web_researcher,
  # Task supervisor configuration
  max_concurrency: 4,
  task_timeout: 10_000,
  task_shutdown: 5_000,

  # Search configuration
  search_adapter: WebResearcher.Search.Adapters.Brave,

  # Playwright configuration
  use_playwright: true,

  # LLM configuration
  llm_model: "gpt-4-turbo",
  max_retries: 3,
  instructor_opts: [
    temperature: 0.7,
    response_format: %{type: "json_object"}
  ]

# Provider-specific configuration
config :web_researcher, :brave, api_key: System.get_env("BRAVE_API_KEY")

# LLM provider configuration
config :web_researcher, :llm,
  provider: :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization_id: System.get_env("OPENAI_ORGANIZATION_ID"),
  api_base: System.get_env("OPENAI_API_BASE_URL")
