defmodule Chess.Board do
  @moduledoc """
  Functionality related to a Chess board.

  A Chess board is a map of `position => piece`, containing only occupied
  squares. `at/2` also accepts a keyword list of `{position, piece}` tuples
  for convenience.
  """

  alias Chess.Position
  alias Chess.Piece

  @positions Position.all()

  @pieces Piece.white_pieces() ++ Piece.black_pieces()

  @doc """
  Create and return the initial Chess board.
  This is a map of 32 `{position, piece}` entries.
  """
  def initial do
    [
      Position.files()
      |> Enum.zip(~w(R N B Q K B N R)a)
      |> Enum.map(fn {file, piece} -> {Position.new(file, 1), piece} end),
      Position.files()
      |> Enum.map(fn file -> {Position.new(file, 2), :P} end),
      Position.files()
      |> Enum.zip(~w(r n b q k b n r)a)
      |> Enum.map(fn {file, piece} -> {Position.new(file, 8), piece} end),
      Position.files()
      |> Enum.map(fn file -> {Position.new(file, 7), :p} end)
    ]
    |> List.flatten()
    |> Map.new()
  end

  @doc """
  Return the piece at the given position,
  or nil if the square is empty.

  Accepts either a board map or a keyword list of `{position, piece}` tuples.
  """
  def at(board, position) when is_map(board) and position in @positions do
    Map.get(board, position)
  end

  def at(board, position) when is_list(board) and position in @positions do
    Keyword.get(board, position)
  end

  @doc """
  Return the `{position, piece}` entries of the given color (`:white` or `:black`).
  """
  def pieces(board, :white),
    do: Enum.filter(board, fn {_position, piece} -> Piece.is_white?(piece) end)

  def pieces(board, :black),
    do: Enum.filter(board, fn {_position, piece} -> Piece.is_black?(piece) end)

  @doc """
  Return the position of the king of the given color,
  or nil if there is no such king.
  """
  def king(board, color) do
    Enum.find_value(board, fn {position, piece} ->
      if is_piece_of?(piece, color) and Piece.is_king?(piece), do: position
    end)
  end

  @doc """
  Put a piece on a square, replacing whatever was there.
  """
  def put(board, position, piece)
      when position in @positions and piece in @pieces do
    Map.put(board, position, piece)
  end

  @doc """
  Remove the piece on a square, if any.

  Removing an empty square is a no-op.
  """
  def remove(board, position) when position in @positions do
    Map.delete(board, position)
  end

  @doc """
  Move the piece on `from` to `to`, capturing any piece on `to`.
  """
  def move(board, from, to) when from in @positions and to in @positions do
    piece = Map.fetch!(board, from)

    board
    |> Map.delete(from)
    |> Map.put(to, piece)
  end

  defp is_piece_of?(piece, :white), do: Piece.is_white?(piece)
  defp is_piece_of?(piece, :black), do: Piece.is_black?(piece)

  def to_ascii(board) do
    8..1//-1
    |> Enum.map(fn rank ->
      1..8
      |> Enum.map(fn file_index ->
        to_string(board |> at(Position.new(file_index, rank)) || ".")
      end)
      |> Enum.join(" ")
    end)
    |> Enum.join("\n")
  end

  def print(board), do: IO.puts(to_ascii(board))
end
