defmodule Chess.PGN.ParseError do
  @moduledoc """
  Raised when a PGN document cannot be read.
  """

  defexception [:message]
end
