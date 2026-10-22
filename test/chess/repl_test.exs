defmodule Chess.ReplTest do
  use ExUnit.Case

  alias Chess.{Game, Repl, Rules}

  describe "new/0" do
    test "returns a new game and prints the initial position" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert {:ok, game} = Repl.new()
          assert %Game{} = game
          assert game.side_to_move == :white
        end)

      assert output =~ "r n b q k b n r"
      assert output =~ "White to move."
    end
  end

  describe "move/2" do
    test "plays a SAN move for the side to move" do
      game = Game.new()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert {:ok, game2} = Repl.move(game, "e4")
          assert length(game2.moves) == 1
          assert game2.side_to_move == :black
          send(self(), {:game2, game2})
        end)

      assert_received {:game2, _game2}
      assert output =~ "1. e4"
      assert output =~ "Black to move."
    end

    test "plays moves for both sides" do
      game = Game.new()

      ExUnit.CaptureIO.capture_io(fn ->
        assert {:ok, game} = Repl.move(game, "e4")
        assert {:ok, game} = Repl.move(game, "e5")
        assert length(game.moves) == 2
        assert game.side_to_move == :white
      end)
    end

    test "accepts flexible SAN and is lenient with markers" do
      game = Game.new()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert {:ok, game} = Repl.move(game, "e4")
          assert {:ok, game} = Repl.move(game, "e5")
          assert {:ok, game} = Repl.move(game, "Qh5")
          assert {:ok, game} = Repl.move(game, "Nc6")
          assert {:ok, game} = Repl.move(game, "Bc4")
          assert {:ok, game} = Repl.move(game, "Nf6")
          assert {:ok, game} = Repl.move(game, "Qxf7")
          assert Rules.checkmate?(game)
        end)

      assert output =~ "checkmated"
    end

    test "returns {:error, :illegal_move} for illegal SAN" do
      game = Game.new()
      assert {:error, :illegal_move} = Repl.move(game, "e5")
    end

    test "returns {:error, :illegal_move} for garbage input" do
      game = Game.new()
      assert {:error, :illegal_move} = Repl.move(game, "notamove")
    end

    test "returns error and prints ending when game is over" do
      game =
        Enum.reduce([{:f2, :f3}, {:e7, :e5}, {:g2, :g4}, {:d8, :h4}], Game.new(), fn move, g ->
          Rules.apply(g, move)
        end)

      output =
        ExUnit.CaptureIO.capture_io(fn -> assert {:error, :checkmate} = Repl.move(game, "e3") end)

      assert output =~ "checkmated"
    end
  end

  describe "move/1" do
    test "lets the engine make a move" do
      game = Game.new()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert {:ok, game2} = Repl.move(game)
          assert length(game2.moves) == 1
          assert game2.side_to_move == :black
        end)

      assert output =~ "Black to move."
    end

    test "returns error and prints ending when game is over" do
      game =
        Enum.reduce([{:f2, :f3}, {:e7, :e5}, {:g2, :g4}, {:d8, :h4}], Game.new(), fn move, g ->
          Rules.apply(g, move)
        end)

      output =
        ExUnit.CaptureIO.capture_io(fn -> assert {:error, :checkmate} = Repl.move(game) end)

      assert output =~ "checkmated"
    end
  end
end
