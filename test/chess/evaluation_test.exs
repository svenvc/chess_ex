defmodule Chess.EvaluationTest do
  use ExUnit.Case

  alias Chess.{Evaluation, Game, Piece, Position}

  defp game(board, side_to_move \\ :white) do
    %Game{board: board, side_to_move: side_to_move}
  end

  describe "evaluate/1" do
    test "the initial position is balanced" do
      game = Game.new()

      assert Evaluation.evaluate(game) == 0
      assert Evaluation.breakdown(game) == %{material: 0, positional: 0}
    end

    test "material counts for the side that is ahead" do
      game = game(%{e1: :K, d1: :Q, e8: :k})

      assert Evaluation.breakdown(game).material == 900
      assert Evaluation.evaluate(game) > 0
    end

    test "a black advantage is negative" do
      game = game(%{e1: :K, d8: :q, e8: :k})

      assert Evaluation.breakdown(game).material == -900
      assert Evaluation.evaluate(game) < 0
    end

    test "a queen is worth more than a rook" do
      assert Evaluation.breakdown(game(%{d1: :Q})).material >
               Evaluation.breakdown(game(%{d1: :R})).material
    end

    test "a board can be evaluated without a game" do
      board = %{e1: :K, d1: :Q, e8: :k}

      assert Evaluation.evaluate(board) == Evaluation.evaluate(game(board))
    end
  end

  describe "evaluate/2" do
    test "the score can be taken from black's point of view" do
      game = game(%{e1: :K, d1: :Q, e8: :k})

      assert Evaluation.evaluate(game, :white) == Evaluation.evaluate(game)
      assert Evaluation.evaluate(game, :black) == -Evaluation.evaluate(game, :white)
      assert Evaluation.evaluate(game, :black) < 0
    end
  end

  describe "positional" do
    test "a central knight is worth more than a knight in the corner" do
      center = Evaluation.breakdown(game(%{d4: :N})).positional
      corner = Evaluation.breakdown(game(%{a1: :N})).positional

      assert center == 20
      assert corner == -50
      assert center - corner == 70
    end

    test "black reads the same table, rotated" do
      # A black pawn on e7 is looked up on d2, the square a white pawn on e2
      # would occupy.
      assert Evaluation.breakdown(game(%{e2: :P})).positional == 20
      assert Evaluation.breakdown(game(%{e7: :p})).positional == -20
    end

    test "a position and its mirror image have opposite scores" do
      board = %{e2: :P, d4: :N, d5: :n, e8: :k}

      assert Evaluation.evaluate(game(board)) == 120
      assert Evaluation.evaluate(game(mirror(board))) == -120
    end
  end

  describe "breakdown/1" do
    test "the terms add up to the total" do
      game = game(%{e1: :K, d1: :Q, e8: :k, d8: :q, c3: :N})

      breakdown = Evaluation.breakdown(game)

      assert Enum.sum(Map.values(breakdown)) == Evaluation.evaluate(game)
    end
  end

  # Rotate the board by 180 degrees and swap the colors of all pieces.
  defp mirror(board) do
    Map.new(board, fn {position, piece} ->
      {rotated(position), swap_color(piece)}
    end)
  end

  defp rotated(position) do
    Position.new(9 - Position.file_index(position), 9 - Position.rank(position))
  end

  defp swap_color(piece) do
    if Piece.white?(piece) do
      piece |> Atom.to_string() |> String.downcase() |> String.to_atom()
    else
      piece |> Atom.to_string() |> String.upcase() |> String.to_atom()
    end
  end
end
