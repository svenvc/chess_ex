defmodule Chess.Position do
  @moduledoc """
  Functionality related to positions on a Chess board.

  A position is an atom from a fixed set of 64, each a letter + digit, as in :a1
  """

  @files ~w(a b c d e f g h)a

  def files, do: @files

  @ranks Enum.to_list(1..8)

  def ranks, do: @ranks

  def new(file, rank) when file in @files and rank in @ranks do
    "#{file}#{rank}" |> String.to_atom()
  end

  def from_string(string) when is_binary(string) do
    nil
  end

  @all @ranks
       |> Enum.flat_map(fn rank ->
         @files
         |> Enum.map(fn file ->
           "#{file}#{rank}" |> String.to_atom()
         end)
       end)

  def all, do: @all

  def is_valid?(position) when position in @all, do: true
  def is_valid?(_position), do: false

  def file(position) when position in [:a1, :a2, :a3, :a4, :a5, :a6, :a7, :a8], do: :a
  def file(position) when position in [:b1, :b2, :b3, :b4, :b5, :b6, :b7, :b8], do: :b
  def file(position) when position in [:c1, :c2, :c3, :c4, :c5, :c6, :c7, :c8], do: :c
  def file(position) when position in [:d1, :d2, :d3, :d4, :d5, :d6, :d7, :d8], do: :d
  def file(position) when position in [:e1, :e2, :e3, :e4, :e5, :e6, :e7, :e8], do: :e
  def file(position) when position in [:f1, :f2, :f3, :f4, :f5, :f6, :f7, :f8], do: :f
  def file(position) when position in [:g1, :g2, :g3, :g4, :g5, :g6, :g7, :g8], do: :g
  def file(position) when position in [:h1, :h2, :h3, :h4, :h5, :h6, :h7, :h8], do: :h

  def file_index(position) when position in [:a1, :a2, :a3, :a4, :a5, :a6, :a7, :a8], do: 1
  def file_index(position) when position in [:b1, :b2, :b3, :b4, :b5, :b6, :b7, :b8], do: 2
  def file_index(position) when position in [:c1, :c2, :c3, :c4, :c5, :c6, :c7, :c8], do: 3
  def file_index(position) when position in [:d1, :d2, :d3, :d4, :d5, :d6, :d7, :d8], do: 4
  def file_index(position) when position in [:e1, :e2, :e3, :e4, :e5, :e6, :e7, :e8], do: 5
  def file_index(position) when position in [:f1, :f2, :f3, :f4, :f5, :f6, :f7, :f8], do: 6
  def file_index(position) when position in [:g1, :g2, :g3, :g4, :g5, :g6, :g7, :g8], do: 7
  def file_index(position) when position in [:h1, :h2, :h3, :h4, :h5, :h6, :h7, :h8], do: 8

  def rank(position) when position in [:a1, :b1, :c1, :d1, :e1, :f1, :g1, :h1], do: 1
  def rank(position) when position in [:a2, :b2, :c2, :d2, :e2, :f2, :g2, :h2], do: 2
  def rank(position) when position in [:a3, :b3, :c3, :d3, :e3, :f3, :g3, :h3], do: 3
  def rank(position) when position in [:a4, :b4, :c4, :d4, :e4, :f4, :g4, :h4], do: 4
  def rank(position) when position in [:a5, :b5, :c5, :d5, :e5, :f5, :g5, :h5], do: 5
  def rank(position) when position in [:a6, :b6, :c6, :d6, :e6, :f6, :g6, :h6], do: 6
  def rank(position) when position in [:a7, :b7, :c7, :d7, :e7, :f7, :g7, :h7], do: 7
  def rank(position) when position in [:a8, :b8, :c8, :d8, :e8, :f8, :g8, :h8], do: 8

  def is_black?(position)
      when position in [
             :a1,
             :c1,
             :e1,
             :g1,
             :b2,
             :d2,
             :f2,
             :h2,
             :a3,
             :c3,
             :e3,
             :g3,
             :b4,
             :d4,
             :f4,
             :h4,
             :a5,
             :c5,
             :e5,
             :g5,
             :b6,
             :d6,
             :f6,
             :h6,
             :a7,
             :c7,
             :e7,
             :g7,
             :b8,
             :d8,
             :f8,
             :h8
           ],
      do: true

  def is_black?(_position), do: false

  def is_white?(position)
      when position in [
             :b1,
             :d1,
             :f1,
             :h1,
             :a2,
             :c2,
             :e2,
             :g2,
             :b3,
             :d3,
             :f3,
             :h3,
             :a4,
             :c4,
             :e4,
             :g4,
             :b5,
             :d5,
             :f5,
             :h5,
             :a6,
             :c6,
             :e6,
             :g6,
             :b7,
             :d7,
             :f7,
             :h7,
             :a8,
             :c8,
             :e8,
             :g8
           ],
      do: true

  def is_white?(_position), do: false
end
