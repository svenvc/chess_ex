defmodule Chess.Castling do
  @moduledoc """
  Functionality related to castling.

  A castling right is a `{color, side}` tuple, where the side is `:king_side`
  or `:queen_side`. A game holds the rights it still has in a `MapSet`;
  `Game.new/0` starts with all four of them.

  The module also names the squares of a castle: the king and the rook start
  on their home squares, the king moves two files, the rook jumps over it, the
  squares between them have to be empty and the squares the king crosses or
  lands on must not be attacked.
  """

  alias Chess.Position

  @sides [:king_side, :queen_side]

  @fen_letters [
    {"K", {:white, :king_side}},
    {"Q", {:white, :queen_side}},
    {"k", {:black, :king_side}},
    {"q", {:black, :queen_side}}
  ]

  @doc """
  Return both sides of the board a castle can go to.
  """
  def sides, do: @sides

  @doc """
  Return the four castling rights, in the order of a FEN record.
  """
  def rights, do: Enum.map(@fen_letters, fn {_letter, right} -> right end)

  @doc """
  Return the FEN letters of the castling rights and the rights they stand
  for, in the canonical order `KQkq`.
  """
  def fen_letters, do: @fen_letters

  @doc """
  Return the right a FEN letter stands for, or nil for an unknown letter.
  """
  def right_for_letter(letter) do
    case Enum.find(@fen_letters, fn {known, _right} -> known == letter end) do
      nil -> nil
      {_letter, right} -> right
    end
  end

  @doc """
  Return the square the king starts on.
  """
  def king_start(color), do: Position.new(:e, home_rank(color))

  @doc """
  Return the square the rook of a side starts on.
  """
  def rook_start(color, :king_side), do: Position.new(:h, home_rank(color))
  def rook_start(color, :queen_side), do: Position.new(:a, home_rank(color))

  @doc """
  Return the square the king lands on.
  """
  def king_destination(color, :king_side), do: Position.new(:g, home_rank(color))
  def king_destination(color, :queen_side), do: Position.new(:c, home_rank(color))

  @doc """
  Return the square the rook lands on.
  """
  def rook_destination(color, :king_side), do: Position.new(:f, home_rank(color))
  def rook_destination(color, :queen_side), do: Position.new(:d, home_rank(color))

  @doc """
  Return the squares between the king and the rook, which have to be empty.
  """
  def empty_squares(color, :king_side), do: squares(color, [:f, :g])
  def empty_squares(color, :queen_side), do: squares(color, [:b, :c, :d])

  @doc """
  Return the squares the king crosses or lands on, which must not be attacked.

  The king's own square is not in the list because castling out of check is
  not allowed at all; the caller checks that separately.
  """
  def safe_squares(color, :king_side), do: squares(color, [:f, :g])
  def safe_squares(color, :queen_side), do: squares(color, [:c, :d])

  @doc """
  Return the side of the board a rook's home file belongs to, or nil for a
  file that is not a rook's home file.
  """
  def side_for_file(:h), do: :king_side
  def side_for_file(:a), do: :queen_side
  def side_for_file(_file), do: nil

  # White's home rank is the first, Black's the eighth.
  defp home_rank(:white), do: 1
  defp home_rank(:black), do: 8

  # The squares of a list of files on the home rank of a color.
  defp squares(color, files) do
    Enum.map(files, fn file -> Position.new(file, home_rank(color)) end)
  end
end
