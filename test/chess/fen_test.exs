defmodule Chess.FENTest do
  use ExUnit.Case

  alias Chess.{Board, FEN, Game, Rules}
  alias Chess.FEN.ParseError

  @initial "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  describe "parse/1" do
    test "reads the initial position" do
      game = FEN.parse(@initial)

      assert game.board == Board.initial()
      assert game.side_to_move == :white
      assert game.en_passant == nil
      assert game.halfmove_clock == 0
      assert game.fullmove_number == 1
      assert game.moves == []
    end

    test "reads all four castling rights" do
      game = FEN.parse(@initial)

      assert game.castling ==
               MapSet.new([
                 {:white, :king_side},
                 {:white, :queen_side},
                 {:black, :king_side},
                 {:black, :queen_side}
               ])
    end

    test "reads a part of the castling rights" do
      game = FEN.parse("r3k2r/8/8/8/8/8/8/R3K2R w Kq - 0 1")

      assert game.castling == MapSet.new([{:white, :king_side}, {:black, :queen_side}])
    end

    test "reads no castling rights" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 0 1")

      assert game.castling == MapSet.new()
    end

    test "reads the side to move" do
      assert FEN.parse("4k3/8/8/8/8/8/8/4K3 b - - 0 1").side_to_move == :black
    end

    test "reads the en passant target" do
      assert FEN.parse("4k3/8/8/8/8/8/8/4K3 w - e6 0 1").en_passant == :e6
      assert FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 0 1").en_passant == nil
    end

    test "reads the counters" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 17 42")

      assert game.halfmove_clock == 17
      assert game.fullmove_number == 42
    end

    test "reads a record of four fields, with the counters left out" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - -")

      assert game.board == %{e1: :K, e8: :k}
      assert game.halfmove_clock == 0
      assert game.fullmove_number == 1
    end

    test "reads a record that is not a position of a real game" do
      game = FEN.parse("8/8/8/8/8/8/8/8 w - - 0 1")

      assert game.board == %{}
    end

    test "reads a record with more than one space between the fields" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3  w   -  -  0  1")

      assert game.board == %{e1: :K, e8: :k}
    end

    test "the position is the start of the game" do
      game = FEN.parse(@initial)

      assert game.start.board == game.board
      assert game.start.side_to_move == game.side_to_move
      assert game.start.moves == []
    end

    test "raises when the record holds too few fields" do
      assert_raise ParseError, ~r/holds four or six fields, found 3/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w -")
      end
    end

    test "raises when the record holds too many fields" do
      assert_raise ParseError, ~r/holds four or six fields, found 7/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 0 1 1")
      end
    end

    test "raises when a piece is unknown" do
      assert_raise ParseError, ~r/unknown piece "X"/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4KX2 w - - 0 1")
      end
    end

    test "raises when a rank holds too many squares" do
      assert_raise ParseError, ~r/holds more than eight squares/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3K w - - 0 1")
      end
    end

    test "raises when a rank holds too few squares" do
      assert_raise ParseError, ~r/the rank 8 holds eight squares, found 7/, fn ->
        FEN.parse("4k2/8/8/8/8/8/8/4K3 w - - 0 1")
      end
    end

    test "raises when the board holds the wrong number of ranks" do
      assert_raise ParseError, ~r/the board holds eight ranks, found 7/, fn ->
        FEN.parse("4k3/8/8/8/8/8/4K3 w - - 0 1")
      end
    end

    test "raises when the side to move is unknown" do
      assert_raise ParseError, ~r/the side to move is not w or b/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 x - - 0 1")
      end
    end

    test "raises when a castling right is unknown" do
      assert_raise ParseError, ~r/unknown castling right "X"/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w X - 0 1")
      end
    end

    test "raises when the en passant target is not a square" do
      assert_raise ParseError, ~r/the en passant target is not a square/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w - z9 0 1")
      end
    end

    test "raises when a counter is not a number" do
      assert_raise ParseError, ~r/the halfmove clock is not a number/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - x 1")
      end
    end

    test "raises when a counter is negative" do
      assert_raise ParseError, ~r/the halfmove clock is not a number/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - -1 1")
      end
    end

    test "raises when the fullmove number is below one" do
      assert_raise ParseError, ~r/the fullmove number starts at 1/, fn ->
        FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 0 0")
      end
    end
  end

  describe "to_fen/1" do
    test "writes the initial position" do
      assert FEN.to_fen(Game.new()) == @initial
    end

    test "writes the empty squares of a rank as a number" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 0 1")

      assert FEN.to_fen(game) == "4k3/8/8/8/8/8/8/4K3 w - - 0 1"
    end

    test "writes no castling rights as a dash" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 0 1")

      assert FEN.to_fen(game) =~ " w - - "
    end

    test "writes the castling rights in the order KQkq" do
      game = FEN.parse("r3k2r/8/8/8/8/8/8/R3K2R w qkQK - 0 1")

      assert FEN.to_fen(game) == "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
    end

    test "writes the en passant target" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - e6 0 1")

      assert FEN.to_fen(game) == "4k3/8/8/8/8/8/8/4K3 w - e6 0 1"
    end

    test "writes the counters" do
      game = FEN.parse("4k3/8/8/8/8/8/8/4K3 w - - 17 42")

      assert FEN.to_fen(game) == "4k3/8/8/8/8/8/8/4K3 w - - 17 42"
    end
  end

  describe "parse/1 and to_fen/1" do
    test "a record survives the round trip" do
      records = [
        @initial,
        "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
        "4k3/8/8/8/8/8/8/4K3 w - - 17 42",
        "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
        "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"
      ]

      for record <- records do
        assert FEN.to_fen(FEN.parse(record)) == record
      end
    end

    test "a game survives the round trip" do
      game =
        FEN.parse("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
        |> Rules.apply({:e1, :g1})

      read = FEN.parse(FEN.to_fen(game))

      assert read.board == game.board
      assert read.side_to_move == game.side_to_move
      assert read.castling == game.castling
      assert read.en_passant == game.en_passant
      assert read.halfmove_clock == game.halfmove_clock
      assert read.fullmove_number == game.fullmove_number
    end
  end

  describe "the rules and the FEN" do
    test "a move updates the en passant target and the counters" do
      game = FEN.parse(@initial) |> Rules.apply({:e2, :e4})

      assert FEN.to_fen(game) == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    end

    test "the fullmove number goes up after the move of Black" do
      game =
        FEN.parse(@initial)
        |> Rules.apply({:e2, :e4})
        |> Rules.apply({:e7, :e5})

      assert FEN.to_fen(game) == "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"
    end

    test "the halfmove clock goes up after a quiet move" do
      game = FEN.parse(@initial) |> Rules.apply({:g1, :f3})

      assert FEN.to_fen(game) == "rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1"
    end

    test "the halfmove clock starts over after a capture" do
      game =
        FEN.parse("4k3/8/8/3p4/4P3/8/8/4K3 w - - 20 30")
        |> Rules.apply({:e4, :d5})

      assert FEN.to_fen(game) == "4k3/8/8/3P4/8/8/8/4K3 b - - 0 30"
    end
  end
end
