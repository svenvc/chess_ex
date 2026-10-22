defmodule Chess.Repl do
  @moduledoc """
  REPL helpers for playing a game step by step.

  `new/0` starts a game and prints the initial position. `move/2` plays a
  manual move given as a SAN string for the side to move. `move/1` lets the
  engine play for the side to move. All functions return `{:ok, game}` or
  `{:error, reason}` and print a step like `Chess.Narrator`.
  """

  alias Chess.{Engine, Game, Narrator, Rules, SAN}

  # Set a process dictionary flag so Chess.Game.inspect/2 prints compactly
  # in the REPL. Use Chess.Repl.clear/0 to remove it.
  defp compact(game) do
    Process.put(:chess_repl_compact, true)
    game
  end

  @doc """
  Clear the compact inspection flag for Repl games.
  """
  def clear do
    Process.delete(:chess_repl_compact)
    :ok
  end

  @doc """
  Start a new game in the initial position.
  """
  def new do
    game = Game.new()
    Narrator.print_last_move(game)
    {:ok, compact(game)}
  end

  @doc """
  Let the engine make a move for the side to move.
  """
  def move(%Game{} = game) do
    if Game.over?(game) do
      Narrator.print_last_move(game)
      {:error, Game.status(game)}
    else
      case Engine.play(game) do
        {:ok, new_game, _move} ->
          Narrator.print_last_move(new_game)
          {:ok, compact(new_game)}

        {:error, status} ->
          Narrator.print_last_move(game)
          {:error, status}
      end
    end
  end

  @doc """
  Make a manual move for the side to move using a SAN string.
  """
  def move(%Game{} = game, san) when is_binary(san) do
    if Game.over?(game) do
      Narrator.print_last_move(game)
      {:error, Game.status(game)}
    else
      move =
        try do
          SAN.parse(String.trim(san), game, validate_marker: false)
        rescue
          _ ->
            nil
        end

      cond do
        is_nil(move) ->
          {:error, :illegal_move}

        Rules.legal_move?(game, move) ->
          new_game = Rules.apply(game, move)
          Narrator.print_last_move(new_game)
          {:ok, compact(new_game)}

        true ->
          {:error, :illegal_move}
      end
    end
  end
end
