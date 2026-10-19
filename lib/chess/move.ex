defmodule Chess.Move do
  @moduledoc """
  Functionality related to Chess moves.

  A move is a {from, to} tuple of 2 positions.
  A move can only be interpreted in the context of a game (for the full sequence of preceding moves)
  and must be applied to a board (to have an effect) - creating a new board.

  TODO: some special moves need a representation as well (en passant, castling, promotion)
  """

  alias Chess.Position

  @positions Position.all()

  @doc """
  Create and return a `{from, to}` move tuple.

  Raises `FunctionClauseError` if either position is not a valid square.
  """
  def new(from, to) when from in @positions and to in @positions do
    {from, to}
  end

  @doc """
  Return true if the argument is a `{from, to}` pair of valid squares.

  This is purely a syntactic check: chess legality (piece movement, occupancy,
  check, whether the move changes square, ...) is decided later against the
  board and game state.
  """
  def is_valid?({from, to}) when from in @positions and to in @positions, do: true
  def is_valid?(_move), do: false
end
