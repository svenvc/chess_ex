defmodule Chess.BoardTest do
  use ExUnit.Case

  alias Chess.{Board, Position, Piece}

  test "initial board" do
    initial_board = Board.initial()

    assert Enum.count(initial_board) == 32

    initial_positions =
      initial_board
      |> Enum.map(fn {position, _piece} -> position end)

    assert initial_positions |> Enum.count(&Position.dark?/1) == 16
    assert initial_positions |> Enum.count(&Position.light?/1) == 16

    initial_pieces =
      initial_board
      |> Enum.map(fn {_position, piece} -> piece end)

    assert initial_pieces |> Enum.count(&Piece.black?/1) == 16
    assert initial_pieces |> Enum.count(&Piece.white?/1) == 16
    assert initial_pieces |> Enum.count(&Piece.king?/1) == 2
    assert initial_pieces |> Enum.count(&Piece.is_queen?/1) == 2
    assert initial_pieces |> Enum.count(&Piece.is_rook?/1) == 4
    assert initial_pieces |> Enum.count(&Piece.is_bishop?/1) == 4
    assert initial_pieces |> Enum.count(&Piece.is_knight?/1) == 4
    assert initial_pieces |> Enum.count(&Piece.is_pawn?/1) == 16

    assert Board.at(initial_board, :d1) == :Q
    assert Board.at(initial_board, :d8) == :q
  end

  test "initial/0 returns a map of occupied squares" do
    initial_board = Board.initial()

    assert is_map(initial_board)
    assert map_size(initial_board) == 32
  end

  test "at/2 accepts both a map and a keyword list" do
    map_board = Board.initial()
    list_board = Map.to_list(map_board)

    assert Board.at(map_board, :d1) == :Q
    assert Board.at(list_board, :d1) == :Q
    assert Board.at(list_board, :d4) == nil

    for position <- Position.all() do
      assert Board.at(map_board, position) == Board.at(list_board, position)
    end
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

    assert_raise FunctionClauseError, fn ->
      Board.at(Map.to_list(Board.initial()), invalid_position)
    end
  end

  test "pieces/2 returns the pieces of one color" do
    initial_board = Board.initial()

    white = Board.pieces(initial_board, :white)
    black = Board.pieces(initial_board, :black)

    assert length(white) == 16
    assert length(black) == 16
    assert {:d1, :Q} in white
    assert {:d8, :q} in black
  end

  test "king/2 returns the king position" do
    initial_board = Board.initial()

    assert Board.king(initial_board, :white) == :e1
    assert Board.king(initial_board, :black) == :e8
    assert Board.king(%{}, :white) == nil
  end

  test "put/3 and remove/2" do
    board = Board.initial()

    assert board |> Board.remove(:e2) |> Board.at(:e2) == nil
    assert board |> Board.put(:e4, :Q) |> Board.at(:e4) == :Q
    assert board |> Board.put(:d1, :N) |> Board.at(:d1) == :N
  end

  test "move/3 relocates a piece and captures" do
    board = Board.initial()

    moved = Board.move(board, :e2, :e4)

    assert Board.at(moved, :e2) == nil
    assert Board.at(moved, :e4) == :P

    captured = Board.move(board, :d1, :d8)

    assert Board.at(captured, :d1) == nil
    assert Board.at(captured, :d8) == :Q
  end

  test "move/3 requires a piece on the from square" do
    assert_raise KeyError, fn -> Board.move(Board.initial(), :e4, :e5) end
  end

  test "rows/1 returns the board rank by rank, including empty squares" do
    rows = Board.rows(Board.initial())

    assert length(rows) == 8
    assert Enum.all?(rows, fn row -> length(row) == 8 end)

    assert hd(rows) == [
             {:a8, :r},
             {:b8, :n},
             {:c8, :b},
             {:d8, :q},
             {:e8, :k},
             {:f8, :b},
             {:g8, :n},
             {:h8, :r}
           ]

    assert List.last(rows) == [
             {:a1, :R},
             {:b1, :N},
             {:c1, :B},
             {:d1, :Q},
             {:e1, :K},
             {:f1, :B},
             {:g1, :N},
             {:h1, :R}
           ]

    assert Enum.at(rows, 2) |> Enum.map(fn {_position, piece} -> piece end) |> Enum.uniq() == [
             nil
           ]

    positions =
      rows
      |> Enum.flat_map(& &1)
      |> Enum.map(fn {position, _piece} -> position end)

    assert Enum.sort(positions) == Enum.sort(Position.all())
  end

  test "to_ascii/1 renders the board rank by rank" do
    lines =
      Board.initial()
      |> Board.to_ascii()
      |> String.split("\n")

    assert length(lines) == 8
    assert hd(lines) == "r n b q k b n r"
    assert List.last(lines) == "R N B Q K B N R"
    assert Enum.at(lines, 2) == ". . . . . . . ."
  end
end
