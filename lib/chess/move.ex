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

  @promotions [white: [:Q, :R, :B, :N], black: [:q, :r, :b, :n]]

  @promotion_pieces @promotions |> Keyword.values() |> List.flatten()

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
  def valid?({from, to})
      when from in @positions and to in @positions,
      do: true

  def valid?({:castle, from, to})
      when from in @positions and to in @positions,
      do: true

  def valid?({:en_passant, from, to})
      when from in @positions and to in @positions,
      do: true

  def valid?({:promotion, from, to, piece})
      when from in @positions and to in @positions and piece in @promotion_pieces,
      do: true

  def valid?(_move), do: false

  @doc """
  Return the square a move comes from.
  """
  def from({from, _to}), do: from
  def from({_kind, from, _to}), do: from
  def from({:promotion, from, _to, _piece}), do: from

  @doc """
  Return the square a move goes to.
  """
  def to({_from, to}), do: to
  def to({_kind, _from, to}), do: to
  def to({:promotion, _from, to, _piece}), do: to

  @doc """
  Return the piece a promotion move promotes to, or nil for other moves.
  """
  def promotion_piece({:promotion, _from, _to, piece}), do: piece
  def promotion_piece(_move), do: nil

  @doc """
  Return the square a move captures on, or nil if the move captures nothing.

  The square of a normal move or a promotion is its destination, which may be
  empty; an en passant capture takes the pawn beside the destination; a castle
  captures nothing. Whether a piece really stands on the square is a question
  for the board.
  """
  def capture_square({_from, to}), do: to
  def capture_square({:castle, _from, _to}), do: nil

  def capture_square({:en_passant, from, to}),
    do: Position.new(Position.file(to), Position.rank(from))

  def capture_square({:promotion, _from, to, _piece}), do: to

  @doc """
  Return the side of the board a castling move goes to.
  """
  def castle_side({:castle, _from, to}) do
    case Position.file(to) do
      :g -> :king_side
      :c -> :queen_side
    end
  end

  @doc """
  Return the square a two-rank move skipped over, or nil for other moves.

  Only a pawn advances two ranks in one move; the caller has to check the
  piece.
  """
  def skipped_square({from, to}) do
    if abs(Position.rank(to) - Position.rank(from)) == 2 do
      Position.new(Position.file(from), div(Position.rank(from) + Position.rank(to), 2))
    end
  end

  def skipped_square(_move), do: nil

  @doc """
  Return the pieces a pawn of the given color may promote to.
  """
  def promotions(color), do: Keyword.fetch!(@promotions, color)
end
