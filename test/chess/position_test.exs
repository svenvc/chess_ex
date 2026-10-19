defmodule Chess.PositionTest do
  use ExUnit.Case

  alias Chess.Position

  test "position manipulation" do
    position = :a1

    assert Position.is_valid?(position)
    assert Position.is_black?(position)
    refute Position.is_white?(position)

    assert Position.file(position) == :a
    assert Position.file_index(position) == 1
    assert Position.rank(position) == 1

    assert Position.new(Position.file(position), Position.rank(position)) == position
  end
end
