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

  test "start_position/1 returns the initial position until the game knows better" do
    game = Game.new()
    assert Game.start_position(game) == game

    game = Rules.apply(game, {:e2, :e4})
    assert Game.start_position(game) == Game.new()

    start = %{Game.new() | board: %{e1: :K, e8: :k}, castling: MapSet.new()}
    game = %{start | start: start, moves: [{:e1, :e2}]}

    assert Game.start_position(game) == start
  end

  test "moves_in_order/1 turns the history around" do
    moves = [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}]
    game = play(moves)

    assert Game.moves_in_order(game) == moves
  end

  test "replay/1 returns the positions a game went through" do
    moves = [{:e2, :e4}, {:e7, :e5}, {:g1, :f3}]
    game = play(moves)

    states = Game.replay(game)

    assert length(states) == 4
    assert hd(states) == Game.new()
    assert List.last(states) == game
    assert Enum.map(states, & &1.side_to_move) == [:white, :black, :white, :black]
    assert Enum.map(states, &length(&1.moves)) == [0, 1, 2, 3]
  end

  test "replay/2 plays a list of moves from a position" do
    moves = [{:e2, :e4}, {:e7, :e5}]

    states = Game.replay(Game.new(), moves)

    assert length(states) == 3
    assert hd(states) == Game.new()
    assert List.last(states) == play(moves)
  end

  test "replay/1 ends a history that cannot be played" do
    game = %{Game.new() | moves: [{:e4, :e5}]}

    assert Game.replay(game) == [Game.new()]
  end

  test "replay/1 of a position without moves is the position itself" do
    game = %{Game.new() | board: %{e1: :K, e8: :k}, side_to_move: :black}

    assert Game.replay(game) == [game]
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
