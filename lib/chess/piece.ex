defmodule Chess.Piece do
  @moduledoc """
  Functionality related to Chess pieces.

  A piece is a single-letter atom, uppercase for white pieces, lowercase for black pieces, as in :Q
  """

  @white_pieces ~w(K Q R B N P)a

  def white_pieces, do: @white_pieces

  @black_pieces ~w(k q r b n p)a

  def black_pieces, do: @black_pieces

  def valid?(piece) when piece in @black_pieces, do: true
  def valid?(piece) when piece in @white_pieces, do: true
  def valid?(_piece), do: false

  @doc """
  Return the type of a piece, or nil for something that is not a piece.
  """
  def type(piece) when piece in [:K, :k], do: :king
  def type(piece) when piece in [:Q, :q], do: :queen
  def type(piece) when piece in [:R, :r], do: :rook
  def type(piece) when piece in [:B, :b], do: :bishop
  def type(piece) when piece in [:N, :n], do: :knight
  def type(piece) when piece in [:P, :p], do: :pawn
  def type(_piece), do: nil

  @doc """
  Return the color of a piece, or nil for something that is not a piece.
  """
  def color(piece) when piece in @white_pieces, do: :white
  def color(piece) when piece in @black_pieces, do: :black
  def color(_piece), do: nil

  @doc """
  Return true if the piece has the given color.
  """
  def of_color?(piece, color), do: color(piece) == color

  @doc """
  Return the rank change of a pawn of the given color: `1` for White and `-1`
  for Black.
  """
  def pawn_direction(:white), do: 1
  def pawn_direction(:black), do: -1

  @doc """
  Return the rank a pawn of the given color starts on: `2` for White and `7`
  for Black.
  """
  def start_rank(:white), do: 2
  def start_rank(:black), do: 7

  @doc """
  Return the rank a pawn of the given color promotes on: `8` for White and `1`
  for Black.
  """
  def promotion_rank(:white), do: 8
  def promotion_rank(:black), do: 1

  def black?(piece) when piece in @black_pieces, do: true
  def black?(_piece), do: false

  def white?(piece) when piece in @white_pieces, do: true
  def white?(_piece), do: false

  def king?(piece) when piece == :k or piece == :K, do: true
  def king?(_piece), do: false

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
