defmodule Chess.CastlingTest do
  use ExUnit.Case

  alias Chess.Castling

  test "sides/0 returns both sides of the board" do
    assert Castling.sides() == [:king_side, :queen_side]
  end

  test "rights/0 returns the four castling rights" do
    assert Castling.rights() == [
             {:white, :king_side},
             {:white, :queen_side},
             {:black, :king_side},
             {:black, :queen_side}
           ]
  end

  test "fen_letters/0 maps the letters to the rights in canonical order" do
    assert Castling.fen_letters() == [
             {"K", {:white, :king_side}},
             {"Q", {:white, :queen_side}},
             {"k", {:black, :king_side}},
             {"q", {:black, :queen_side}}
           ]
  end

  test "right_for_letter/1 reads the rights of a FEN record" do
    assert Castling.right_for_letter("K") == {:white, :king_side}
    assert Castling.right_for_letter("Q") == {:white, :queen_side}
    assert Castling.right_for_letter("k") == {:black, :king_side}
    assert Castling.right_for_letter("q") == {:black, :queen_side}
    assert Castling.right_for_letter("X") == nil
    assert Castling.right_for_letter("-") == nil
  end

  test "the squares of the king and the rook" do
    assert Castling.king_start(:white) == :e1
    assert Castling.king_start(:black) == :e8

    assert Castling.rook_start(:white, :king_side) == :h1
    assert Castling.rook_start(:white, :queen_side) == :a1
    assert Castling.rook_start(:black, :king_side) == :h8
    assert Castling.rook_start(:black, :queen_side) == :a8

    assert Castling.king_destination(:white, :king_side) == :g1
    assert Castling.king_destination(:white, :queen_side) == :c1
    assert Castling.king_destination(:black, :king_side) == :g8
    assert Castling.king_destination(:black, :queen_side) == :c8

    assert Castling.rook_destination(:white, :king_side) == :f1
    assert Castling.rook_destination(:white, :queen_side) == :d1
    assert Castling.rook_destination(:black, :king_side) == :f8
    assert Castling.rook_destination(:black, :queen_side) == :d8
  end

  test "the squares that have to be empty and the squares that have to be safe" do
    assert Castling.empty_squares(:white, :king_side) == [:f1, :g1]
    assert Castling.empty_squares(:white, :queen_side) == [:b1, :c1, :d1]
    assert Castling.empty_squares(:black, :king_side) == [:f8, :g8]
    assert Castling.empty_squares(:black, :queen_side) == [:b8, :c8, :d8]

    assert Castling.safe_squares(:white, :king_side) == [:f1, :g1]
    assert Castling.safe_squares(:white, :queen_side) == [:c1, :d1]
    assert Castling.safe_squares(:black, :king_side) == [:f8, :g8]
    assert Castling.safe_squares(:black, :queen_side) == [:c8, :d8]
  end

  test "side_for_file/1 names the side of a rook's home file" do
    assert Castling.side_for_file(:h) == :king_side
    assert Castling.side_for_file(:a) == :queen_side
    assert Castling.side_for_file(:e) == nil
  end
end
