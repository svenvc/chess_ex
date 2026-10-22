defmodule Chess.FEN.ParseError do
  @moduledoc """
  Raised when a FEN record cannot be read.
  """

  defexception [:message]
end
