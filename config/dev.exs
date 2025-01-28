import Config

# Set logger level to debug in development
config :logger, level: :debug

config :web_researcher,
  # Task supervisor configuration
  task: [
    max_concurrency: System.schedulers_online(),
    timeout: 10_000,
    shutdown: 5_000
  ],

  # Search configuration
  search_adapter: WebResearcher.Search.Adapters.SearXNG,

  # Playwright configuration
  playwright: [
    enabled: true,
    timeout: 30_000
  ],

  # LLM configuration
  llm: [
    provider: :openai,
    model: "gpt-4-turbo",
    max_retries: 3,
    opts: [
      temperature: 0.7,
      response_format: %{type: "json_object"}
    ]
  ],

  # Provider configurations
  providers: [
    # OpenAI provider config
    openai: [
      api_key: System.get_env("OPENAI_API_KEY"),
      organization_id: System.get_env("OPENAI_ORGANIZATION_ID"),
      api_base: System.get_env("OPENAI_API_BASE_URL")
    ],

    # Brave Search provider config
    brave: [
      api_key: System.get_env("BRAVE_API_KEY"),
      timeout: 10_000
    ],

    # SearXNG provider config
    searxng: [
      base_url: System.get_env("SEARXNG_BASE_URL", "http://localhost:8080"),
      timeout: 10_000,
      format: "json",
      language: "en",
      safesearch: 1,
      categories: "general",
      engines: "duckduckgo,brave,google",
      headers: [
        {"User-Agent",
         "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"},
        {"Accept", "application/json"},
        {"Accept-Language", "en-US,en;q=0.9"},
        {"Accept-Encoding", "gzip, deflate"},
        {"Connection", "keep-alive"},
        {"Cache-Control", "no-cache"},
        {"Pragma", "no-cache"}
      ]
    ]
  ]
