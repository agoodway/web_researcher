defmodule WebResearcher.Retriever.Req do
  require Logger
  @behaviour WebResearcher.Retriever
  alias WebResearcher.Retriever.Response

  @doc """
  Fetches a webpage using Req HTTP client.
  """
  def get(url, opts \\ []) do
    responder = Keyword.get(opts, :responder, &Response.default_responder/1)

    case Req.get(url) do
      {:ok, %Req.Response{status: status, body: body}} when status < 400 ->
        %Response{status: :ok, content: body}

      error ->
        Logger.error("WebResearcher - Failed to get #{url}: #{inspect(error)}")
        %Response{status: :failed, content: nil}
    end
    |> responder.()
  end
end
