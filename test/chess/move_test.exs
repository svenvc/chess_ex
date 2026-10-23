defmodule Chess.MoveTest do
  use ExUnit.Case

  alias Chess.Move

  test "normal moves" do
    move = Move.new(:e2, :e4)

    assert move == {:e2, :e4}
    assert Move.valid?(move)
  end

  test "castling moves" do
    move = Move.castle(:e1, :g1)

    assert move == {:castle, :e1, :g1}
    assert Move.valid?(move)
  end

  test "en passant moves" do
    move = Move.en_passant(:e5, :d6)

    assert move == {:en_passant, :e5, :d6}
    assert Move.valid?(move)
  end

  test "promotion moves" do
    for piece <- [:Q, :R, :B, :N, :q, :r, :b, :n] do
      move = Move.promotion(:a7, :a8, piece)

      assert move == {:promotion, :a7, :a8, piece}
      assert Move.valid?(move)
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

  test "from/1 and to/1 read every move shape" do
    assert Move.from({:e2, :e4}) == :e2
    assert Move.to({:e2, :e4}) == :e4
    assert Move.from({:castle, :e1, :g1}) == :e1
    assert Move.to({:castle, :e1, :g1}) == :g1
    assert Move.from({:en_passant, :e5, :d6}) == :e5
    assert Move.to({:en_passant, :e5, :d6}) == :d6
    assert Move.from({:promotion, :a7, :a8, :Q}) == :a7
    assert Move.to({:promotion, :a7, :a8, :Q}) == :a8
  end

  test "promotion_piece/1 returns the promoted piece or nil" do
    assert Move.promotion_piece({:promotion, :a7, :a8, :Q}) == :Q
    assert Move.promotion_piece({:e2, :e4}) == nil
    assert Move.promotion_piece({:castle, :e1, :g1}) == nil
  end

  test "capture_square/1 names the square a move captures on" do
    assert Move.capture_square({:e2, :e4}) == :e4
    assert Move.capture_square({:promotion, :a7, :b8, :Q}) == :b8
    assert Move.capture_square({:castle, :e1, :g1}) == nil
    assert Move.capture_square({:en_passant, :e5, :d6}) == :d5
  end

  test "castle_side/1 names the side of a castling move" do
    assert Move.castle_side({:castle, :e1, :g1}) == :king_side
    assert Move.castle_side({:castle, :e1, :c1}) == :queen_side
    assert Move.castle_side({:castle, :e8, :g8}) == :king_side
    assert Move.castle_side({:castle, :e8, :c8}) == :queen_side
  end

  test "skipped_square/1 names the square of a two-rank move" do
    assert Move.skipped_square({:e2, :e4}) == :e3
    assert Move.skipped_square({:e7, :e5}) == :e6
    assert Move.skipped_square({:e2, :e3}) == nil
    assert Move.skipped_square({:castle, :e1, :g1}) == nil
  end

  test "promotions/1 returns the pieces of the moving color" do
    assert Move.promotions(:white) == [:Q, :R, :B, :N]
    assert Move.promotions(:black) == [:q, :r, :b, :n]
  end

  test "validity" do
    assert Move.valid?({:e2, :e4})
    assert Move.valid?({:castle, :e1, :g1})
    assert Move.valid?({:en_passant, :e5, :d6})
    assert Move.valid?({:promotion, :a7, :a8, :Q})

    # syntactically valid, but not a legal move
    assert Move.valid?({:e2, :e2})

    invalid_position = String.to_atom("z9")

    refute Move.valid?({invalid_position, :e4})
    refute Move.valid?({:e2, invalid_position})
    refute Move.valid?({:castle, invalid_position, :g1})
    refute Move.valid?({:en_passant, :e5, invalid_position})
    refute Move.valid?({:promotion, :a7, :a8, :K})
    refute Move.valid?({:e2, "e4"})
    refute Move.valid?(:e2)
    refute Move.valid?({:e2})
    refute Move.valid?({:e2, :e4, :e5})
    refute Move.valid?("e2e4")
  end
end
