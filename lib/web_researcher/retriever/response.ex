defmodule WebResearcher.Retriever.Response do
  @moduledoc """
  Response struct for the retriever.
  """

  @type t :: %__MODULE__{
          status: atom(),
          content: String.t()
        }

  defstruct status: nil, content: nil

  @doc """
  Default responder for requests.
  """
  def default_responder(%WebResearcher.Retriever.Response{status: :failed} = response) do
    {:error, response}
  end

  def default_responder(response), do: {:ok, response}
end
