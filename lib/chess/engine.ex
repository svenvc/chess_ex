defmodule Chess.Engine do
  @moduledoc """
  Automatic move generation for a `Chess.Game`.

  Three strategies are available:

    * `:random` — a uniformly random legal move
    * `:best` — the move with the best static evaluation after one ply
    * `:search` — a depth-limited search with alpha-beta pruning, delegated to `Chess.Search`

  The `:search` strategy accepts a `:depth` option in plies (half-moves),
  defaulting to `4`. See `Chess.Search` for the search itself.
  """

  alias Chess.{Evaluation, Game, Rules, Search}

  @doc """
  Play a move in the game using the given strategy.

  By default uses the `:best` strategy (1-ply evaluation). Returns a
  tuple with the new game state and the move that was played.

  Returns `{:error, reason}` if the game is over or has no legal moves,
  where `reason` is the game status (e.g. `:checkmate`, `:stalemate`,
  `:draw_repetition`, etc.).
  """
  def play(game, opts \\ [])

  def play(%Game{} = game, opts) do
    if Game.over?(game) do
      {:error, Game.status(game)}
    else
      case Rules.legal_moves(game) do
        [] ->
          {:error, Game.status(game)}

        moves ->
          strategy = Keyword.get(opts, :strategy, :best)
          move = select_move(game, moves, strategy, opts)
          {:ok, Rules.apply(game, move), move}
      end
    end
  end

  @doc """
  Return a random legal move for the side to move.

  Returns `{:error, reason}` if the game is over or has no legal moves.
  """
  def random_move(game) do
    play(game, strategy: :random)
    |> case do
      {:ok, _game, move} -> {:ok, move}
      other -> other
    end
  end

  @doc """
  Return the best legal move for the side to move using 1-ply evaluation.

  By default, moves with equal best scores are chosen randomly.
  Pass `randomize: false` to pick the first best move found.

  Returns `{:error, reason}` if the game is over or has no legal moves.
  """
  def best_move(game, opts \\ []) do
    play(game, Keyword.put_new(opts, :strategy, :best))
    |> case do
      {:ok, _game, move} -> {:ok, move}
      other -> other
    end
  end

  @doc """
  Return the best legal move for the side to move found by a depth-limited
  alpha-beta search.

  The search accepts the options of `Chess.Search.best_move/2`:
  `:depth` (in plies, default `4`), `:randomize` (default `true`) and
  `:book` (default `true`).

  Returns `{:error, reason}` if the game is over or has no legal moves.
  """
  def search_move(game, opts \\ []) do
    play(game, Keyword.merge(opts, strategy: :search))
    |> case do
      {:ok, _game, move} -> {:ok, move}
      other -> other
    end
  end

  defp select_move(_game, moves, :random, _opts) do
    Enum.random(moves)
  end

  defp select_move(game, _moves, :search, opts) do
    {:ok, move, _score} = Search.best_move(game, opts)
    move
  end

  defp select_move(game, moves, :best, opts) do
    color = game.side_to_move
    randomize = Keyword.get(opts, :randomize, true)

    moves
    |> Enum.map(fn move ->
      score = game |> Rules.apply(move) |> Evaluation.evaluate(color)
      {move, score}
    end)
    |> Enum.group_by(fn {_move, score} -> score end)
    |> Enum.max_by(fn {score, _moves} -> score end)
    |> case do
      {_score, moves_with_score} ->
        if randomize do
          Enum.random(moves_with_score) |> elem(0)
        else
          moves_with_score |> hd() |> elem(0)
        end
    end
  end
end
