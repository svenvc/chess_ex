defmodule Chess.GameTest do
  use ExUnit.Case

  alias Chess.{Board, Game, Rules}

  test "new/0 starts from the initial position" do
    game = Game.new()

    assert game.board == Board.initial()
    assert game.side_to_move == :white
    assert game.en_passant == nil
    assert game.moves == []
    assert game.halfmove_clock == 0
    assert game.fullmove_number == 1
    assert game.start == nil

    assert game.castling ==
             MapSet.new([
               {:white, :king_side},
               {:white, :queen_side},
               {:black, :king_side},
               {:black, :queen_side}
             ])
  end

  describe "status/1" do
    test "a game that has just begun is ongoing" do
      game = Game.new()

      assert Game.status(game) == :ongoing
      refute Game.over?(game)
      assert Game.winner(game) == nil
    end

    test "a checkmate ends the game and the other side wins" do
      # The fool's mate: black mates white.
      game = play([{:f2, :f3}, {:e7, :e5}, {:g2, :g4}, {:d8, :h4}])

      assert Rules.checkmate?(game)

      assert Game.status(game) == :checkmate
      assert Game.over?(game)
      assert Game.winner(game) == :black
    end

    test "a stalemate ends the game in a draw" do
      # The black king on a8 has no legal move and is not in check.
      game = %Game{board: %{a8: :k, c7: :K, b6: :Q}, side_to_move: :black}

      assert Game.status(game) == :stalemate
      assert Game.over?(game)
      assert Game.winner(game) == nil
    end

    test "a game without material is drawn" do
      game = %Game{board: %{e1: :K, e8: :k}, side_to_move: :white}

      assert Game.status(game) == :draw_insufficient_material
      assert Game.over?(game)
      assert Game.winner(game) == nil
    end

    test "a position that occurred three times draws the game" do
      game = play(shuffle())

      assert Game.status(game) == :draw_repetition
      assert Game.over?(game)
      assert Game.winner(game) == nil
    end

    test "a position that occurred five times draws the game" do
      game = play(shuffle() ++ shuffle())

      assert Game.status(game) == :draw_fivefold_repetition
      assert Game.over?(game)
      assert Game.winner(game) == nil
    end

    test "the fifty move rule draws the game" do
      game = %{Game.new() | halfmove_clock: 100}

      assert Game.status(game) == :draw_fifty_moves
      assert Game.over?(game)
      assert Game.winner(game) == nil
    end

    test "the seventy five move rule draws the game" do
      game = %{Game.new() | halfmove_clock: 150}

      assert Game.status(game) == :draw_seventy_five_moves
      assert Game.over?(game)
      assert Game.winner(game) == nil
    end
  end

  # Play the moves of a game, from the initial position.
  defp play(moves) do
    Enum.reduce(moves, Game.new(), fn move, game -> Rules.apply(game, move) end)
  end

  # The moves that let the knights go out and back again.
  defp shuffle do
    [
      {:g1, :f3},
      {:g8, :f6},
      {:f3, :g1},
      {:f6, :g8},
      {:g1, :f3},
      {:g8, :f6},
      {:f3, :g1},
      {:f6, :g8}
    ]
  end
end
