defmodule Chess.UCITest do
  use ExUnit.Case

  alias Chess.{FEN, UCI}

  @version Mix.Project.config()[:version]

  describe "handle/2" do
    test "identifies the engine" do
      assert {:reply, lines, _state} = UCI.handle(UCI.new(), "uci")
      assert "id name ChessEx #{@version}" in lines
      assert "id author ChessEx contributors" in lines
      assert List.last(lines) == "uciok"
    end

    test "answers isready" do
      assert {:reply, ["readyok"], _state} = UCI.handle(UCI.new(), "isready")
    end

    test "ucinewgame starts over" do
      {:reply, [], state} =
        UCI.handle(UCI.new(), "position startpos moves e2e4 e7e5")

      assert state.game.side_to_move == :white

      assert {:reply, [], reset} = UCI.handle(state, "ucinewgame")
      assert FEN.to_fen(reset.game) == FEN.to_fen(Chess.Game.new())
    end

    test "reads a start position and its moves" do
      assert {:reply, [], state} =
               UCI.handle(UCI.new(), "position startpos moves e2e4 e7e5")

      assert FEN.to_fen(state.game) ==
               "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"
    end

    test "reads a FEN record" do
      fen = "8/8/8/8/8/8/4K3/4k3 w - - 0 1"

      assert {:reply, [], state} = UCI.handle(UCI.new(), "position fen " <> fen)
      assert FEN.to_fen(state.game) == fen
    end

    test "reads moves after a FEN record" do
      fen = "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"

      assert {:reply, [], state} =
               UCI.handle(UCI.new(), "position fen #{fen} moves e5d6")

      assert FEN.to_fen(state.game) == "4k3/8/3P4/8/8/8/8/4K3 b - - 0 1"
    end

    test "reads a castle" do
      fen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"

      assert {:reply, [], state} =
               UCI.handle(UCI.new(), "position fen #{fen} moves e1g1")

      assert state.game.moves == [{:castle, :e1, :g1}]
      assert FEN.to_fen(state.game) == "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1"
    end

    test "reads a promotion" do
      fen = "8/P7/8/8/8/8/8/K6k w - - 0 1"

      assert {:reply, [], state} =
               UCI.handle(UCI.new(), "position fen #{fen} moves a7a8q")

      assert state.game.moves == [{:promotion, :a7, :a8, :Q}]
      assert FEN.to_fen(state.game) == "Q7/8/8/8/8/8/8/K6k b - - 0 1"
    end

    test "keeps the old position after an invalid FEN" do
      {:reply, [], state} = UCI.handle(UCI.new(), "position startpos moves e2e4")

      assert {:reply, ["info string invalid FEN"], unchanged} =
               UCI.handle(state, "position fen not a fen")

      assert unchanged.game == state.game
    end

    test "keeps the old position after an illegal move" do
      {:reply, [], state} = UCI.handle(UCI.new(), "position startpos moves e2e4")

      assert {:reply, ["info string illegal move: e2e5"], unchanged} =
               UCI.handle(state, "position startpos moves e2e5")

      assert unchanged.game == state.game
    end

    test "asks for a search on go" do
      assert {:search, %{max_depth: 3, budget_ms: nil}, _state} =
               UCI.handle(UCI.new(), "go")
    end

    test "stops and quits" do
      assert {:stop, _state} = UCI.handle(UCI.new(), "stop")
      assert {:quit, _state} = UCI.handle(UCI.new(), "quit")
    end

    test "ignores debug and setoption" do
      assert {:reply, [], _state} = UCI.handle(UCI.new(), "debug on")
      assert {:reply, [], _state} = UCI.handle(UCI.new(), "setoption name Foo value Bar")
    end

    test "reports an unknown command" do
      assert {:reply, ["info string unknown command: frobnicate"], _state} =
               UCI.handle(UCI.new(), "frobnicate")
    end
  end

  describe "plan_go/2" do
    test "uses the default depth without options" do
      assert UCI.plan_go([], :white) == %{max_depth: 3, budget_ms: nil}
    end

    test "honours depth" do
      assert UCI.plan_go(["depth", "2"], :white) == %{max_depth: 2, budget_ms: nil}
      assert UCI.plan_go(["depth", "0"], :white) == %{max_depth: 1, budget_ms: nil}
    end

    test "honours movetime" do
      assert UCI.plan_go(["movetime", "1200"], :white) ==
               %{max_depth: 4, budget_ms: 1200}
    end

    test "honours infinite" do
      assert UCI.plan_go(["infinite"], :white) == %{max_depth: 4, budget_ms: nil}
    end

    test "uses the clock of the side to move" do
      arguments = ["wtime", "300000", "btime", "60000", "winc", "2000", "binc", "0"]

      assert %{max_depth: 4, budget_ms: 11_000} = UCI.plan_go(arguments, :white)
      assert %{max_depth: 4, budget_ms: 2_000} = UCI.plan_go(arguments, :black)
    end

    test "divides by the moves to go" do
      arguments = ["wtime", "300000", "winc", "2000", "movestogo", "10"]

      assert %{max_depth: 4, budget_ms: 31_000} = UCI.plan_go(arguments, :white)
    end

    test "lets depth win over a time limit" do
      assert UCI.plan_go(["depth", "2", "movetime", "1000"], :white) ==
               %{max_depth: 2, budget_ms: nil}
    end

    test "lets movetime win over the clock" do
      assert UCI.plan_go(["wtime", "300000", "movetime", "500"], :white) ==
               %{max_depth: 4, budget_ms: 500}
    end

    test "ignores unknown options" do
      assert UCI.plan_go(["nodes", "1000", "ponder"], :white) ==
               %{max_depth: 3, budget_ms: nil}
    end
  end

  describe "parse_move/2" do
    test "parses a normal move" do
      assert {:ok, {:e2, :e4}} = UCI.parse_move(Chess.Game.new(), "e2e4")
    end

    test "rejects an illegal move" do
      assert :error = UCI.parse_move(Chess.Game.new(), "e2e5")
    end

    test "rejects a malformed token" do
      assert :error = UCI.parse_move(Chess.Game.new(), "e2")
      assert :error = UCI.parse_move(Chess.Game.new(), "e2e4x")
      assert :error = UCI.parse_move(Chess.Game.new(), "0000")
    end

    test "parses a castle" do
      game = FEN.parse("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")

      assert {:ok, {:castle, :e1, :g1}} = UCI.parse_move(game, "e1g1")
      assert {:ok, {:castle, :e1, :c1}} = UCI.parse_move(game, "e1c1")
    end

    test "parses an en passant capture" do
      game = FEN.parse("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")

      assert {:ok, {:en_passant, :e5, :d6}} = UCI.parse_move(game, "e5d6")
    end

    test "parses a promotion" do
      game = FEN.parse("8/P7/8/8/8/8/8/K6k w - - 0 1")

      assert {:ok, {:promotion, :a7, :a8, :Q}} = UCI.parse_move(game, "a7a8q")
      assert {:ok, {:promotion, :a7, :a8, :Q}} = UCI.parse_move(game, "a7a8Q")
    end

    test "rejects a promotion without the promotion piece" do
      game = FEN.parse("8/P7/8/8/8/8/8/K6k w - - 0 1")

      assert :error = UCI.parse_move(game, "a7a8")
    end
  end

  describe "to_uci/1" do
    test "writes the kinds of moves" do
      assert UCI.to_uci({:e2, :e4}) == "e2e4"
      assert UCI.to_uci({:castle, :e1, :g1}) == "e1g1"
      assert UCI.to_uci({:en_passant, :e5, :d6}) == "e5d6"
      assert UCI.to_uci({:promotion, :e7, :e8, :Q}) == "e7e8q"
      assert UCI.to_uci({:promotion, :e2, :e1, :q}) == "e2e1q"
    end
  end

  describe "format_score/1" do
    test "writes centipawns" do
      assert UCI.format_score(0) == "cp 0"
      assert UCI.format_score(150) == "cp 150"
      assert UCI.format_score(-150) == "cp -150"
    end

    test "writes mate distances" do
      assert UCI.format_score(99_999) == "mate 1"
      assert UCI.format_score(99_997) == "mate 2"
      assert UCI.format_score(-99_997) == "mate -2"
    end
  end
end
