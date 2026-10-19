defmodule Chess.Piece do
  @moduledoc """
  Functionality related to Chess pieces.

  A piece is a single-letter atom, uppercase for white pieces, lowercase for black pieces, as in :Q
  """

  @white_pieces ~w(K Q R B N P)a

  def white_pieces, do: @white_pieces

  @black_pieces ~w(k q r b n p)a

  def black_pieces, do: @black_pieces

  def is_valid?(piece) when piece in @black_pieces, do: true
  def is_valid?(piece) when piece in @white_pieces, do: true
  def is_valid?(_piece), do: false

  def is_black?(piece) when piece in @black_pieces, do: true
  def is_black?(_piece), do: false

  def is_white?(piece) when piece in @white_pieces, do: true
  def is_white?(_piece), do: false

  def is_king?(piece) when piece == :k or piece == :K, do: true
  def is_king?(_piece), do: false

  def is_queen?(piece) when piece == :q or piece == :Q, do: true
  def is_queen?(_piece), do: false

  def is_rook?(piece) when piece == :r or piece == :R, do: true
  def is_rook?(_piece), do: false

  def is_bishop?(piece) when piece == :b or piece == :B, do: true
  def is_bishop?(_piece), do: false

  def is_knight?(piece) when piece == :n or piece == :N, do: true
  def is_knight?(_piece), do: false

  def is_pawn?(piece) when piece == :p or piece == :P, do: true
  def is_pawn?(_piece), do: false
end
