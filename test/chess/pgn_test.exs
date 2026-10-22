defmodule Chess.PGNTest do
  use ExUnit.Case

  alias Chess.{Board, PGN, Rules}
  alias Chess.PGN.ParseError

  @fixtures [
    %{
      file: "The_Opera_game.pgn",
      event: "Paris",
      white: "Paul Morphy",
      black: "Duke Karl / Count Isouard",
      result: "1-0",
      plies: 33,
      checkmate: true,
      in_check: true,
      final: """
      . n . R k b . r
      p . . . . p p p
      . . . . q . . .
      . . . . p . B .
      . . . . P . . .
      . . . . . . . .
      P P P . . P P P
      . . K . . . . .
      """
    },
    %{
      file: "anderssen-kieseritzky-1851.pgn",
      event: "Casual game: traditional score and illustrative finish",
      white: "Adolf Anderssen",
      black: "Lionel Kieseritzky",
      result: "1-0",
      plies: 45,
      checkmate: true,
      in_check: true,
      final: """
      r . b k . . . r
      p . . p B p N p
      n . . . . n . .
      . p . N P . . P
      . . . . . . P .
      . . . P . . . .
      P . P . K . . .
      q . . . . . b .
      """
    },
    %{
      file: "anderssen_dufresne_1852.pgn",
      event: "Casual Game",
      white: "Adolf Anderssen",
      black: "Jean Dufresne",
      result: "1-0",
      plies: 40,
      checkmate: false,
      in_check: false,
      final: """
      . r . . k . r .
      p b p p n p . p
      . b . . . P . .
      . . . . . . . .
      Q . . . . . . .
      B . P B . q . .
      P . . . . P P P
      . . . R . . K .
      """
    },
    %{
      file: "steinitz-bardeleben-1895.pgn",
      event: "?",
      white: "Wilhelm Steinitz",
      black: "Curt von Bardeleben",
      result: "1-0",
      plies: 49,
      checkmate: false,
      in_check: true,
      final: """
      r . r . . . . k
      p p . q . . . R
      . . . . . p p .
      . . . p . . N .
      . . . . . . Q .
      . . . . . . . .
      P P . . . P P P
      . . R . . . K .
      """
    },
    %{
      file: "rotlewi-rubinstein-1907.pgn",
      event: "?",
      white: "Gersz Rotlewi",
      black: "Akiba Rubinstein",
      result: "0-1",
      plies: 50,
      checkmate: false,
      in_check: false,
      final: """
      . . . . . . k .
      . . . . . p p p
      p b . . p . . .
      . p . . P . . .
      . P . . b P n P
      P . . . . . . r
      . B . . . . Q P
      R . . . . R . K
      """
    },
    %{
      file: "The-Game-of-the-Century-Byrnne-Fisher.pgn",
      event: "Third Rosenwald Trophy",
      white: "Donald Byrne",
      black: "Robert James Fischer",
      result: "0-1",
      plies: 82,
      checkmate: true,
      in_check: true,
      final: """
      . Q . . . . . .
      . . . . . p k .
      . . p . . . p .
      . p . . N . . p
      . b . . . . . P
      . b n . . . . .
      . . r . . . P .
      . . K . . . . .
      """
    },
    %{
      file: "Deep_Blue_vs_Kasparov.pgn",
      event: "IBM Man-Machine",
      white: "Deep Blue (Computer)",
      black: "Garry Kasparov",
      result: "1-0",
      plies: 37,
      checkmate: false,
      in_check: false,
      final: """
      r . k . . . . r
      p . . n b . p .
      . . b . . . . p
      . p . n . p . .
      . . P P . . . .
      . . . Q . N B .
      . P . . . P P P
      R . . . . . K .
      """
    },
    %{
      file: "karpov-kasparov-game-16.pgn",
      event: "World Chess Championship, Game 16",
      white: "Anatoly Karpov",
      black: "Garry Kasparov",
      result: "0-1",
      plies: 80,
      checkmate: false,
      in_check: true,
      final: """
      . . . . . . . .
      . . . . . p k .
      . . . . . . . p
      . . . . . . . .
      . p . . . . P .
      . P . R . . P .
      . . . N . q B P
      . . . N r . . K
      """
    },
    %{
      file: "Kasparovs-Immortal-Kasparov-Topalov.pgn",
      event: "Hoogovens Group A",
      white: "Garry Kasparov",
      black: "Veselin Topalov",
      result: "1-0",
      plies: 87,
      checkmate: false,
      in_check: false,
      final: """
      . . . . . . . .
      Q . . . . . . p
      . . . . . . p .
      . . . . . p . .
      . . . . . P . .
      . . p . . . P .
      . . . r . . . P
      . . K . k . . .
      """
    },
    %{
      file: "aronian-anand-2013.pgn",
      event: "Tata Steel-A 75th",
      white: "Levon Aronian",
      black: "Viswanathan Anand",
      result: "0-1",
      plies: 46,
      checkmate: false,
      in_check: false,
      final: """
      . . r . . . k .
      p b . . . . p .
      . . . . p . . .
      . p . . . p . q
      . . . . . P n .
      P . N Q b . . P
      . P . . . . P .
      R . B . . R . K
      """
    },
    %{
      file: "synthetic_special_moves.pgn",
      event: "Synthetic Special Moves",
      white: "Engine",
      black: "Engine",
      result: "1-0",
      plies: 31,
      checkmate: false,
      in_check: false,
      final: """
      Q . b q . r k .
      p . p . . p . .
      . . p P p n . b
      . . . . . . p .
      . n . P . . . .
      . . N . B . . p
      P . P . Q P P P
      . . K R . B . R
      """
    },
    %{
      file: "fen_start.pgn",
      event: "FEN Start",
      white: "Engine",
      black: "Engine",
      result: "1-0",
      plies: 16,
      checkmate: false,
      in_check: false,
      final: """
      r . b q . r k .
      . . p n b p p p
      p . . p . n . .
      . p . . p . . .
      . . . P P . . .
      . B P . . N . P
      P P . . . P P .
      R N B Q R . K .
      """
    }
  ]

  defp fixture_path(file), do: Path.join([__DIR__, "..", "fixtures", file])

  describe "parse/2" do
    test "reads the tag pairs" do
      pgn =
        PGN.parse("""
        [Event "Test Event"]
        [Site "Somewhere"]
        [Result "1-0"]

        1. e4 e5 2. Nf3 Nc6 1-0
        """)

      assert pgn.headers["Event"] == "Test Event"
      assert pgn.headers["Site"] == "Somewhere"
      assert pgn.headers["Result"] == "1-0"
      assert pgn.result == "1-0"
    end

    test "reads a tag value with an escaped quote" do
      pgn =
        PGN.parse("""
        [Event "A \\"quoted\\" event"]

        1. e4 1-0
        """)

      assert pgn.headers["Event"] == ~s(A "quoted" event)
    end

    test "reads the moves in the order they were played" do
      pgn =
        PGN.parse("""
        [Result "1-0"]

        1. e4 e5 2. Nf3 Nc6 1-0
        """)

      assert pgn.moves == [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}, {:b8, :c6}]
    end

    test "reads a move number that is glued to the move" do
      pgn = PGN.parse("1.e4 e5 2.Nf3 1-0")

      assert pgn.moves == [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}]
    end

    test "reads a move number that is written for both sides" do
      pgn = PGN.parse("1. e4 1... e5 2. Nf3 2... Nc6 1-0")

      assert pgn.moves == [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}, {:b8, :c6}]
    end

    test "reads a move without a number" do
      pgn = PGN.parse("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O 1-0")

      assert pgn.moves == [
               {:e2, :e4},
               {:e7, :e5},
               {:g1, :f3},
               {:b8, :c6},
               {:f1, :b5},
               {:a7, :a6},
               {:b5, :a4},
               {:g8, :f6},
               {:castle, :e1, :g1}
             ]
    end

    test "reads a comment" do
      pgn =
        PGN.parse("""
        [Result "1-0"]

        1. e4 {the king's pawn} e5 1-0
        """)

      assert pgn.comments == %{1 => ["the king's pawn"]}
    end

    test "reads a comment behind a semicolon" do
      pgn =
        PGN.parse("""
        [Result "1-0"]

        1. e4 ; the king's pawn
        e5 1-0
        """)

      assert pgn.comments == %{1 => ["the king's pawn"]}
    end

    test "reads a comment that stands on its own" do
      pgn =
        PGN.parse("""
        [Result "1-0"]

        {a game between friends} 1. e4 e5 1-0
        """)

      assert pgn.comments == %{0 => ["a game between friends"]}
    end

    test "reads the result of the game" do
      assert PGN.parse("1. e4 1-0").result == "1-0"
      assert PGN.parse("1. e4 0-1").result == "0-1"
      assert PGN.parse("1. e4 1/2-1/2").result == "1/2-1/2"
      assert PGN.parse("1. e4 *").result == "*"
    end

    test "takes the result from the tag pair when the moves hold none" do
      pgn = PGN.parse("[Result \"1-0\"]\n\n1. e4")

      assert pgn.result == "1-0"
    end

    test "raises when a move is not legal" do
      assert_raise ParseError, ~r/no legal move matches/, fn ->
        PGN.parse("1. e5 e5 1-0")
      end
    end

    test "raises when a move number does not fit" do
      assert_raise ParseError, ~r/expected move 1, found 3/, fn ->
        PGN.parse("3. e4 e5 1-0")
      end
    end

    test "raises when the document holds no game" do
      assert_raise ParseError, ~r/holds no game/, fn -> PGN.parse("") end
    end

    test "raises when the document holds more than one game" do
      assert_raise ParseError, ~r/holds 2 games/, fn ->
        PGN.parse("[Event \"One\"]\n\n1. e4 1-0\n\n[Event \"Two\"]\n\n1. d4 0-1")
      end
    end
  end

  describe "parse_all/2" do
    test "reads every game of a document" do
      games =
        PGN.parse_all("""
        [Event "One"]

        1. e4 1-0

        [Event "Two"]

        1. d4 0-1
        """)

      assert length(games) == 2
      assert Enum.map(games, & &1.headers["Event"]) == ["One", "Two"]
      assert Enum.map(games, & &1.result) == ["1-0", "0-1"]
    end
  end

  describe "to_pgn/1" do
    test "writes the tag pairs of the seven tag roster first" do
      pgn =
        PGN.parse("""
        [Event "Test Event"]
        [Site "Somewhere"]
        [Date "2026.10.21"]
        [Round "1"]
        [White "White"]
        [Black "Black"]
        [Result "1-0"]
        [ECO "C20"]

        1. e4 e5 1-0
        """)

      text = PGN.to_pgn(pgn)

      assert text =~ "[Event \"Test Event\"]\n"
      assert text =~ "[Result \"1-0\"]\n"
      assert text =~ "[ECO \"C20\"]\n"
      assert text =~ "\n1. e4 e5\n1-0\n"
    end

    test "writes a game that holds no tag pairs" do
      pgn = PGN.parse("1. e4 e5 1-0")

      text = PGN.to_pgn(pgn)

      assert text =~ "[Event \"?\"]"
      assert text =~ "[Result \"1-0\"]"
      assert text =~ "1. e4 e5"
    end

    test "writes the comments of the game" do
      pgn = PGN.parse("1. e4 {the king's pawn} e5 1-0")

      assert PGN.to_pgn(pgn) =~ "1. e4 {the king's pawn} e5"
    end

    test "writes a tag value with a quote escaped" do
      pgn = PGN.parse(~s([Event "A \\"quoted\\" event"]\n\n1. e4 1-0))

      text = PGN.to_pgn(pgn)

      assert text =~ ~s([Event "A \\"quoted\\" event"])
      assert PGN.parse(text).headers["Event"] == ~s(A "quoted" event)
    end

    test "raises when a move cannot be written" do
      pgn = %PGN.Game{
        headers: %{},
        moves: [{:e2, :e5}],
        result: "1-0",
        comments: %{},
        game: Chess.Game.new()
      }

      assert_raise ParseError, ~r/is not a legal move/, fn -> PGN.to_pgn(pgn) end
    end
  end

  describe "parse/2 and to_pgn/1" do
    test "a game survives the round trip" do
      pgn = PGN.parse("1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0")
      written = PGN.to_pgn(pgn)
      read = PGN.parse(written)

      assert read.moves == pgn.moves
      assert read.result == pgn.result
      assert read.comments == pgn.comments
    end
  end

  describe "a game that starts from a FEN" do
    @fen "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"
    @fen_black "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 2 3"

    test "reads the moves against the position of the tag" do
      pgn = PGN.parse(~s([SetUp "1"]\n[FEN "#{@fen}"]\n\n3. Bb5 a6 1-0))

      assert pgn.moves == [{:f1, :b5}, {:a7, :a6}]
      assert pgn.game.board[:b5] == :B
    end

    test "raises when a move is not legal in that position" do
      assert_raise ParseError, ~r/no legal move matches/, fn ->
        PGN.parse(~s([FEN "#{@fen}"]\n\n3. Nc6 Nc6 1-0))
      end
    end

    test "raises when the tag is not a FEN record" do
      assert_raise ParseError, ~r/the FEN tag is not a FEN record/, fn ->
        PGN.parse(~s([FEN "not a FEN record"]\n\n1. e4 1-0))
      end
    end

    test "the move numbers start in the middle of the game" do
      pgn = PGN.parse(~s([FEN "#{@fen}"]\n\n3. Bb5 a6 1-0))

      assert PGN.to_pgn(pgn) =~ "3. Bb5 a6"
    end

    test "the move numbers of a game that starts with Black carry the dots" do
      pgn = PGN.parse(~s([FEN "#{@fen_black}"]\n\n3... Nf6 1-0))

      assert PGN.to_pgn(pgn) =~ "3... Nf6"
    end

    test "writes the position of the game as a tag" do
      pgn = PGN.parse(~s([FEN "#{@fen}"]\n\n3. Bb5 a6 1-0))

      text = PGN.to_pgn(pgn)

      assert text =~ ~s([SetUp "1"]\n)
      assert text =~ ~s([FEN "#{@fen}"]\n)
    end

    test "a game that starts from the initial position is written without the tag" do
      text = PGN.to_pgn(PGN.parse("1. e4 e5 1-0"))

      refute text =~ "SetUp"
      refute text =~ "FEN"
    end

    test "the game of the fixture survives the round trip" do
      pgn = PGN.parse_file(fixture_path("fen_start.pgn"))
      read = PGN.parse(PGN.to_pgn(pgn))

      assert read.moves == pgn.moves
      assert read.game.board == pgn.game.board
      assert read.headers["FEN"] == @fen
    end
  end

  for fixture <- @fixtures do
    test "reads #{fixture.file}" do
      fixture = unquote(Macro.escape(fixture))
      pgn = PGN.parse_file(fixture_path(fixture.file))

      assert pgn.headers["Event"] == fixture.event
      assert pgn.headers["White"] == fixture.white
      assert pgn.headers["Black"] == fixture.black
      assert pgn.headers["Result"] == fixture.result
      assert pgn.result == fixture.result
      assert length(pgn.moves) == fixture.plies
      assert Rules.checkmate?(pgn.game) == fixture.checkmate
      assert Rules.in_check?(pgn.game) == fixture.in_check
      assert Board.to_ascii(pgn.game.board) == String.trim(fixture.final)
    end

    test "writes #{fixture.file} back" do
      fixture = unquote(Macro.escape(fixture))
      pgn = PGN.parse_file(fixture_path(fixture.file))
      written = PGN.to_pgn(pgn)
      read = PGN.parse(written)

      assert read.moves == pgn.moves
      assert read.result == pgn.result
      assert read.comments == pgn.comments
      assert Map.take(read.headers, Map.keys(pgn.headers)) == pgn.headers
    end
  end

  test "the mate in four of the Dufresne game stands in a comment" do
    pgn = PGN.parse_file(fixture_path("anderssen_dufresne_1852.pgn"))

    assert Map.keys(pgn.comments) == [40]
    assert pgn.comments[40] |> hd() =~ "24.Bxe7#"
    assert length(pgn.moves) == 40
  end

  test "the continuation of the Kieseritzky game stands in a comment" do
    pgn = PGN.parse_file(fixture_path("anderssen-kieseritzky-1851.pgn"))

    assert Map.keys(pgn.comments) == [39]
    assert pgn.comments[39] |> hd() =~ "traditional continuation"
    assert length(pgn.moves) == 45
  end
end
