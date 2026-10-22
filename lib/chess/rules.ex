defmodule Chess.Rules do
  @moduledoc """
  Move legality and move generation for a `Chess.Game`.

  Castling rights, the en passant target and the side to move live in the game
  state, because they cannot be derived from the board alone.
  """

  alias Chess.{Board, Game, Move, Piece, Position}

  import Kernel, except: [apply: 2]

  @positions Position.all()
  @colors [:white, :black]

  @knight_deltas [{1, 2}, {2, 1}, {2, -1}, {1, -2}, {-1, -2}, {-2, -1}, {-2, 1}, {-1, 2}]

  @king_deltas [{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}]

  @rook_deltas [{1, 0}, {-1, 0}, {0, 1}, {0, -1}]

  @bishop_deltas [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}]

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
      king -> attacked?(game.board, king, opponent(color))
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
    Move.is_valid?(move) and move in legal_moves(game)
  end

  @doc """
  Return true if the side to move is checkmated.
  """
  def checkmate?(game), do: in_check?(game) and legal_moves(game) == []

  @doc """
  Return true if the side to move is stalemated.
  """
  def stalemate?(game), do: not in_check?(game) and legal_moves(game) == []

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
        side_to_move: opponent(color),
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
    rank = Position.rank(square) - pawn_direction(by_color)
    file_index = Position.file_index(square)

    [file_index - 1, file_index + 1]
    |> Enum.any?(fn index ->
      case position_at(index, rank) do
        nil -> false
        position -> pawn_of?(Board.at(board, position), by_color)
      end
    end)
  end

  # A knight attacks from any of the eight L-shaped offsets, regardless of
  # blocking pieces.
  defp knight_attack?(board, square, by_color) do
    Enum.any?(@knight_deltas, fn {fd, rd} ->
      case offset(square, fd, rd) do
        nil -> false
        position -> knight_of?(Board.at(board, position), by_color)
      end
    end)
  end

  # A king attacks all eight adjacent squares.
  defp king_attack?(board, square, by_color) do
    Enum.any?(@king_deltas, fn {fd, rd} ->
      case offset(square, fd, rd) do
        nil -> false
        position -> king_of?(Board.at(board, position), by_color)
      end
    end)
  end

  # Rook/queen rays cover ranks and files, bishop/queen rays cover diagonals;
  # either is enough for the square to be attacked.
  defp sliding_attack?(board, square, by_color) do
    ray_attack?(board, square, by_color, @rook_deltas, &Piece.is_rook?/1) or
      ray_attack?(board, square, by_color, @bishop_deltas, &Piece.is_bishop?/1)
  end

  # True if any of the given directions contains a matching slider of by_color.
  defp ray_attack?(board, square, by_color, deltas, piece?) do
    Enum.any?(deltas, fn {fd, rd} ->
      scan_ray(board, square, by_color, fd, rd, piece?)
    end)
  end

  # Walk one ray until the board edge or the first piece. Only that first piece
  # matters: a same-colored slider or a queen attacks the square, anything else
  # (including any blocker) stops the attack.
  defp scan_ray(board, square, by_color, fd, rd, piece?) do
    case offset(square, fd, rd) do
      nil ->
        false

      next ->
        case Board.at(board, next) do
          nil ->
            scan_ray(board, next, by_color, fd, rd, piece?)

          piece ->
            of_color?(piece, by_color) and (piece?.(piece) or Piece.is_queen?(piece))
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
    cond do
      Piece.is_pawn?(piece) -> pawn_moves(game, from)
      Piece.is_knight?(piece) -> step_moves(game, from, @knight_deltas)
      Piece.is_bishop?(piece) -> ray_moves(game, from, @bishop_deltas)
      Piece.is_rook?(piece) -> ray_moves(game, from, @rook_deltas)
      Piece.is_queen?(piece) -> ray_moves(game, from, @bishop_deltas ++ @rook_deltas)
      Piece.is_king?(piece) -> king_moves(game, from)
      true -> []
    end
  end

  # A pawn may push to an empty square (one step, plus an optional two-step
  # from its start rank) and capture diagonally, including en passant.
  defp pawn_moves(game, from) do
    color = game.side_to_move
    direction = pawn_direction(color)
    one = offset(from, 0, direction)

    forward =
      if one && Board.at(game.board, one) == nil do
        promotion_moves(from, one, color) ++ double_step(game, from, color)
      else
        []
      end

    captures =
      [-1, 1]
      |> Enum.map(fn fd -> offset(from, fd, direction) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(fn to -> pawn_capture(game, from, to, color) end)

    forward ++ captures
  end

  # The two-square advance is only available from the pawn's start rank and
  # only when both the intermediate and destination squares are empty.
  defp double_step(game, from, color) do
    if Position.rank(from) == start_rank(color) do
      two = offset(from, 0, 2 * pawn_direction(color))

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
        if not Piece.is_king?(piece) and not of_color?(piece, color) do
          promotion_moves(from, to, color)
        else
          []
        end
    end
  end

  # The victim sits beside the moving pawn, not on the destination square.
  defp en_passant_capture?(game, from, to, color) do
    captured = Board.at(game.board, Position.new(Position.file(to), Position.rank(from)))

    Piece.is_pawn?(captured) and not of_color?(captured, color)
  end

  # A pawn move onto the last rank expands into the four promotion choices;
  # other moves stay plain `{from, to}` tuples.
  defp promotion_moves(from, to, color) do
    if Position.rank(to) == promotion_rank(color) do
      color
      |> promotion_pieces()
      |> Enum.map(fn piece -> Move.promotion(from, to, piece) end)
    else
      [Move.new(from, to)]
    end
  end

  # Single-square movers (knight, king): keep empty or enemy-occupied squares.
  defp step_moves(game, from, deltas) do
    deltas
    |> Enum.map(fn {fd, rd} -> offset(from, fd, rd) end)
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
    case offset(current, fd, rd) do
      nil ->
        []

      to ->
        case Board.at(game.board, to) do
          nil ->
            [Move.new(from, to) | ray_moves_in_direction(game, from, to, fd, rd)]

          piece ->
            if not Piece.is_king?(piece) and not of_color?(piece, game.side_to_move) do
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

    if from == king_start(color) and not in_check?(game, color) do
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
    rank = home_rank(color)

    {rook_file, empty_files, safe_files, to_file} =
      case side do
        :king_side -> {:h, [:f, :g], [:f, :g], :g}
        :queen_side -> {:a, [:b, :c, :d], [:c, :d], :c}
      end

    rook = Board.at(game.board, Position.new(rook_file, rank))
    to = Position.new(to_file, rank)

    cond do
      not MapSet.member?(game.castling, {color, side}) ->
        moves

      not own_rook?(rook, color) ->
        moves

      Enum.any?(empty_files, fn file -> Board.at(game.board, Position.new(file, rank)) != nil end) ->
        moves

      Enum.any?(safe_files, fn file ->
        attacked?(game.board, Position.new(file, rank), opponent(color))
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
      piece -> not Piece.is_king?(piece) and not of_color?(piece, game.side_to_move)
    end
  end

  ## Board application

  # Apply the board change for each move kind; also return the en passant
  # target created by a double pawn push (nil otherwise).
  defp apply_board(board, {from, to}, color) do
    {Board.move(board, from, to), double_push_target(board, from, to, color)}
  end

  defp apply_board(board, {:castle, from, to}, _color) do
    {castle_board(board, from, to), nil}
  end

  defp apply_board(board, {:en_passant, from, to}, _color) do
    captured = Position.new(Position.file(to), Position.rank(from))
    board = board |> Board.remove(captured) |> Board.move(from, to)

    {board, nil}
  end

  defp apply_board(board, {:promotion, from, to, piece}, _color) do
    board = board |> Board.remove(from) |> Board.put(to, piece)

    {board, nil}
  end

  # Move the king and then the rook to the other side of it. Which rook moves
  # is implied by the king's destination file (g = king side, c = queen side).
  defp castle_board(board, from, to) do
    rank = Position.rank(from)

    {rook_from_file, rook_to_file} =
      case Position.file(to) do
        :g -> {:h, :f}
        :c -> {:a, :d}
      end

    board
    |> Board.move(from, to)
    |> Board.move(Position.new(rook_from_file, rank), Position.new(rook_to_file, rank))
  end

  # The en passant target is the square the pawn skipped over.
  defp double_push_target(board, from, to, _color) do
    if Piece.is_pawn?(Board.at(board, from)) and
         abs(Position.rank(to) - Position.rank(from)) == 2 do
      offset(from, 0, div(Position.rank(to) - Position.rank(from), 2))
    else
      nil
    end
  end

  # Find the captured piece before the board changes. En passant is special
  # because the captured pawn is beside the destination, not on it.
  defp captured_piece(board, {_from, to}), do: Board.at(board, to)

  defp captured_piece(_board, {:castle, _from, _to}), do: nil

  defp captured_piece(board, {:en_passant, from, to}) do
    Board.at(board, Position.new(Position.file(to), Position.rank(from)))
  end

  defp captured_piece(board, {:promotion, _from, to, _piece}), do: Board.at(board, to)

  ## Castling rights

  # Drop rights for a moved king/rook and for a rook captured on its home
  # square.
  defp update_castling(castling, board, color, move, captured) do
    from = move_from(move)

    castling
    |> revoke_for_moved(color, Board.at(board, from), from)
    |> revoke_for_captured(captured, move_to(move))
  end

  # Losing rights when the king moves (both) or a rook leaves a home corner.
  defp revoke_for_moved(castling, _color, nil, _from), do: castling

  defp revoke_for_moved(castling, color, piece, from) do
    cond do
      Piece.is_king?(piece) ->
        castling
        |> revoke(color, :king_side)
        |> revoke(color, :queen_side)

      Piece.is_rook?(piece) and Position.rank(from) == home_rank(color) ->
        revoke_for_rook_square(castling, color, Position.file(from))

      true ->
        castling
    end
  end

  # Losing rights when a rook is captured on its home corner.
  defp revoke_for_captured(castling, nil, _to), do: castling

  defp revoke_for_captured(castling, piece, to) do
    if Piece.is_rook?(piece) do
      color = if Piece.is_white?(piece), do: :white, else: :black

      if Position.rank(to) == home_rank(color) do
        revoke_for_rook_square(castling, color, Position.file(to))
      else
        castling
      end
    else
      castling
    end
  end

  # Map a rook's home file to its castling side.
  defp revoke_for_rook_square(castling, color, :h), do: revoke(castling, color, :king_side)
  defp revoke_for_rook_square(castling, color, :a), do: revoke(castling, color, :queen_side)
  defp revoke_for_rook_square(castling, _color, _file), do: castling

  # Remove one castling right from the set.
  defp revoke(castling, color, side), do: MapSet.delete(castling, {color, side})

  ## Counters

  # The halfmove clock counts the plies since the last capture or the last
  # pawn move; a capture or a pawn move starts it over.
  defp next_halfmove_clock(game, board, move, captured) do
    if captured != nil or Piece.is_pawn?(Board.at(board, move_from(move))) do
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

  # The origin square of any move shape.
  defp move_from({from, _to}), do: from
  defp move_from({_kind, from, _to}), do: from
  defp move_from({:promotion, from, _to, _piece}), do: from

  # The destination square of any move shape.
  defp move_to({_from, to}), do: to
  defp move_to({_kind, _from, to}), do: to
  defp move_to({:promotion, _from, to, _piece}), do: to

  # Build a position from 1-based file/rank indexes, or nil when off-board.
  defp position_at(file_index, rank)
       when file_index in 1..8 and rank in 1..8 do
    Position.new(file_index, rank)
  end

  defp position_at(_file_index, _rank), do: nil

  # Move a position by a file/rank delta, or nil when it leaves the board.
  defp offset(position, file_delta, rank_delta) do
    position_at(
      Position.file_index(position) + file_delta,
      Position.rank(position) + rank_delta
    )
  end

  # The other color.
  defp opponent(:white), do: :black
  defp opponent(:black), do: :white

  # White pawns advance towards rank 8, black pawns towards rank 1.
  defp pawn_direction(:white), do: 1
  defp pawn_direction(:black), do: -1

  # Rank on which pawns may make their initial two-square advance.
  defp start_rank(:white), do: 2
  defp start_rank(:black), do: 7

  # Last rank for each color.
  defp promotion_rank(:white), do: 8
  defp promotion_rank(:black), do: 1

  # Back rank for each color (kings, rooks, castling).
  defp home_rank(:white), do: 1
  defp home_rank(:black), do: 8

  # King's initial square, the only square castling may start from.
  defp king_start(:white), do: :e1
  defp king_start(:black), do: :e8

  # Promotion choices, using the case that matches the color's pieces.
  defp promotion_pieces(:white), do: [:Q, :R, :B, :N]
  defp promotion_pieces(:black), do: [:q, :r, :b, :n]

  # Color checks for pieces (nil is neither).
  defp of_color?(piece, :white), do: Piece.is_white?(piece)
  defp of_color?(piece, :black), do: Piece.is_black?(piece)

  # Piece is a pawn of the given color.
  defp pawn_of?(piece, color), do: Piece.is_pawn?(piece) and of_color?(piece, color)

  # Piece is a knight of the given color.
  defp knight_of?(piece, color), do: Piece.is_knight?(piece) and of_color?(piece, color)

  # Piece is a king of the given color.
  defp king_of?(piece, color), do: Piece.is_king?(piece) and of_color?(piece, color)

  # Piece is a rook of the given color.
  defp own_rook?(piece, color), do: Piece.is_rook?(piece) and of_color?(piece, color)
end
