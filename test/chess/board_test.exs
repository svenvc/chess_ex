defmodule Chess.BoardTest do
  use ExUnit.Case

  alias Chess.{Board, Position, Piece}

  test "initial board" do
    initial_board = Board.initial()

    assert Enum.count(initial_board) == 32

    initial_positions =
      initial_board
      |> Enum.map(fn {position, _piece} -> position end)

    assert initial_positions |> Enum.count(&Position.is_black?/1) == 16
    assert initial_positions |> Enum.count(&Position.is_white?/1) == 16

    initial_pieces =
      initial_board
      |> Enum.map(fn {_position, piece} -> piece end)

    assert initial_pieces |> Enum.count(&Piece.is_black?/1) == 16
    assert initial_pieces |> Enum.count(&Piece.is_white?/1) == 16
    assert initial_pieces |> Enum.count(&Piece.is_king?/1) == 2
    assert initial_pieces |> Enum.count(&Piece.is_queen?/1) == 2
    assert initial_pieces |> Enum.count(&Piece.is_rook?/1) == 4
    assert initial_pieces |> Enum.count(&Piece.is_bishop?/1) == 4
    assert initial_pieces |> Enum.count(&Piece.is_knight?/1) == 4
    assert initial_pieces |> Enum.count(&Piece.is_pawn?/1) == 16

    initial_board_map = initial_board |> Map.new()

    assert initial_board_map[:d1] == :Q
    assert initial_board_map[:d8] == :q
  end
end
