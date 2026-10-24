defmodule Chess.Book do
  @moduledoc """
  A small opening book keyed by position.

  The book is a compile-time constant. Its key is the first four fields of the
  FEN record of a position - the placement of the pieces, the side to move, the
  castling rights and the en passant target - so the two counters do not take
  part in a lookup. Each entry comes from one line of UCI moves in `@lines`;
  the lines are replayed while the module is compiled, which means a line with
  an illegal move fails compilation instead of lying dormant.

  The book is deliberately small: a handful of main lines, enough to start a
  game in a known opening. Once a game leaves the book, `move/2` returns
  `:error` and `Chess.Search` searches the position itself.

  Positions are keyed by their FEN record, so transpositions are found as long
  as they are reached without a different en passant target. The book has no
  notion of weights: every move known for a position is equally likely.
  """

  alias Chess.{FEN, Game, Rules, UCI}

  # One variation per line, in UCI notation. The lines are independent; shared
  # prefixes become a position with several book moves.
  @lines [
    # Ruy Lopez
    "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7",
    # Italian Game
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d4 e5d4",
    # Scotch Game
    "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4",
    # Sicilian Defence, Najdorf
    "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6",
    # Sicilian Defence, ...Nc6
    "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4",
    # French Defence
    "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6",
    # Caro-Kann Defence
    "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4",
    # Queen's Gambit Declined
    "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c4d5 e6d5",
    # Queen's Gambit Accepted
    "d2d4 d7d5 c2c4 d5c4 g1f3 g8f6",
    # King's Indian Defence
    "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6",
    # Nimzo-Indian Defence
    "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4",
    # English Opening
    "c2c4 e7e5 b1c3 g8f6 g2g3",
    # Réti Opening
    "g1f3 d7d5 g2g3 g8f6 f1g2"
  ]

  # Replay every line once at compile time and group the next move of each ply
  # under the key of the position it was played from.
  @book @lines
        |> Enum.flat_map(fn line ->
          line
          |> String.split()
          |> Enum.reduce({Game.new(), []}, fn token, {game, entries} ->
            {:ok, move} = UCI.parse_move(game, token)
            position = game |> FEN.to_fen() |> String.split(" ") |> Enum.take(4) |> Enum.join(" ")
            {Rules.apply(game, move), [{position, move} | entries]}
          end)
          |> elem(1)
        end)
        |> Enum.reduce(%{}, fn {position, move}, book ->
          Map.update(book, position, [move], &[move | &1])
        end)
        |> Map.new(fn {position, moves} -> {position, Enum.uniq(moves)} end)

  @doc """
  Return a book move for the position.

  By default a move is picked randomly among the moves the book knows for the
  position. Pass `randomize: false` to always get the first one.

  Returns `:error` when the position is not in the book, or when none of the
  moves recorded for it is legal in this game.
  """
  def move(%Game{} = game, opts \\ []) do
    randomize? = Keyword.get(opts, :randomize, true)

    with {:ok, moves} <- Map.fetch(@book, key(game)),
         legal = Rules.legal_moves(game),
         [_ | _] = candidates <- Enum.filter(moves, &(&1 in legal)) do
      {:ok, if(randomize?, do: Enum.random(candidates), else: hd(candidates))}
    else
      _other -> :error
    end
  end

  defp key(game) do
    game |> FEN.to_fen() |> String.split(" ") |> Enum.take(4) |> Enum.join(" ")
  end
end
