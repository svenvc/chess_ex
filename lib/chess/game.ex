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
  there. The moves of a game are played back from `start` when the draw
  rules ask for the positions the game went through, so a game that does not
  start from the initial position has to know where its moves begin.
  """

  alias Chess.{Board, Rules}

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

  @type status ::
          :ongoing
          | :checkmate
          | :stalemate
          | :draw_fivefold_repetition
          | :draw_repetition
          | :draw_seventy_five_moves
          | :draw_fifty_moves
          | :draw_insufficient_material

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

  @doc """
  Return how the game stands.

  The game is `:ongoing` as long as it can be played on. It is `:checkmate`
  when the side to move is mated and `:stalemate` when the side to move has
  no move and is not in check. The draws are the rules that end a game
  without a winner:

    * `:draw_fivefold_repetition` - the position has occurred five times
    * `:draw_repetition` - the position has occurred three times
    * `:draw_seventy_five_moves` - 75 moves without a capture or a pawn move
    * `:draw_fifty_moves` - 50 moves without a capture or a pawn move
    * `:draw_insufficient_material` - neither side has the material to mate

  The rules of the FIDE make the threefold repetition and the fifty move rule
  claimable: the player who wants the draw has to claim it. Here they end
  the game like the other two.
  """
  def status(game) do
    cond do
      Rules.checkmate?(game) -> :checkmate
      Rules.stalemate?(game) -> :stalemate
      Rules.fivefold_repetition?(game) -> :draw_fivefold_repetition
      Rules.threefold_repetition?(game) -> :draw_repetition
      Rules.seventy_five_move_rule?(game) -> :draw_seventy_five_moves
      Rules.fifty_move_rule?(game) -> :draw_fifty_moves
      Rules.insufficient_material?(game) -> :draw_insufficient_material
      true -> :ongoing
    end
  end

  @doc """
  Return true if the game is over.
  """
  def over?(game), do: status(game) != :ongoing

  @doc """
  Return the side that won the game, or nil if nobody won it.

  Only a checkmate has a winner: a game that is drawn has none.
  """
  def winner(game) do
    case status(game) do
      :checkmate -> opponent(game.side_to_move)
      _other -> nil
    end
  end

  # The other color.
  defp opponent(:white), do: :black
  defp opponent(:black), do: :white
end

# Inspect implementation for Chess.Game. When the process dictionary
# flag :chess_repl_compact is set (by Chess.Repl), games print compactly
# to avoid cluttering the REPL.
defimpl Inspect, for: Chess.Game do
  def inspect(game, opts) do
    if Process.get(:chess_repl_compact) do
      "#Chess.Game<>"
    else
      Inspect.Any.inspect(game, opts)
    end
  end
end
