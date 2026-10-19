defmodule Chess.Board do
  @moduledoc """
  Functionality related to a Chess board.

  A Chess board is a map of `position => piece`, containing only occupied
  squares. `at/2` also accepts a keyword list of `{position, piece}` tuples
  for convenience.
  """

  alias Chess.Position

  @positions Position.all()

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
