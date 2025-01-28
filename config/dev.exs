import Config

config :web_researcher,
  # Web Researcher Development-specific settings
  use_playwright: true,

  # LLM Configuration
  llm_provider: String.to_atom(System.get_env("LLM_PROVIDER", "openai")),
  llm_model: System.get_env("LLM_MODEL", "gpt-3.5-turbo"),
  max_retries: String.to_integer(System.get_env("LLM_MAX_RETRIES", "3")),
  instructor_opts: [
    temperature: String.to_float(System.get_env("LLM_TEMPERATURE", "0.7"))
  ]
