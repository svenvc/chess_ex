defmodule Chess.PieceTest do
  use ExUnit.Case

  alias Chess.Piece

  test "Queens" do
    piece = :Q

    assert Piece.valid?(piece)
    assert Piece.is_queen?(piece)
    assert Piece.white?(piece)

    piece = :q

    assert Piece.valid?(piece)
    assert Piece.is_queen?(piece)
    assert Piece.black?(piece)
  end

  test "type/1 names the kind of piece" do
    assert Piece.type(:K) == :king
    assert Piece.type(:q) == :queen
    assert Piece.type(:R) == :rook
    assert Piece.type(:b) == :bishop
    assert Piece.type(:N) == :knight
    assert Piece.type(:p) == :pawn

    assert Piece.type(:x) == nil
    assert Piece.type(nil) == nil
  end

  test "color/1 names the color of a piece" do
    for piece <- Piece.white_pieces() do
      assert Piece.color(piece) == :white
    end

    for piece <- Piece.black_pieces() do
      assert Piece.color(piece) == :black
    end

    assert Piece.color(:x) == nil
    assert Piece.color(nil) == nil
  end

  test "of_color?/2 compares the color of a piece" do
    assert Piece.of_color?(:Q, :white)
    assert Piece.of_color?(:q, :black)
    refute Piece.of_color?(:Q, :black)
    refute Piece.of_color?(:q, :white)
    refute Piece.of_color?(:x, :white)
    refute Piece.of_color?(:x, :black)
  end

  test "pawn_direction/1 returns the rank change of a pawn" do
    assert Piece.pawn_direction(:white) == 1
    assert Piece.pawn_direction(:black) == -1
  end

  test "start_rank/1 returns the rank a pawn starts on" do
    assert Piece.start_rank(:white) == 2
    assert Piece.start_rank(:black) == 7
  end

  test "promotion_rank/1 returns the rank a pawn promotes on" do
    assert Piece.promotion_rank(:white) == 8
    assert Piece.promotion_rank(:black) == 1
  end
end
