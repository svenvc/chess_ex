defmodule Chess.Evaluation do
  @moduledoc """
  Static evaluation of a position.

  Scores are integers in centipawns and always from White's point of view: a
  positive score means White stands better, a negative one that Black does.

  The score is the sum of the terms returned by `breakdown/1`:

    * `:material` — the value of the pieces on the board
    * `:positional` — a piece-square table lookup for every piece

  Adding a term (mobility, pawn structure, king safety, ...) means adding a
  function and a key to the breakdown map; `evaluate/1` sums the map's values.
  The material value of a single piece is exposed through `piece_value/1`,
  which the search also uses to order captures.
  """

  alias Chess.{Board, Game, Piece, Position}

  # Material values in centipawns. The king is worth nothing here: a won game
  # is a matter for search, not for a static score.
  @material_values %{
    P: 100,
    N: 320,
    B: 330,
    R: 500,
    Q: 900,
    K: 0,
    p: 100,
    n: 320,
    b: 330,
    r: 500,
    q: 900,
    k: 0
  }

  # Piece-square tables from White's point of view, written top down: the
  # first row is rank 8, the last one rank 1. Black's pieces are looked up on
  # the square rotated by 180 degrees, so both colors read the same tables.
  #
  # The classic tables from "Simplified Evaluation Function", chessprogramming.org.
  # https://en.wikipedia.org/wiki/Evaluation_function#Piece-square_tables
  @pawn_table {
    {0, 0, 0, 0, 0, 0, 0, 0},
    {50, 50, 50, 50, 50, 50, 50, 50},
    {10, 10, 20, 30, 30, 20, 10, 10},
    {5, 5, 10, 25, 25, 10, 5, 5},
    {0, 0, 0, 20, 20, 0, 0, 0},
    {5, -5, -10, 0, 0, -10, -5, 5},
    {10, 10, 10, 20, 20, 10, 10, 10},
    {0, 0, 0, 0, 0, 0, 0, 0}
  }

  @knight_table {
    {-50, -40, -30, -30, -30, -30, -40, -50},
    {-40, -20, 0, 0, 0, 0, -20, -40},
    {-30, 0, 10, 15, 15, 10, 0, -30},
    {-30, 5, 15, 20, 20, 15, 5, -30},
    {-30, 0, 15, 20, 20, 15, 0, -30},
    {-30, 5, 10, 15, 15, 10, 5, -30},
    {-40, -20, 0, 5, 5, 0, -20, -40},
    {-50, -40, -30, -30, -30, -30, -40, -50}
  }

  @bishop_table {
    {-20, -10, -10, -10, -10, -10, -10, -20},
    {-10, 5, 0, 0, 0, 0, 5, -10},
    {-10, 10, 10, 10, 10, 10, 10, -10},
    {-10, 0, 10, 10, 10, 10, 0, -10},
    {-10, 5, 5, 10, 10, 5, 5, -10},
    {-10, 0, 10, 10, 10, 10, 0, -10},
    {-10, 10, 10, 10, 10, 10, 10, -10},
    {-20, -10, -10, -10, -10, -10, -10, -20}
  }

  @rook_table {
    {0, 0, 5, 10, 10, 5, 0, 0},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {20, 20, 20, 20, 20, 20, 20, 20},
    {0, 0, 5, 10, 10, 5, 0, 0}
  }

  @queen_table {
    {-20, -10, -10, -5, -5, -10, -10, -20},
    {-10, 0, 5, 0, 0, 0, 0, -10},
    {-10, 5, 5, 5, 5, 5, 0, -10},
    {0, 0, 5, 5, 5, 5, 0, -5},
    {-5, 0, 5, 5, 5, 5, 0, -5},
    {-10, 0, 5, 5, 5, 5, 0, -10},
    {-10, 0, 0, 0, 0, 0, 0, -10},
    {-20, -10, -10, -5, -5, -10, -10, -20}
  }

  @king_table {
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-20, -30, -30, -40, -40, -30, -30, -20},
    {-10, -20, -20, -20, -20, -20, -20, -10},
    {20, 20, 0, 0, 0, 0, 20, 20},
    {20, 30, 10, 0, 0, 10, 30, 20}
  }

  @tables %{
    pawn: @pawn_table,
    knight: @knight_table,
    bishop: @bishop_table,
    rook: @rook_table,
    queen: @queen_table,
    king: @king_table
  }

  @doc """
  Evaluate the position and return the score in centipawns, from White's
  point of view.

  Accepts a `Chess.Game` or a board (a map of `position => piece`).
  """
  def evaluate(game) do
    game
    |> breakdown()
    |> Enum.sum_by(fn {_term, value} -> value end)
  end

  @doc """
  Evaluate the position from the given color's point of view.

  A positive score means the given color stands better.
  """
  def evaluate(game, :white), do: evaluate(game)
  def evaluate(game, :black), do: -evaluate(game)

  @doc """
  Return the material value of a piece in centipawns.

  The king is worth `0`: a won game is a matter for search, not for a static
  score. The values are the ones `breakdown/1` uses for its `:material` term.
  """
  def piece_value(piece), do: Map.fetch!(@material_values, piece)

  @doc """
  Return the terms of the evaluation, from White's point of view.

  The values add up to the result of `evaluate/1`.
  """
  def breakdown(game) do
    board = board(game)

    %{
      material: material(board),
      positional: positional(board)
    }
  end

  ## Terms

  # The material balance, in centipawns.
  defp material(board) do
    white = material_of(board, :white)
    black = material_of(board, :black)

    white - black
  end

  defp material_of(board, color) do
    board
    |> Board.pieces(color)
    |> Enum.reduce(0, fn {_position, piece}, sum -> sum + value(piece) end)
  end

  # The piece-square table score, in centipawns.
  defp positional(board) do
    white = positional_of(board, :white)
    black = positional_of(board, :black)

    white - black
  end

  defp positional_of(board, color) do
    board
    |> Board.pieces(color)
    |> Enum.reduce(0, fn {position, piece}, sum -> sum + square_value(piece, position) end)
  end

  ## Lookups

  # The material value of a piece, in centipawns.
  defp value(piece), do: piece_value(piece)

  # The piece-square table value of a piece on a square. Black's square is
  # rotated by 180 degrees before the lookup, so that both colors read the
  # tables from White's point of view.
  defp square_value(piece, position) do
    position = if Piece.white?(piece), do: position, else: Position.rotate(position)
    table = table_for(piece)

    elem(elem(table, 8 - Position.rank(position)), Position.file_index(position) - 1)
  end

  # The piece-square table of a piece type.
  defp table_for(piece), do: Map.fetch!(@tables, Piece.type(piece))

  ## Helpers

  # The board of a game, or the board itself.
  defp board(%Game{} = game), do: game.board
  defp board(board) when is_map(board), do: board
end
