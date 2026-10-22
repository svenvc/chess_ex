defmodule Chess.Game do
  @moduledoc """
  Functionality related to a game of Chess.

  A Chess game is a sequence of alternating, legal moves from the initial board
  to its current state.
  Various properties can hold for a game state, such as which side has the next move,
  whether it is finished and who won and so on.

  The game state stores everything that cannot be derived from the board alone:
  the side to move, the remaining castling rights and the current en passant
  target square (the square behind a pawn that just advanced two squares).
  It also holds the two counters of a FEN record: the halfmove clock and the
  number of the full move that is being played.

  `moves` is the move history, newest first. It is not needed for move
  generation or legality; it exists for game records and future draw rules.

  `start` is the position the game started from. It is `nil` for a game that
  starts from the initial position; `Chess.FEN.parse/1` sets it to the
  position it read, so that the moves of the game can be played back from
  there.
  """

  alias Chess.Board

  defstruct board: nil,
            side_to_move: :white,
            castling: MapSet.new(),
            en_passant: nil,
            halfmove_clock: 0,
            fullmove_number: 1,
            moves: [],
            start: nil

  @castling_rights MapSet.new([
                     {:white, :king_side},
                     {:white, :queen_side},
                     {:black, :king_side},
                     {:black, :queen_side}
                   ])

  @doc """
  Create and return a new game in the initial position (White to move,
  all castling rights, no en passant target).
  """
  def new do
    %__MODULE__{
      board: Board.initial(),
      side_to_move: :white,
      castling: @castling_rights,
      en_passant: nil,
      moves: []
    }
  end
end
