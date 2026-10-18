defmodule Chess.Piece do
  @moduledoc """
  Functionality related to Chess pieces.
  """

  @white_pieces ~w(K Q R B N P)a

  def white_pieces, do: @white_pieces

  @black_pieces ~w(k q r b n p)a

  def black_pieces, do: @black_pieces
end
