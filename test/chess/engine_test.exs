defmodule Chess.EngineTest do
  use ExUnit.Case

  alias Chess.{Engine, Game, Rules}

  describe "play/2" do
    test "plays a move from the initial position" do
      game = Game.new()

      assert {:ok, new_game, move} = Engine.play(game)
      assert move in Rules.legal_moves(game)
      assert new_game.side_to_move == :black
      assert length(new_game.moves) == 1
    end

    test "plays randomly when strategy is :random" do
      game = Game.new()

      assert {:ok, _new_game, move} = Engine.play(game, strategy: :random)
      assert move in Rules.legal_moves(game)
    end

    test "plays with best strategy by default" do
      game = Game.new()

      assert {:ok, _new_game, _move} = Engine.play(game)
    end

    test "returns error for checkmate" do
      # Fool's mate: black mates white
      game =
        Enum.reduce([{:f2, :f3}, {:e7, :e5}, {:g2, :g4}, {:d8, :h4}], Game.new(), fn move, game ->
          Rules.apply(game, move)
        end)

      assert Game.status(game) == :checkmate
      assert {:error, :checkmate} = Engine.play(game)
    end

    test "returns error for stalemate" do
      # Black king on a8 has no legal move and is not in check
      game = %Game{board: %{a8: :k, c7: :K, b6: :Q}, side_to_move: :black}

      assert Game.status(game) == :stalemate
      assert {:error, :stalemate} = Engine.play(game)
    end

    test "returns error for draw" do
      game = %Game{board: %{e1: :K, e8: :k}, side_to_move: :white}

      assert Game.status(game) == :draw_insufficient_material
      assert {:error, :draw_insufficient_material} = Engine.play(game)
    end
  end

  describe "random_move/1" do
    test "returns a legal move" do
      game = Game.new()

      assert {:ok, move} = Engine.random_move(game)
      assert move in Rules.legal_moves(game)
    end

    test "returns error for terminal position" do
      game = %Game{board: %{a8: :k, c7: :K, b6: :Q}, side_to_move: :black}

      assert {:error, :stalemate} = Engine.random_move(game)
    end
  end

  describe "best_move/1" do
    test "returns a legal move" do
      game = Game.new()

      assert {:ok, move} = Engine.best_move(game)
      assert move in Rules.legal_moves(game)
    end

    test "returns error for terminal position" do
      game =
        Enum.reduce([{:f2, :f3}, {:e7, :e5}, {:g2, :g4}, {:d8, :h4}], Game.new(), fn move, game ->
          Rules.apply(game, move)
        end)

      assert {:error, :checkmate} = Engine.best_move(game)
    end

    test "captures material when possible" do
      # White can capture black queen
      game = %Game{
        board: %{e1: :K, d1: :Q, d5: :q, e8: :k},
        side_to_move: :white,
        castling: MapSet.new()
      }

      assert {:ok, move} = Engine.best_move(game)
      # Queen captures queen on d5
      assert move == {:d1, :d5}
    end

    test "works from black's perspective" do
      # Black can capture white queen
      game = %Game{
        board: %{e1: :K, d5: :Q, d8: :q, e8: :k},
        side_to_move: :black,
        castling: MapSet.new()
      }

      assert {:ok, move} = Engine.best_move(game)
      assert move in Rules.legal_moves(game)
      # Black should capture the queen
      applied = Rules.apply(game, move)
      # After move, queen should be captured
      assert applied.board[:d5] == nil or applied.board[:d5] != :Q
    end
  end
end
