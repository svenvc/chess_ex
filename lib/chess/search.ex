defmodule Chess.Search do
  @moduledoc """
  Depth-limited search for the best move in a position.

  The search is a *negamax* search with *alpha-beta* pruning. Move generation
  and move application come from `Chess.Rules`; the score of a position comes
  from `Chess.Evaluation`.

  ## Negamax

  Negamax is a compact form of minimax that avoids writing two separate
  functions for the two sides. It relies on chess being a zero-sum game: what
  is good for White is equally bad for Black. At every node the score is
  therefore expressed from the point of view of the side to move, and playing
  a move simply flips the sign:

      score(position) = max over all moves of -score(position after the move)

  `Chess.Evaluation.evaluate/2` already returns a score from a given color's
  point of view, so the value of a quiet position is just
  `Evaluation.evaluate(game, game.side_to_move)`.

  A checkmate is worth more than any material score: the mated side gets
  `-100_000` plus the distance from the root, so that a faster mate scores
  higher than a slower one. A stalemate is worth `0`, like a draw.

  ## Alpha-beta pruning

  Alpha-beta is an optimisation of minimax, not a different evaluation. While
  searching a node it keeps a window of two scores:

    * *alpha* — the best score the side to move has already been guaranteed
      by an earlier move;
    * *beta* — the best score the opponent has already been guaranteed at a
      parent node.

  If a move gives the side to move a score of at least *beta*, the opponent
  would never allow this line, so the remaining moves at the node cannot
  change the result and are pruned. If a move is no better than *alpha*, it
  cannot become the best move either. Without pruning the tree grows like
  `b^d` for a branching factor `b` and a depth `d`; with good move ordering
  alpha-beta gets much closer to `b^(d/2)`.

  ## Move ordering: MVV-LVA

  Alpha-beta works best when the best move is searched first. Captures are
  tried first, using *MVV-LVA* — **M**ost **V**aluable **V**ictim,
  **L**east **V**aluable **A**ttacker: a queen taken by a pawn is more
  promising than a pawn taken by a queen. Promotions follow the same idea.
  Quiet moves need no special ordering here.

  ## Draws

  The fifty-move rule and insufficient material are recognised inside the
  tree. Repetition draws are not: the repetition rules replay the whole game
  at every node, which would make the search far too slow. A repetition that
  the search does not see is left to the normal game rules once a move is
  actually played.

  ## Depth

  `depth` counts plies (half-moves), not full moves. `depth: 1` looks at the
  side's own moves and then evaluates the resulting positions; `depth: 3`
  looks at a move, the reply and one more move. Deeper searches are stronger
  but grow quickly: depth 3 is the default.

  ## Opening book

  A small opening book, `Chess.Book`, is consulted before the tree is
  searched. A book move is returned with a score of `0`. Pass `book: false` to
  search the position itself; there is no endgame tablebase.
  """

  alias Chess.{Board, Book, Evaluation, Game, Move, Rules}

  @default_depth 3
  @mate 100_000
  @infinity 1_000_000

  @doc """
  Search for the best legal move and return it with its score.

  The score is in centipawns from the point of view of the side to move, the
  same convention as `Chess.Evaluation.evaluate/2`.

  Options:

    * `:depth` — the number of plies to search, default `#{@default_depth}`,
      minimum `1`
    * `:randomize` — pick randomly among moves with the same best score,
      default `true`; with `false` the first best move is used
    * `:book` — consult `Chess.Book` first, default `true`; a book move scores
      `0` and is chosen randomly unless `randomize: false`

  Returns `{:error, status}` if the game is already over or the side to move
  has no legal move.
  """
  def best_move(%Game{} = game, opts \\ []) do
    depth = max(Keyword.get(opts, :depth, @default_depth), 1)
    randomize? = Keyword.get(opts, :randomize, true)
    book? = Keyword.get(opts, :book, true)

    case Game.status(game) do
      :ongoing ->
        case book_move(game, book?, randomize?) do
          {:ok, move} -> {:ok, move, 0}
          :error -> search(game, depth, randomize?)
        end

      status ->
        {:error, status}
    end
  end

  defp book_move(game, true, randomize?), do: Book.move(game, randomize: randomize?)
  defp book_move(_game, false, _randomize?), do: :error

  defp search(game, depth, randomize?) do
    moves = Rules.legal_moves(game)

    {move, score} =
      moves
      |> order_moves(game)
      |> Enum.map(fn move ->
        score = -negamax(Rules.apply(game, move), depth - 1, -@infinity, @infinity, 1)
        {move, score}
      end)
      |> pick_best(randomize?)

    {:ok, move, score}
  end

  ## Search

  # A leaf: there are no moves left to search. A checkmate at the horizon still
  # has to be seen, which is why the legal moves are generated only when the
  # side to move is in check.
  defp negamax(game, 0, _alpha, _beta, ply) do
    cond do
      Rules.in_check?(game) and Rules.legal_moves(game) == [] -> -@mate + ply
      draw?(game) -> 0
      true -> Evaluation.evaluate(game, game.side_to_move)
    end
  end

  # An internal node. Having no legal moves means mate or stalemate; both have
  # to be decided before looking at draws, because a checkmate wins even on the
  # move that reaches the fifty-move limit.
  defp negamax(game, depth, alpha, beta, ply) do
    case ordered_moves(game) do
      [] ->
        if Rules.in_check?(game), do: -@mate + ply, else: 0

      moves ->
        if draw?(game) do
          0
        else
          alpha_beta(moves, game, depth, alpha, beta, ply, -@infinity)
        end
    end
  end

  # Search the moves of one node, keeping the best score seen so far and
  # narrowing alpha as the search goes on. A score at or above beta cuts the
  # remaining moves off: the opponent would avoid this line.
  defp alpha_beta([], _game, _depth, _alpha, _beta, _ply, best), do: best

  defp alpha_beta([move | rest], game, depth, alpha, beta, ply, best) do
    score = -negamax(Rules.apply(game, move), depth - 1, -beta, -alpha, ply + 1)
    best = max(best, score)
    alpha = max(alpha, score)

    if alpha >= beta do
      best
    else
      alpha_beta(rest, game, depth, alpha, beta, ply, best)
    end
  end

  ## Move ordering

  defp ordered_moves(game) do
    game
    |> Rules.legal_moves()
    |> order_moves(game)
  end

  # Most valuable victim, least valuable attacker: the material the capture
  # wins times ten, minus the value of the piece doing the capturing. A
  # promotion adds the value of the new piece, so a queen promotion comes
  # before a knight promotion.
  defp order_moves(moves, game) do
    Enum.sort_by(moves, fn move -> -move_score(game, move) end)
  end

  defp move_score(game, move) do
    victim =
      case Move.capture_square(move) do
        nil -> 0
        square -> game.board |> Board.at(square) |> piece_value()
      end

    attacker = game.board |> Board.at(Move.from(move)) |> piece_value()
    promotion = Move.promotion_piece(move) |> piece_value()

    victim * 10 - attacker + promotion
  end

  defp piece_value(nil), do: 0
  defp piece_value(piece), do: Evaluation.piece_value(piece)

  ## Helpers

  defp draw?(game) do
    Rules.fifty_move_rule?(game) or Rules.insufficient_material?(game)
  end

  defp pick_best(scored, randomize?) do
    best = scored |> Enum.map(fn {_move, score} -> score end) |> Enum.max()
    ties = for {move, ^best} <- scored, do: move
    move = if randomize?, do: Enum.random(ties), else: hd(ties)

    {move, best}
  end
end
