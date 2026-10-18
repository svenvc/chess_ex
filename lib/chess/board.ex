defmodule Chess.Board do
  @moduledoc """
  Functionality related to a Chess board.
  """

  alias Chess.Position

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
end
