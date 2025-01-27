# Web Researcher

Elixir library for web content extraction, processing and summarization. Features include web search with LLM powered summaries, fetching and parsing of single pages into markdown, and website crawling. Planned support multiple search adapters (Brave, Bing, SearXNG, etc) and proxy service.

## Planned Features

- [x] Fetch webpage with Playwright fallback
- [x] HTML to Markdown conversion
- [ ] LLM-powered content summarization
- [ ] Search adapter: Brave
- [ ] Search adapter: Bing
- [ ] Search adapter: SearXNG
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

### Playwright

Playwright support is optional but recommended for fetching JavaScript-heavy pages and Single Page Applications (SPAs). The library will first attempt to fetch pages using standard HTTP requests, and only fall back to Playwright when necessary.

When enabled, WebResearcher maintains a persistent Playwright browser instance in your application's supervision tree and automatically restarts it if it crashes.

To ensure [Playwright's]([text](https://github.com/mechanical-orchard/playwright-elixir)) runtime dependencies (e.g., browsers) are available, execute the following command:

```bash
mix playwright.install
```

## Configuration

The following configuration options are available:

```elixir
# config/config.exs
config :web_researcher,
  # Enable/disable Playwright fallback for JavaScript-heavy pages
  use_playwright: false # default: true
```

## Usage

Fetch a webpage and return a markdown representation:

```elixir
# Basic usage
WebResearcher.fetch_page("https://elixir-lang.org")

# Disable Playwright for a specific request
WebResearcher.fetch_page("https://elixir-lang.org", use_playwright: false)
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/web_researcher>.
