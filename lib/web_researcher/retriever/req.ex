defmodule WebResearcher.Retriever.Req do
  require Logger
  alias WebResearcher.{Retriever.Response, Config}

  @doc """
  Fetches a webpage using Req HTTP client.
  """
  def get(url, opts \\ []) do
    responder = Keyword.get(opts, :responder, &Response.default_responder/1)
    req_config = Config.get_req_config(opts)
    retry_opt = if req_config.max_retries > 0, do: :safe_transient, else: false

    case Req.get(url,
           retry: retry_opt,
           retry_delay: req_config.retry_delay
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status < 400 ->
        %Response{status: :ok, content: body}

      {:ok, %Req.Response{status: status}} ->
        %Response{status: :failed, content: to_string(status)}

      _error ->
        %Response{status: :failed, content: nil}
    end
    |> responder.()
  end
end
