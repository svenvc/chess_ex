defmodule Chess.MoveTest do
  use ExUnit.Case

  alias Chess.Move

  test "creation" do
    move = Move.new(:e2, :e4)

    assert move == {:e2, :e4}
    assert Move.is_valid?(move)
  end

  test "creation rejects invalid positions" do
    # built dynamically so the compiler's type checking
    # doesn't flag these intentionally invalid calls
    invalid_position = String.to_atom("z9")

    assert_raise FunctionClauseError, fn -> Move.new(invalid_position, :e4) end
    assert_raise FunctionClauseError, fn -> Move.new(:e2, invalid_position) end
  end

  test "validity" do
    assert Move.is_valid?({:e2, :e4})

    # syntactically valid, but not a legal move
    assert Move.is_valid?({:e2, :e2})

    invalid_position = String.to_atom("z9")

    refute Move.is_valid?({invalid_position, :e4})
    refute Move.is_valid?({:e2, invalid_position})
    refute Move.is_valid?({:e2, "e4"})
    refute Move.is_valid?(:e2)
    refute Move.is_valid?({:e2})
    refute Move.is_valid?({:e2, :e4, :e5})
    refute Move.is_valid?("e2e4")
  end
end
