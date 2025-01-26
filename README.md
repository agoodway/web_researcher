# Web Researcher

Elixir library for web content extraction, processing and summarization. Features include web search with LLM powered summaries, single page fetching and parsing to markdown, and website crawling. Planned support multiple search adapters (Brave, Bing, SearXNG, etc) and proxy service.

## Planned Features

- [ ] Fetch webpage with Playwright fallback
- [ ] HTML to Markdown conversion
- [ ] LLM-powered content summarization
- [ ] Search adapter: Brave
- [ ] Search adapter: Bing
- [ ] Search adapter: SearXNG
- [ ] Proxy service integration
- [ ] Website crawling with rate limiting

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

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/web_researcher>.

