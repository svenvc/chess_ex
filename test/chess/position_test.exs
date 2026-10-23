defmodule Chess.PositionTest do
  use ExUnit.Case

  alias Chess.Position

  test "position manipulation" do
    position = :a1

    assert Position.valid?(position)
    assert Position.dark?(position)
    refute Position.light?(position)

    assert Position.file(position) == :a
    assert Position.file_index(position) == 1
    assert Position.rank(position) == 1

    assert Position.new(Position.file(position), Position.rank(position)) == position
    assert Position.new(Position.file_index(position), Position.rank(position)) == position
  end

  test "parsing" do
    assert Position.from_string("a1") == :a1
  end

  test "at/2 builds a position from file and rank indexes" do
    assert Position.at(1, 1) == :a1
    assert Position.at(8, 8) == :h8
    assert Position.at(4, 5) == :d5

    assert Position.at(0, 1) == nil
    assert Position.at(9, 1) == nil
    assert Position.at(1, 0) == nil
    assert Position.at(1, 9) == nil
  end

  test "offset/3 moves a position and stops at the board edge" do
    assert Position.offset(:a1, 1, 0) == :b1
    assert Position.offset(:a1, 0, 1) == :a2
    assert Position.offset(:e4, 1, 1) == :f5
    assert Position.offset(:e4, -2, -3) == :c1

    assert Position.offset(:a1, -1, 0) == nil
    assert Position.offset(:a1, 0, -1) == nil
    assert Position.offset(:h8, 1, 0) == nil
    assert Position.offset(:h8, 0, 1) == nil
  end

  test "rotate/1 turns the board around" do
    assert Position.rotate(:a1) == :h8
    assert Position.rotate(:h8) == :a1
    assert Position.rotate(:b1) == :g8
    assert Position.rotate(:e4) == :d5
  end

  test "same_color?/2 compares square colors" do
    assert Position.same_color?(:a1, :h8)
    assert Position.same_color?(:b1, :a2)
    refute Position.same_color?(:a1, :a2)
    refute Position.same_color?(:b1, :h8)
  end
end
