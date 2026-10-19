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

  test "at/2 returns the piece at a position" do
    initial_board = Board.initial()

    assert Board.at(initial_board, :d1) == :Q
    assert Board.at(initial_board, :d8) == :q
    assert Board.at(initial_board, :e1) == :K
    assert Board.at(initial_board, :e8) == :k
    assert Board.at(initial_board, :a2) == :P
    assert Board.at(initial_board, :h7) == :p
  end

  test "at/2 returns nil for an empty square" do
    initial_board = Board.initial()

    assert Board.at(initial_board, :d4) == nil
    assert Board.at(initial_board, :e4) == nil
    assert Board.at(initial_board, :a4) == nil
  end

  test "at/2 rejects an invalid position" do
    # values are built dynamically so the compiler's type checking
    # doesn't flag these intentionally invalid calls
    invalid_position = String.to_atom("z9")
    invalid_type = IO.iodata_to_binary([?d, ?4])

    assert_raise FunctionClauseError, fn -> Board.at(Board.initial(), invalid_position) end
    assert_raise FunctionClauseError, fn -> Board.at(Board.initial(), invalid_type) end
  end
end
