defmodule Chess.NarratorTest do
  use ExUnit.Case

  alias Chess.{FEN, Game, Narrator, Rules}

  # The steps of a description, each as a list of lines.
  defp steps(input) do
    input
    |> Narrator.describe()
    |> String.split("\n\n")
    |> Enum.map(&String.split(&1, "\n"))
  end

  # The first lines of every step: the label of a step, not its board.
  defp headings(input) do
    input
    |> steps()
    |> Enum.map(&hd/1)
  end

  # The step of the last ply, with its board.
  defp last_step(input) do
    input
    |> steps()
    |> Enum.at(-2)
  end

  describe "describe/1" do
    test "names the players of a PGN game" do
      pgn = Chess.PGN.parse_file(fixture_path("The_Opera_game.pgn"))

      assert Narrator.describe(pgn) =~ "Paul Morphy (White) vs Duke Karl / Count Isouard (Black)"
    end

    test "describes the initial position first" do
      input = [{:e2, :e4}]

      assert headings(input) |> hd() == "Initial position"

      [initial | _moves] = steps(input)

      assert initial |> Enum.at(1) == "r n b q k b n r"

      assert initial |> List.last() ==
               "Evaluation: +0.00 for White (material +0.00, positional +0.00)"
    end

    test "puts the notation on its own line and the move in words below it" do
      [_initial, move | _rest] = steps([{:e2, :e4}])

      assert move |> hd() == "1. e4"
      assert move |> Enum.at(1) == "white pawn from e2 to e4, advances two squares"
    end

    test "shows the board after every move and the strength of the position" do
      [_initial, move | _rest] = steps([{:e2, :e4}])

      assert move |> Enum.at(2) == "r n b q k b n r"
      assert move |> Enum.at(6) == ". . . . P . . ."

      assert move |> List.last() ==
               "Evaluation: +0.00 for White (material +0.00, positional +0.00)"
    end

    test "numbers the plies of both sides" do
      input = [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}]

      assert headings(input) |> Enum.drop(-1) == ["Initial position", "1. e4", "2. e5", "3. Nf3"]
    end
  end

  describe "describing a move" do
    test "names the piece and the squares it moved between" do
      assert second_line([{:g1, :f3}]) == "white knight from g1 to f3"
      assert second_line([{:e2, :e4}, {:e7, :e5}, {:g1, :f3}]) == "white knight from g1 to f3"
      assert second_line([{:d2, :d4}]) == "white pawn from d2 to d4, advances two squares"
    end

    test "names the piece a capture takes" do
      input = [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}, {:b8, :c6}, {:f3, :e5}]

      assert second_line(input) == "white knight from f3 to e5, captures black pawn on e5"
    end

    test "names the pawn of an en passant capture" do
      input = [{:e2, :e4}, {:g8, :f6}, {:e4, :e5}, {:d7, :d5}, {:en_passant, :e5, :d6}]

      assert second_line(input) ==
               "white pawn from e5 to d6, captures black pawn on d5 en passant"
    end

    test "names the piece a promotion became" do
      input = [
        {:a2, :a4},
        {:b7, :b5},
        {:a4, :b5},
        {:b8, :c6},
        {:b5, :b6},
        {:c6, :b8},
        {:b6, :b7},
        {:b8, :c6},
        {:promotion, :b7, :b8, :Q}
      ]

      assert second_line(input) == "white pawn from b7 to b8, promotes to queen"
    end

    test "names the piece a promotion captures" do
      input = [
        {:a2, :a4},
        {:b7, :b5},
        {:a4, :b5},
        {:g8, :f6},
        {:b5, :b6},
        {:f6, :g8},
        {:b6, :b7},
        {:g8, :f6},
        {:promotion, :b7, :a8, :N}
      ]

      assert second_line(input) ==
               "white pawn from b7 to a8, captures black rook on a8, promotes to knight"
    end

    test "names the rook of a castle" do
      input = [
        {:e2, :e4},
        {:e7, :e5},
        {:g1, :f3},
        {:b8, :c6},
        {:f1, :c4},
        {:g8, :f6},
        {:castle, :e1, :g1}
      ]

      assert second_line(input) ==
               "white king castles king side from e1 to g1, rook from h1 to f1"
    end

    test "says when a move gives check" do
      input = [{:e2, :e4}, {:e7, :e5}, {:f1, :c4}, {:b8, :c6}, {:d1, :h5}, {:g8, :f6}, {:h5, :e5}]

      assert second_line(input) ==
               "white queen from h5 to e5, captures black pawn on e5, black is in check"
    end

    test "says when a move gives checkmate" do
      input = [{:e2, :e4}, {:e7, :e5}, {:f1, :c4}, {:b8, :c6}, {:d1, :h5}, {:g8, :f6}, {:h5, :f7}]

      assert second_line(input) ==
               "white queen from h5 to f7, captures black pawn on f7, black is checkmated"
    end
  end

  describe "the end of the game" do
    test "says who wins by checkmate" do
      pgn =
        Chess.PGN.parse("""
        [White "White"]
        [Black "Black"]
        [Result "1-0"]

        1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#
        1-0
        """)

      assert Narrator.describe(pgn) |> String.ends_with?("black is checkmated. White wins (1-0).")
    end

    test "says who wins by the result of the game" do
      pgn = Chess.PGN.parse("[Result \"0-1\"]\n\n1. e4 e5 0-1")

      assert Narrator.describe(pgn) |> String.ends_with?("Black wins (0-1).")
    end

    test "says a drawn game is drawn" do
      pgn = Chess.PGN.parse("[Result \"1/2-1/2\"]\n\n1. e4 e5 1/2-1/2")

      assert Narrator.describe(pgn) |> String.ends_with?("The game is drawn (1/2-1/2).")
    end

    test "mentions a check the last move gave" do
      input = [{:e2, :e4}, {:e7, :e5}, {:f1, :c4}, {:b8, :c6}, {:d1, :h5}, {:g8, :f6}, {:h5, :e5}]

      assert Narrator.describe(input)
             |> String.ends_with?("black is in check. The moves run out; the game is not over.")
    end

    test "says the moves run out when nothing ends the game" do
      assert Narrator.describe([{:e2, :e4}])
             |> String.ends_with?("The moves run out; the game is not over.")
    end

    test "says when the side to move is stalemated" do
      # The black king on a8 has no legal move and is not in check.
      game = %Game{board: %{a8: :k, b7: :p, b6: :P, c7: :Q, h1: :K}, side_to_move: :black}

      assert Rules.stalemate?(game)

      assert Narrator.describe(game)
             |> String.ends_with?("black is stalemated. The game is drawn.")
    end
  end

  describe "the game it describes" do
    test "plays a plain list of moves from the initial position" do
      assert last_step([{:e2, :e4}]) |> Enum.at(2) == "r n b q k b n r"
    end

    test "plays the moves of a game of our own in the order they were played" do
      moves = [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}]
      game = Enum.reduce(moves, Game.new(), fn move, game -> Rules.apply(game, move) end)

      assert headings(moves) == headings(game)
      assert last_step(moves) == last_step(game)
    end

    test "describes a game of our own without moves as the position it stands on" do
      game = %Game{board: %{a8: :k, h1: :K}, side_to_move: :white}

      assert headings(game) |> hd() == "Position"
      assert steps(game) |> hd() |> Enum.at(1) == "k . . . . . . ."
    end

    test "describes a PGN game and the same list of moves alike" do
      pgn =
        Chess.PGN.parse("""
        [Result "1-0"]

        1. e4 e5 2. Nf3 Nc6 1-0
        """)

      assert last_step(pgn) == last_step(pgn.moves)
    end

    test "describes a PGN game that starts from a FEN" do
      pgn =
        Chess.PGN.parse("""
        [SetUp "1"]
        [FEN "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"]

        3. Bb5 a6 1-0
        """)

      [initial | _moves] = steps(pgn)

      assert initial |> Enum.at(1) == "r . b q k b n r"
      assert headings(pgn) |> Enum.drop(-1) == ["Initial position", "1. Bb5", "2. a6"]
    end

    test "describes a game of our own that starts from a FEN" do
      game =
        FEN.parse("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
        |> Rules.apply({:f1, :b5})

      [initial | _moves] = steps(game)

      assert initial |> Enum.at(1) == "r . b q k b n r"
      assert headings(game) |> Enum.drop(-1) == ["Initial position", "1. Bb5"]
    end

    test "raises when a move is not legal in the position it is played in" do
      assert_raise ArgumentError, "move 2 is not legal in this position", fn ->
        Narrator.describe([{:e2, :e4}, {:e7, :e4}])
      end
    end
  end

  describe "print/1" do
    test "writes the description out" do
      assert ExUnit.CaptureIO.capture_io(fn -> Narrator.print([{:e2, :e4}]) end) =~ "1. e4"
    end
  end

  test "narrates the Opera game to its end" do
    pgn = Chess.PGN.parse_file(fixture_path("The_Opera_game.pgn"))
    text = Narrator.describe(pgn)

    assert text =~ "33. Rd8#"
    assert text =~ "white rook from d1 to d8, black is checkmated"
    assert text |> String.ends_with?("black is checkmated. White wins (1-0).")
  end

  # The move in words of the last ply of a list of moves.
  defp second_line(moves), do: moves |> steps() |> Enum.at(-2) |> Enum.at(1)

  defp fixture_path(file) do
    Path.join([__DIR__, "..", "fixtures", file])
  end
end
