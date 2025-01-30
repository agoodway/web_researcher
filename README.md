# Web Researcher

Elixir library for web content extraction, processing and summarization. Features include web search with LLM powered summaries, fetching and parsing of single pages into markdown, and website crawling. Planned support multiple search adapters (Brave, Bing, SerpAPI, SearXNG, etc) and proxy services.

## Planned Features

- [x] Fetch webpage with Playwright fallback
- [x] Fetch webpages via search adapter
- [x] HTML to Markdown conversion
- [x] LLM-powered web page summarization
- [ ] LLM-powered web search summarization
- [x] Parse out Title and Description
- [x] Search adapter: SearXNG
- [x] Search adapter: Brave
- [ ] Search adapter: Bing
- [ ] Search adapter: SerpAPI
- [ ] Proxy service integration
- [ ] Detect if webpage is RSS and crawl
- [ ] Website crawling (based on sitemap) with rate limiting

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `web_researcher` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:web_researcher, "~> 0.1.0"}
  ]
end
```

## Configuration

The following configuration options are available:

```elixir
# config/config.exs

config :web_researcher,
# Enable/disable Playwright fallback for JavaScript-heavy pages
  use_playwright: false, # default: true

  # Task supervisor configuration for parallel operations
  max_concurrency: 4,    # Maximum number of concurrent tasks (default is dynamic)
  task_timeout: 10_000,  # Default timeout for tasks in ms (default: 10_000)
  task_shutdown: 5_000,  # Shutdown timeout in ms (default: 5_000)

  # HTTP client retry configuration
  req: [
    max_retries: 3,      # Number of retries for failed requests (default: 0)
    retry_delay: 2000    # Base delay between retries in ms (default: 1000)
  ],

  # Search adapter configuration
  search_adapter: WebResearcher.Search.Adapters.Brave,

  # LLM Configuration (based on Instructor)
  llm_model: "gpt-4-turbo",
  max_retries: 3, # default: 3
  instructor_opts: [ # default: []
    # Any additional Instructor options
    temperature: 0.7,
    response_format: %{type: "json_object"}
  ]
```

### HTTP Client Configuration

The library uses Req as its HTTP client with configurable retry behavior. By default, retries are disabled (max_retries: 0). When retries are enabled:
- Uses exponential backoff (retry_delay * attempt)
- Only retries on connection errors and 5xx responses
- Can be configured globally or per-request

Example with retries enabled:
```elixir
# Global configuration
config :web_researcher,
  req: [
    max_retries: 3,     # Retry up to 3 times
    retry_delay: 1000   # Start with 1 second delay
  ]

# Per-request configuration
WebResearcher.fetch_page("https://example.com", max_retries: 2, retry_delay: 2000)
```

## Search Providers

WebResearcher supports multiple search providers to gather web content:

### SearXNG

[SearXNG](https://github.com/searxng/searxng) is a privacy-respecting, self-hostable metasearch engine that aggregates results from various search services.

Configure SearXNG in your config:

```elixir
config :web_researcher, :searxng,
  base_url: System.get_env("SEARXNG_BASE_URL", "http://localhost:8080"),
  engines: "duckduckgo,brave,google",
  language: "en"
```

When running [SearXNG]([text](https://docs.searxng.org/dev/search_api.html)) via [Docker](https://github.com/searxng/searxng-docker), you'll need the following additional configuration:

In `settings.yaml`:
```yaml
search:
  formats:
    - json
```

In `docker-compose.yaml`:
```yaml
    environment:
      - SEARXNG_REQUEST_TIMEOUT=10.0
      - SEARXNG_LIMITER=false
      - SEARXNG_REDIS_URL=redis://redis:6379/0
```

These settings enable JSON response format and configure appropriate timeouts and rate limiting for local development.

### Brave Search API

Popular search provider with its own independent index and optional summarization. [Brave](https://brave.com/search/api/) requires an API key:

```elixir
config :web_researcher, :brave,
  api_key: System.get_env("BRAVE_API_KEY")
```

## Usage

Fetch a webpage and return a markdown representation:

```elixir
# Basic usage
WebResearcher.fetch_page("https://elixir-lang.org")

# Disable Playwright for a specific request
WebResearcher.fetch_page("https://elixir-lang.org", use_playwright: false)

# Fetch and summarize a webpage
{:ok, webpage} = WebResearcher.fetch_page_and_summarize("https://elixir-lang.org")

# Override LLM options for a specific request
{:ok, webpage} = WebResearcher.fetch_page_and_summarize("https://elixir-lang.org",
  model: "gpt-3.5-turbo",
  temperature: 0.5
)

# Search the web (results only)
{:ok, result} = WebResearcher.search_web("elixir programming")

# Search and fetch pages
{:ok, result} = WebResearcher.search_web_and_fetch_pages("elixir programming",
  limit: 5,           # Number of results (default: 10)
  timeout: 15_000     # Page fetch timeout in ms (default: 10_000)
)
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/web_researcher>.
