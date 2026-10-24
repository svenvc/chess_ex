defmodule Chess.SearchTest do
  use ExUnit.Case

  alias Chess.{Game, Rules, Search}

  defp game(board, side_to_move \\ :white) do
    %Game{board: board, side_to_move: side_to_move, castling: MapSet.new()}
  end

  describe "best_move/2" do
    test "returns a legal move from the initial position" do
      game = Game.new()

      assert {:ok, move, score} = Search.best_move(game, depth: 1)
      assert move in Rules.legal_moves(game)
      assert is_integer(score)
    end

    test "finds a mate in one" do
      # 1. Qd8#: the queen covers the eighth rank and g8.
      game = game(%{e1: :K, d1: :Q, h8: :k, g7: :p, h7: :p})

      assert {:ok, move, score} = Search.best_move(game, depth: 1)
      assert Rules.checkmate?(Rules.apply(game, move))
      assert score > 90_000
    end

    test "captures a hanging queen" do
      game = game(%{e1: :K, d1: :Q, d5: :q, e8: :k})

      assert {:ok, {:d1, :d5}, _score} = Search.best_move(game, depth: 2)
    end

    test "captures a hanging queen as black" do
      game = game(%{e1: :K, d5: :Q, d8: :q, e8: :k}, :black)

      assert {:ok, {:d8, :d5}, _score} = Search.best_move(game, depth: 2)
    end

    test "deeper search avoids a poisoned pawn" do
      # Qxe6 wins a pawn, but the d7 pawn recaptures the queen. One ply only
      # sees the gain; two plies see the recapture. The white pawn on d6
      # blocks the queen from taking the d7 pawn instead.
      game = game(%{e1: :K, d5: :Q, d6: :P, e8: :k, d7: :p, e6: :p})

      assert {:ok, {:d5, :e6}, _score} = Search.best_move(game, depth: 1)

      assert {:ok, move, _score} = Search.best_move(game, depth: 2)
      refute move == {:d5, :e6}
    end

    test "uses the opening book by default" do
      game = Game.new()

      assert {:ok, move, 0} = Search.best_move(game)
      assert move in [{:e2, :e4}, {:d2, :d4}, {:c2, :c4}, {:g1, :f3}]
    end

    test "book: false searches the position itself" do
      game = Game.new()

      assert {:ok, move, score} = Search.best_move(game, depth: 1, book: false)
      assert move in Rules.legal_moves(game)
      assert is_integer(score)
    end

    test "randomize: false returns the same move on repeated calls" do
      game = Game.new()

      assert {:ok, move, _score} =
               Search.best_move(game, depth: 1, randomize: false, book: false)

      assert {:ok, ^move, _score} =
               Search.best_move(game, depth: 1, randomize: false, book: false)
    end

    test "returns an error for checkmate" do
      # Fool's mate: black mates white.
      game =
        Enum.reduce([{:f2, :f3}, {:e7, :e5}, {:g2, :g4}, {:d8, :h4}], Game.new(), fn move, game ->
          Rules.apply(game, move)
        end)

      assert {:error, :checkmate} = Search.best_move(game)
    end

    test "returns an error for stalemate" do
      game = game(%{a8: :k, c7: :K, b6: :Q}, :black)

      assert {:error, :stalemate} = Search.best_move(game)
    end

    test "returns an error for a drawn position with legal moves" do
      game = game(%{e1: :K, e8: :k})

      assert {:error, :draw_insufficient_material} = Search.best_move(game)
    end
  end
end
