defmodule Chess.Position do
  @moduledoc """
  Functionality related to positions on a Chess board.
  """

  @files ~w(a b c d e f g h)a

  def files, do: @files

  @ranks Enum.to_list(1..8)

  def ranks, do: @ranks

  def new(file, rank) do
    "#{file}#{rank}" |> String.to_atom()
  end

  @all @ranks
       |> Enum.map(fn rank ->
         @files
         |> Enum.map(fn file ->
           "#{file}#{rank}" |> String.to_atom()
         end)
       end)

  def all, do: @all
end
