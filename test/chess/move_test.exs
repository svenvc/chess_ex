defmodule Chess.MoveTest do
  use ExUnit.Case

  alias Chess.Move

  test "normal moves" do
    move = Move.new(:e2, :e4)

    assert move == {:e2, :e4}
    assert Move.is_valid?(move)
  end

  test "castling moves" do
    move = Move.castle(:e1, :g1)

    assert move == {:castle, :e1, :g1}
    assert Move.is_valid?(move)
  end

  test "en passant moves" do
    move = Move.en_passant(:e5, :d6)

    assert move == {:en_passant, :e5, :d6}
    assert Move.is_valid?(move)
  end

  test "promotion moves" do
    for piece <- [:Q, :R, :B, :N, :q, :r, :b, :n] do
      move = Move.promotion(:a7, :a8, piece)

      assert move == {:promotion, :a7, :a8, piece}
      assert Move.is_valid?(move)
    end
  end

  test "constructors reject invalid positions" do
    # built dynamically so the compiler's type checking
    # doesn't flag these intentionally invalid calls
    invalid_position = String.to_atom("z9")

    assert_raise FunctionClauseError, fn -> Move.new(invalid_position, :e4) end
    assert_raise FunctionClauseError, fn -> Move.new(:e2, invalid_position) end
    assert_raise FunctionClauseError, fn -> Move.castle(invalid_position, :g1) end
    assert_raise FunctionClauseError, fn -> Move.en_passant(:e5, invalid_position) end
    assert_raise FunctionClauseError, fn -> Move.promotion(invalid_position, :a8, :Q) end
  end

  test "promotion rejects invalid pieces" do
    invalid_piece = String.to_atom("x")
    king = String.to_atom("K")

    assert_raise FunctionClauseError, fn -> Move.promotion(:a7, :a8, invalid_piece) end
    assert_raise FunctionClauseError, fn -> Move.promotion(:a7, :a8, king) end
  end

  test "validity" do
    assert Move.is_valid?({:e2, :e4})
    assert Move.is_valid?({:castle, :e1, :g1})
    assert Move.is_valid?({:en_passant, :e5, :d6})
    assert Move.is_valid?({:promotion, :a7, :a8, :Q})

    # syntactically valid, but not a legal move
    assert Move.is_valid?({:e2, :e2})

    invalid_position = String.to_atom("z9")

    refute Move.is_valid?({invalid_position, :e4})
    refute Move.is_valid?({:e2, invalid_position})
    refute Move.is_valid?({:castle, invalid_position, :g1})
    refute Move.is_valid?({:en_passant, :e5, invalid_position})
    refute Move.is_valid?({:promotion, :a7, :a8, :K})
    refute Move.is_valid?({:e2, "e4"})
    refute Move.is_valid?(:e2)
    refute Move.is_valid?({:e2})
    refute Move.is_valid?({:e2, :e4, :e5})
    refute Move.is_valid?("e2e4")
  end
end
