defmodule Chess.Move do
  @moduledoc """
  Functionality related to Chess moves.

  A move is one of the following tagged tuples:

    * `{from, to}` — a normal move, including captures
    * `{:castle, from, to}` — castling; `from`/`to` are the king squares
    * `{:en_passant, from, to}` — en passant capture
    * `{:promotion, from, to, piece}` — promotion to `piece`

  A move can only be interpreted in the context of a game (for the full
  sequence of preceding moves) and must be applied to a board (to have an
  effect) - creating a new board.
  """

  alias Chess.Position

  @positions Position.all()

  @promotion_pieces ~w(Q R B N q r b n)a

  @doc """
  Create and return a normal `{from, to}` move tuple.

  Raises `FunctionClauseError` if either position is not a valid square.
  """
  def new(from, to) when from in @positions and to in @positions do
    {from, to}
  end

  @doc """
  Create and return a `{:castle, from, to}` move tuple.

  Raises `FunctionClauseError` if either position is not a valid square.
  """
  def castle(from, to) when from in @positions and to in @positions do
    {:castle, from, to}
  end

  @doc """
  Create and return an `{:en_passant, from, to}` move tuple.

  Raises `FunctionClauseError` if either position is not a valid square.
  """
  def en_passant(from, to) when from in @positions and to in @positions do
    {:en_passant, from, to}
  end

  @doc """
  Create and return a `{:promotion, from, to, piece}` move tuple.

  Raises `FunctionClauseError` if either position is not a valid square or
  `piece` is not a queen, rook, bishop or knight (of either color).
  """
  def promotion(from, to, piece)
      when from in @positions and to in @positions and piece in @promotion_pieces do
    {:promotion, from, to, piece}
  end

  @doc """
  Return true if the argument is a well-formed move tuple.

  This is purely a syntactic check: chess legality (piece movement, occupancy,
  check, whether the move changes square, ...) is decided later against the
  board and game state.
  """
  def is_valid?({from, to})
      when from in @positions and to in @positions,
      do: true

  def is_valid?({:castle, from, to})
      when from in @positions and to in @positions,
      do: true

  def is_valid?({:en_passant, from, to})
      when from in @positions and to in @positions,
      do: true

  def is_valid?({:promotion, from, to, piece})
      when from in @positions and to in @positions and piece in @promotion_pieces,
      do: true

  def is_valid?(_move), do: false
end
