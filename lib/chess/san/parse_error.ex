defmodule Chess.SAN.ParseError do
  @moduledoc """
  Raised when a SAN token cannot be read, or does not match a legal move.
  """

  defexception [:message]
end
