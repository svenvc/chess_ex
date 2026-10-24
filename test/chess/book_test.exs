defmodule Chess.BookTest do
  use ExUnit.Case

  alias Chess.{Book, Game, Rules, UCI}

  defp play(tokens) do
    Enum.reduce(tokens, Game.new(), fn token, game ->
      {:ok, move} = UCI.parse_move(game, token)
      Rules.apply(game, move)
    end)
  end

  describe "move/2" do
    test "returns a legal first move" do
      game = Game.new()

      assert {:ok, move} = Book.move(game)
      assert move in Rules.legal_moves(game)
      assert move in [{:e2, :e4}, {:d2, :d4}, {:c2, :c4}, {:g1, :f3}]
    end

    test "answers for both sides" do
      assert {:ok, move} = Book.move(play(["e2e4"]))
      assert move in [{:e7, :e5}, {:c7, :c5}, {:e7, :e6}, {:c7, :c6}]

      assert {:ok, move} = Book.move(play(["e2e4", "e7e5"]))
      assert move in [{:g1, :f3}, {:d2, :d4}]
    end

    test "knows a position a few plies deep" do
      game = play(["e2e4", "e7e5", "g1f3", "b8c6"])

      assert {:ok, move} = Book.move(game)
      assert move in [{:f1, :b5}, {:f1, :c4}, {:d2, :d4}]
    end

    test "finds a position through a transposition" do
      # The Italian Game can reach the same position with the bishop developed
      # before the knight; the en passant target is empty on both paths.
      transposed = play(["e2e4", "e7e5", "f1c4", "f8c5", "g1f3", "b8c6"])
      line = play(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"])

      assert Book.move(transposed, randomize: false) == Book.move(line, randomize: false)
      assert {:ok, {:c2, :c3}} = Book.move(transposed, randomize: false)
    end

    test "returns :error once the game leaves the book" do
      assert :error = Book.move(play(["e2e4", "e7e5", "f2f4"]))
      assert :error = Book.move(play(["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "g8f6"]))
    end

    test "randomize: false is stable" do
      game = play(["e2e4"])

      assert {:ok, move} = Book.move(game, randomize: false)
      assert {:ok, ^move} = Book.move(game, randomize: false)
    end

    test "every recorded move is legal in the position it belongs to" do
      # Walk each line and ask the book at every position; whatever it answers
      # must be one of the legal moves.
      lines = [
        ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6"],
        ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4"],
        ["d2d4", "g8f6", "c2c4", "g7g6", "b1c3", "f8g7"],
        ["c2c4", "e7e5", "b1c3", "g8f6", "g2g3"]
      ]

      for moves <- lines,
          prefix <- Enum.map(0..length(moves), &Enum.take(moves, &1)),
          game = play(prefix),
          {:ok, move} <- [Book.move(game)] do
        assert move in Rules.legal_moves(game)
      end
    end
  end
end
