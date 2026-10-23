defmodule Chess.Rules do
  @moduledoc """
  Move legality and move generation for a `Chess.Game`.

  Castling rights, the en passant target and the side to move live in the game
  state, because they cannot be derived from the board alone.

  The rules that end a game in a draw live here as well: the repetition rules,
  the fifty-move and the seventy-five-move rule and the rule about material
  that is not enough to mate.
  """

  alias Chess.{Board, Castling, Color, Game, Move, Piece, Position}

  import Kernel, except: [apply: 2]

  @positions Position.all()

  @colors [:white, :black]

  @knight_deltas [{1, 2}, {2, 1}, {2, -1}, {1, -2}, {-1, -2}, {-2, -1}, {-2, 1}, {-1, 2}]

  @king_deltas [{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}]

  @rook_deltas [{1, 0}, {-1, 0}, {0, 1}, {0, -1}]

  @bishop_deltas [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}]

  # The number of plies the halfmove clock has to reach for the fifty move
  # rule and for the seventy five move rule.
  @fifty_moves 100

  @seventy_five_moves 150

  ## Queries

  @doc """
  Return true if `square` is attacked by any piece of `by_color`.
  """
  def attacked?(board, square, by_color)
      when is_map(board) and square in @positions and by_color in @colors do
    pawn_attack?(board, square, by_color) or
      knight_attack?(board, square, by_color) or
      king_attack?(board, square, by_color) or
      sliding_attack?(board, square, by_color)
  end

  @doc """
  Return true if the side to move is in check.
  """
  def in_check?(game), do: in_check?(game, game.side_to_move)

  @doc """
  Return true if the king of `color` is in check.
  """
  def in_check?(game, color) when color in @colors do
    case Board.king(game.board, color) do
      nil -> false
      king -> attacked?(game.board, king, Color.opponent(color))
    end
  end

  ## Move generation

  @doc """
  Return all legal moves for the side to move.
  """
  def legal_moves(game) do
    color = game.side_to_move

    game
    |> pseudo_legal_moves()
    |> Enum.filter(fn move -> not in_check?(apply(game, move), color) end)
  end

  @doc """
  Return all pseudo-legal moves for the side to move.

  These respect piece movement, occupancy, castling rights and the en passant
  target, but may leave the mover's own king in check.
  """
  def pseudo_legal_moves(game) do
    game.board
    |> Board.pieces(game.side_to_move)
    |> Enum.flat_map(fn {from, _piece} -> moves_from(game, from) end)
  end

  @doc """
  Return true if `move` is a well-formed and legal move for the side to move.
  """
  def legal_move?(game, move) do
    Move.valid?(move) and move in legal_moves(game)
  end

  @doc """
  Return true if the side to move is checkmated.
  """
  def checkmate?(game), do: in_check?(game) and legal_moves(game) == []

  @doc """
  Return true if the side to move is stalemated.
  """
  def stalemate?(game), do: not in_check?(game) and legal_moves(game) == []

  @doc """
  Return the check status of the side to move:

    * `:checkmate` - in check and without a legal move
    * `:stalemate` - not in check and without a legal move
    * `:check` - in check
    * `:none` - not in check and with a legal move

  This works out the legal moves once, so it is cheaper than asking the
  checkmate, stalemate and check questions one after the other.
  """
  def check_status(game) do
    check? = in_check?(game)
    moves = legal_moves(game)

    cond do
      moves == [] and check? -> :checkmate
      moves == [] -> :stalemate
      check? -> :check
      true -> :none
    end
  end

  ## Draws

  @doc """
  Return true if neither side has the material to checkmate the other.

  A king against a king, a king and a single minor piece against a king, or
  a king and a bishop against a king and a bishop on squares of the same
  color: in all of these the game cannot end in mate.
  """
  def insufficient_material?(game) do
    board = game.board
    white = minors(board, :white)
    black = minors(board, :black)

    cond do
      heavy_material?(board) ->
        false

      white == [] and black == [] ->
        true

      length(white) + length(black) == 1 ->
        true

      length(white) == 1 and length(black) == 1 ->
        both_bishops?(white, black) and same_colour?(white, black)

      true ->
        false
    end
  end

  @doc """
  Return true if the fifty move rule applies: 50 moves of each player without
  a capture and without a pawn move.
  """
  def fifty_move_rule?(game), do: game.halfmove_clock >= @fifty_moves

  @doc """
  Return true if the seventy five move rule applies: 75 moves of each player
  without a capture and without a pawn move.
  """
  def seventy_five_move_rule?(game), do: game.halfmove_clock >= @seventy_five_moves

  @doc """
  Return how often the current position of the game has occurred.

  A position is the board, the side to move, the castling rights and the en
  passant target; the halfmove clock and the number of the move are not part
  of it. The en passant target only makes a difference when the side to move
  can actually take a pawn en passant.

  The positions of the game are worked out by playing its moves again, from
  the position the game started at.
  """
  def repetition_count(game) do
    keys =
      game
      |> Game.replay()
      |> Enum.map(&position_key/1)

    current = List.last(keys)

    Enum.count(keys, &(&1 == current))
  end

  @doc """
  Return true if the current position has occurred three times.
  """
  def threefold_repetition?(game), do: repetition_count(game) >= 3

  @doc """
  Return true if the current position has occurred five times.
  """
  def fivefold_repetition?(game), do: repetition_count(game) >= 5

  ## Move application

  @doc """
  Apply `move` to the game and return the resulting game state.

  This assumes the move is legal for the side to move. Besides the board, it
  updates the side to move, castling rights, the en passant target and the
  two counters of a FEN record.
  """
  def apply(%Game{} = game, move) do
    color = game.side_to_move
    board = game.board
    captured = captured_piece(board, move)
    {new_board, en_passant} = apply_board(board, move, color)

    %Game{
      game
      | board: new_board,
        side_to_move: Color.opponent(color),
        en_passant: en_passant,
        castling: update_castling(game.castling, board, color, move, captured),
        halfmove_clock: next_halfmove_clock(game, board, move, captured),
        fullmove_number: next_fullmove_number(game, color),
        moves: [move | game.moves]
    }
  end

  ## Attack detection

  # Look for an enemy pawn one rank "behind" the square relative to its
  # direction of travel: pawns attack diagonally forward, never straight ahead.
  defp pawn_attack?(board, square, by_color) do
    rank = Position.rank(square) - Piece.pawn_direction(by_color)
    file_index = Position.file_index(square)

    [file_index - 1, file_index + 1]
    |> Enum.any?(fn index ->
      case Position.at(index, rank) do
        nil -> false
        position -> piece_of?(Board.at(board, position), :pawn, by_color)
      end
    end)
  end

  # A knight attacks from any of the eight L-shaped offsets, regardless of
  # blocking pieces.
  defp knight_attack?(board, square, by_color) do
    Enum.any?(@knight_deltas, fn {fd, rd} ->
      case Position.offset(square, fd, rd) do
        nil -> false
        position -> piece_of?(Board.at(board, position), :knight, by_color)
      end
    end)
  end

  # A king attacks all eight adjacent squares.
  defp king_attack?(board, square, by_color) do
    Enum.any?(@king_deltas, fn {fd, rd} ->
      case Position.offset(square, fd, rd) do
        nil -> false
        position -> piece_of?(Board.at(board, position), :king, by_color)
      end
    end)
  end

  # Rook/queen rays cover ranks and files, bishop/queen rays cover diagonals;
  # either is enough for the square to be attacked.
  defp sliding_attack?(board, square, by_color) do
    ray_attack?(board, square, by_color, @rook_deltas, :rook) or
      ray_attack?(board, square, by_color, @bishop_deltas, :bishop)
  end

  # True if any of the given directions contains a matching slider of by_color.
  defp ray_attack?(board, square, by_color, deltas, type) do
    Enum.any?(deltas, fn {fd, rd} ->
      scan_ray(board, square, by_color, fd, rd, type)
    end)
  end

  # Walk one ray until the board edge or the first piece. Only that first piece
  # matters: a same-colored slider or a queen attacks the square, anything else
  # (including any blocker) stops the attack.
  defp scan_ray(board, square, by_color, fd, rd, type) do
    case Position.offset(square, fd, rd) do
      nil ->
        false

      next ->
        case Board.at(board, next) do
          nil ->
            scan_ray(board, next, by_color, fd, rd, type)

          piece ->
            piece_of?(piece, type, by_color) or piece_of?(piece, :queen, by_color)
        end
    end
  end

  ## Per piece generation

  # Generate moves for the piece on `from`, if there is one.
  defp moves_from(game, from) do
    case Board.at(game.board, from) do
      nil -> []
      piece -> piece_moves(game, from, piece)
    end
  end

  # Dispatch to the generator for the piece type.
  defp piece_moves(game, from, piece) do
    case Piece.type(piece) do
      :pawn -> pawn_moves(game, from)
      :knight -> step_moves(game, from, @knight_deltas)
      :bishop -> ray_moves(game, from, @bishop_deltas)
      :rook -> ray_moves(game, from, @rook_deltas)
      :queen -> ray_moves(game, from, @bishop_deltas ++ @rook_deltas)
      :king -> king_moves(game, from)
      nil -> []
    end
  end

  # A pawn may push to an empty square (one step, plus an optional two-step
  # from its start rank) and capture diagonally, including en passant.
  defp pawn_moves(game, from) do
    color = game.side_to_move
    direction = Piece.pawn_direction(color)
    one = Position.offset(from, 0, direction)

    forward =
      if one && Board.at(game.board, one) == nil do
        promotion_moves(from, one, color) ++ double_step(game, from, color)
      else
        []
      end

    captures =
      [-1, 1]
      |> Enum.map(fn fd -> Position.offset(from, fd, direction) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(fn to -> pawn_capture(game, from, to, color) end)

    forward ++ captures
  end

  # The two-square advance is only available from the pawn's start rank and
  # only when both the intermediate and destination squares are empty.
  defp double_step(game, from, color) do
    if Position.rank(from) == Piece.start_rank(color) do
      two = Position.offset(from, 0, 2 * Piece.pawn_direction(color))

      if two && Board.at(game.board, two) == nil do
        [Move.new(from, two)]
      else
        []
      end
    else
      []
    end
  end

  # A diagonal pawn move: capture an enemy piece, or capture en passant an
  # adjacent pawn that just advanced two squares.
  defp pawn_capture(game, from, to, color) do
    case Board.at(game.board, to) do
      nil ->
        if to == game.en_passant and en_passant_capture?(game, from, to, color) do
          [Move.en_passant(from, to)]
        else
          []
        end

      piece ->
        if not Piece.king?(piece) and not Piece.of_color?(piece, color) do
          promotion_moves(from, to, color)
        else
          []
        end
    end
  end

  # The victim sits beside the moving pawn, not on the destination square.
  defp en_passant_capture?(game, from, to, color) do
    captured = Board.at(game.board, Position.new(Position.file(to), Position.rank(from)))

    Piece.type(captured) == :pawn and not Piece.of_color?(captured, color)
  end

  # A pawn move onto the last rank expands into the four promotion choices;
  # other moves stay plain `{from, to}` tuples.
  defp promotion_moves(from, to, color) do
    if Position.rank(to) == Piece.promotion_rank(color) do
      color
      |> Move.promotions()
      |> Enum.map(fn piece -> Move.promotion(from, to, piece) end)
    else
      [Move.new(from, to)]
    end
  end

  # Single-square movers (knight, king): keep empty or enemy-occupied squares.
  defp step_moves(game, from, deltas) do
    deltas
    |> Enum.map(fn {fd, rd} -> Position.offset(from, fd, rd) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn to -> square_available?(game, to) end)
    |> Enum.map(fn to -> Move.new(from, to) end)
  end

  # Sliding movers (bishop, rook, queen): expand along each direction.
  defp ray_moves(game, from, deltas) do
    deltas
    |> Enum.flat_map(fn {fd, rd} ->
      ray_moves_in_direction(game, from, from, fd, rd)
    end)
  end

  # Collect squares along one ray until the edge, an own piece (stop) or an
  # enemy piece (capture and stop). Kings are never captured.
  defp ray_moves_in_direction(game, from, current, fd, rd) do
    case Position.offset(current, fd, rd) do
      nil ->
        []

      to ->
        case Board.at(game.board, to) do
          nil ->
            [Move.new(from, to) | ray_moves_in_direction(game, from, to, fd, rd)]

          piece ->
            if not Piece.king?(piece) and not Piece.of_color?(piece, game.side_to_move) do
              [Move.new(from, to)]
            else
              []
            end
        end
    end
  end

  # Ordinary king steps plus any available castling moves.
  defp king_moves(game, from) do
    step_moves(game, from, @king_deltas) ++ castling_moves(game, from)
  end

  # Castling is only considered from the king's home square and while the king
  # is not in check.
  defp castling_moves(game, from) do
    color = game.side_to_move

    if from == Castling.king_start(color) and not in_check?(game, color) do
      []
      |> maybe_add_castle(game, color, :king_side, from)
      |> maybe_add_castle(game, color, :queen_side, from)
    else
      []
    end
  end

  # Add one castling move if the right is still available, the rook is home,
  # the path is empty and the king neither crosses nor lands on an attacked
  # square. Checking `attacked?` avoids simulating the move for the transit
  # square.
  defp maybe_add_castle(moves, game, color, side, from) do
    rook = Board.at(game.board, Castling.rook_start(color, side))
    to = Castling.king_destination(color, side)

    cond do
      not MapSet.member?(game.castling, {color, side}) ->
        moves

      not piece_of?(rook, :rook, color) ->
        moves

      Enum.any?(Castling.empty_squares(color, side), fn square ->
        Board.at(game.board, square) != nil
      end) ->
        moves

      Enum.any?(Castling.safe_squares(color, side), fn square ->
        attacked?(game.board, square, Color.opponent(color))
      end) ->
        moves

      true ->
        [Move.castle(from, to) | moves]
    end
  end

  # A destination is available if it is empty or holds an enemy non-king piece.
  defp square_available?(game, to) do
    case Board.at(game.board, to) do
      nil -> true
      piece -> not Piece.king?(piece) and not Piece.of_color?(piece, game.side_to_move)
    end
  end

  ## Board application

  # Apply the board change for each move kind; also return the en passant
  # target created by a double pawn push (nil otherwise).
  defp apply_board(board, {from, to} = move, _color) do
    {Board.move(board, from, to), double_push_target(board, move)}
  end

  defp apply_board(board, {:castle, from, to} = move, color) do
    side = Move.castle_side(move)

    board =
      board
      |> Board.move(from, to)
      |> Board.move(Castling.rook_start(color, side), Castling.rook_destination(color, side))

    {board, nil}
  end

  defp apply_board(board, {:en_passant, from, to} = move, _color) do
    captured = Move.capture_square(move)
    board = board |> Board.remove(captured) |> Board.move(from, to)

    {board, nil}
  end

  defp apply_board(board, {:promotion, from, to, piece}, _color) do
    board = board |> Board.remove(from) |> Board.put(to, piece)

    {board, nil}
  end

  # The en passant target is the square the pawn skipped over.
  defp double_push_target(board, move) do
    if Piece.type(Board.at(board, Move.from(move))) == :pawn do
      Move.skipped_square(move)
    end
  end

  # Find the captured piece before the board changes.
  defp captured_piece(board, move) do
    case Move.capture_square(move) do
      nil -> nil
      square -> Board.at(board, square)
    end
  end

  ## Draws

  # The pieces that are enough to mate on their own.
  defp heavy_material?(board) do
    Enum.any?(board, fn {_position, piece} ->
      Piece.type(piece) in [:pawn, :rook, :queen]
    end)
  end

  # The bishops and knights of a color: the pieces that are not enough on
  # their own.
  defp minors(board, color) do
    board
    |> Board.pieces(color)
    |> Enum.filter(fn {_position, piece} ->
      Piece.type(piece) in [:bishop, :knight]
    end)
  end

  # Both sides hold a single bishop.
  defp both_bishops?([{_first, first_piece}], [{_second, second_piece}]) do
    Piece.type(first_piece) == :bishop and Piece.type(second_piece) == :bishop
  end

  # The two bishops stand on squares of the same color.
  defp same_colour?([{first_position, _first_piece}], [{second_position, _second_piece}]) do
    Position.same_color?(first_position, second_position)
  end

  # The key of a position: the board, the side to move, the castling rights
  # and the en passant target.
  defp position_key(game) do
    {game.board, game.side_to_move, game.castling, en_passant_key(game)}
  end

  # The en passant target is part of the position only when the side to move
  # can take a pawn with it. A pawn of that side stands beside the target, on
  # the rank it would capture from, so this is the same question as whether the
  # target is attacked by a pawn of the side to move.
  defp en_passant_key(game) do
    if game.en_passant != nil and
         pawn_attack?(game.board, game.en_passant, game.side_to_move) do
      game.en_passant
    end
  end

  ## Castling rights

  # Drop rights for a moved king/rook and for a rook captured on its home
  # square.
  defp update_castling(castling, board, color, move, captured) do
    from = Move.from(move)

    castling
    |> revoke_for_moved(color, Board.at(board, from), from)
    |> revoke_for_captured(captured, Move.to(move))
  end

  # Losing rights when the king moves (both) or a rook leaves a home corner.
  defp revoke_for_moved(castling, _color, nil, _from), do: castling

  defp revoke_for_moved(castling, color, piece, from) do
    case Piece.type(piece) do
      :king ->
        castling
        |> revoke(color, :king_side)
        |> revoke(color, :queen_side)

      :rook ->
        revoke_for_rook_square(castling, color, from)

      _other ->
        castling
    end
  end

  # Losing rights when a rook is captured on its home corner.
  defp revoke_for_captured(castling, captured, square) do
    if Piece.type(captured) == :rook do
      revoke_for_rook_square(castling, Piece.color(captured), square)
    else
      castling
    end
  end

  # A rook's home square names its side; any other square names no side.
  defp revoke_for_rook_square(castling, color, square) do
    side =
      Enum.find(Castling.sides(), fn side ->
        Castling.rook_start(color, side) == square
      end)

    if side, do: revoke(castling, color, side), else: castling
  end

  # Remove one castling right from the set.
  defp revoke(castling, color, side), do: MapSet.delete(castling, {color, side})

  ## Counters

  # The halfmove clock counts the plies since the last capture or the last
  # pawn move; a capture or a pawn move starts it over.
  defp next_halfmove_clock(game, board, move, captured) do
    if captured != nil or Piece.type(Board.at(board, Move.from(move))) == :pawn do
      0
    else
      game.halfmove_clock + 1
    end
  end

  # The number of the full move goes up after the move of Black.
  defp next_fullmove_number(game, color) do
    if color == :black, do: game.fullmove_number + 1, else: game.fullmove_number
  end

  ## Helpers

  # Piece is of the given type and color (nil is neither).
  defp piece_of?(piece, type, color) do
    Piece.type(piece) == type and Piece.of_color?(piece, color)
  end
end
