defmodule Chess.Board do
  @moduledoc """
  Functionality related to a Chess board.

  A Chess board is a list of {position, piece} tuples.
  """

  alias Chess.Position

  @doc """
  Create and return the initial Chess board.
  This is a list of 32 {position, piece} tuples.
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
  end

  def to_ascii(board) do
    8..1//-1
    |> Enum.map(fn rank ->
      1..8
      |> Enum.map(fn file_index ->
        to_string(board |> Keyword.get(Position.new(file_index, rank), "."))
      end)
      |> Enum.join(" ")
    end)
    |> Enum.join("\n")
  end

  def print(board), do: IO.puts(to_ascii(board))
end
