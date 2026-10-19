defmodule Chess.PieceTest do
  use ExUnit.Case

  alias Chess.Piece

  test "Queens" do
    piece = :Q

    assert Piece.is_valid?(piece)
    assert Piece.is_queen?(piece)
    assert Piece.is_white?(piece)

    piece = :q

    assert Piece.is_valid?(piece)
    assert Piece.is_queen?(piece)
    assert Piece.is_black?(piece)
  end
end
