defmodule Chess.Move do
  @moduledoc """
  Functionality related to Chess moves.

  A move is a {from, to} tuple of 2 positions.
  A move can only be interpreted in the context of a game (for the full sequence of preceding moves)
  and must be applied to a board (to have an effect) - creating a new board.

  TODO: some special moves need a representation as well (en passent, castling, promotion)
  """

  alias Chess.Position

  @positions Position.all()

  def new(from, to) when from in @positions and to in @positions do
    {from, to}
  end

  def is_valid?({from, to} = _position) when from in @positions and to in @positions, do: true
  def is_valid?(_position), do: false
end
