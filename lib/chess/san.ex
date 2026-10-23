defmodule Chess.SAN do
  @moduledoc """
  Standard Algebraic Notation (SAN): the notation chess moves are written in,
  as in `1. e4 e5 2. Nf3 Nc6`.

  A token names the piece that moves, optionally the square it comes from (to
  tell pieces of the same type apart), an optional capture marker, the
  destination square, an optional promotion piece and an optional check or
  checkmate marker.

  `parse/2` reads a token in the context of a game and returns the
  `Chess.Move` it stands for. `to_san/2` does the opposite. Both work on the
  legal moves of the position, so a token always describes exactly one move.
  """

  alias Chess.{Board, Castling, Move, Position, Rules}
  alias Chess.SAN.ParseError

  @piece_letters ~w(K Q R B N)
  @promotion_pieces ~w(Q R B N q r b n)

  @doc """
  Parse a SAN token into a `Chess.Move`.

  The move is looked up in the legal moves of `game`, the position before the
  move. Raises `Chess.SAN.ParseError` when the token is malformed, when no
  legal move matches it or when it matches more than one.

  Options:

    * `:validate_marker` - check that the `+` and `#` markers agree with the
      move (default `true`).
  """
  def parse(san, game, opts \\ []) do
    token = String.trim(san)
    {token, marker} = split_marker(token)

    move = resolve(token, game)

    if Keyword.get(opts, :validate_marker, true) do
      validate_marker!(move, marker, game, token)
    end

    move
  end

  @doc """
  Return the SAN token for `move` in the given position.

  The position is the one *before* the move. Raises `Chess.SAN.ParseError`
  when the move is not legal in that position.
  """
  def to_san(move, game) do
    unless Rules.legal_move?(game, move) do
      raise ParseError, "#{inspect(move)} is not a legal move in this position"
    end

    from = Move.from(move)
    to = Move.to(move)
    promotion = Move.promotion_piece(move)
    piece = Board.at(game.board, from)

    san_body(game, move, from, to, promotion, piece) <> marker(move, game)
  end

  ## Parsing

  # The check and checkmate markers are a suffix of the token: "+" for check,
  # "#" for checkmate. Some writers use "++" for a double check.
  defp split_marker(token) do
    cond do
      String.ends_with?(token, "#") -> {String.trim_trailing(token, "#"), :mate}
      String.ends_with?(token, "+") -> {String.trim_trailing(token, "+"), :check}
      true -> {token, :none}
    end
  end

  defp resolve(token, game) do
    case parse_token(token) do
      {:castle, side} -> find_castle(game, side, token)
      {:move, description} -> find_move(game, description, token)
      :error -> raise ParseError, "#{inspect(token)} is not a valid SAN token"
    end
  end

  # Castling is written as the king moving two squares: "O-O" to the king
  # side, "O-O-O" to the queen side. The zeros are accepted as well.
  defp parse_token(token) do
    case castling(token) do
      {:ok, side} -> {:castle, side}
      :error -> parse_move_token(token)
    end
  end

  defp castling("O-O-O"), do: {:ok, :queen_side}
  defp castling("0-0-0"), do: {:ok, :queen_side}
  defp castling("O-O"), do: {:ok, :king_side}
  defp castling("0-0"), do: {:ok, :king_side}
  defp castling(_token), do: :error

  # A move token is read from the right: the destination square comes last,
  # preceded by the optional promotion, the optional capture marker and the
  # hints about the square the piece comes from.
  defp parse_move_token(token) do
    with {:ok, rest, promotion} <- split_promotion(token),
         {:ok, origin, to} <- split_destination(rest),
         {:ok, origin, capture?} <- split_capture(origin),
         {:ok, piece, from_file, from_rank} <- split_origin(origin, capture?) do
      {:move,
       %{
         piece: piece,
         from_file: from_file,
         from_rank: from_rank,
         capture?: capture?,
         to: to,
         promotion: promotion
       }}
    else
      _error -> :error
    end
  end

  # The promotion piece follows an "=" and comes last: "e8=Q".
  defp split_promotion(token) do
    case String.split(token, "=", parts: 2) do
      [_rest, ""] ->
        :error

      [rest, piece] ->
        if String.length(piece) == 1 and piece in @promotion_pieces do
          {:ok, rest, piece}
        else
          :error
        end

      _token ->
        {:ok, token, nil}
    end
  end

  # A capture is marked with an "x" between the origin and the destination.
  defp split_capture(origin) do
    if String.ends_with?(origin, "x") do
      {:ok, String.slice(origin, 0..-2//1), true}
    else
      {:ok, origin, false}
    end
  end

  # The destination is the last two characters of the token.
  defp split_destination(token) do
    if String.length(token) >= 2 do
      destination = String.slice(token, -2..-1//1)

      if valid_square?(destination) do
        {:ok, String.slice(token, 0..-3//1), Position.from_string(destination)}
      else
        :error
      end
    else
      :error
    end
  end

  # What is left is the piece and the hints about the square it comes from.
  # A piece token starts with the letter of the piece, a pawn token with the
  # file the pawn comes from - which is only written for a capture.
  defp split_origin(origin, capture?) do
    case origin do
      "" ->
        {:ok, nil, nil, nil}

      <<piece::binary-size(1), rest::binary>> ->
        if piece in @piece_letters do
          with {:ok, from_file, from_rank} <- split_hints(rest) do
            {:ok, piece, from_file, from_rank}
          end
        else
          case split_hints(origin) do
            {:ok, from_file, nil} when capture? -> {:ok, nil, from_file, nil}
            _error -> :error
          end
        end
    end
  end

  # The hints are the file and the rank of the square the piece comes from.
  defp split_hints(hints) do
    case hints do
      "" ->
        {:ok, nil, nil}

      <<file, rest::binary>> when file in ?a..?h ->
        case rest do
          "" -> {:ok, file_index(file), nil}
          <<rank>> when rank in ?1..?8 -> {:ok, file_index(file), rank - ?0}
          _other -> :error
        end

      <<rank>> when rank in ?1..?8 ->
        {:ok, nil, rank - ?0}

      _other ->
        :error
    end
  end

  defp valid_square?(<<file, rank>>), do: file in ?a..?h and rank in ?1..?8
  defp valid_square?(_destination), do: false

  defp file_index(file), do: file - ?a + 1

  # Look the move up in the legal moves of the position. Every legal move that
  # fits the token is a candidate; there must be exactly one.
  defp find_move(game, description, token) do
    candidates = Enum.filter(Rules.legal_moves(game), &matches?(game, &1, description))

    case candidates do
      [move] ->
        move

      [] ->
        raise ParseError, "no legal move matches #{inspect(token)}"

      many ->
        raise ParseError, "#{inspect(token)} matches #{length(many)} legal moves"
    end
  end

  defp matches?(game, move, description) do
    from = Move.from(move)
    to = Move.to(move)
    piece = piece_letter(Board.at(game.board, from))

    to == description.to and
      piece_matches?(piece, description.piece) and
      file_matches?(from, description.from_file) and
      rank_matches?(from, description.from_rank) and
      capture?(game, move) == description.capture? and
      promotion_matches?(Move.promotion_piece(move), description.promotion)
  end

  # A token without a piece letter is a pawn move; every other piece is named.
  defp piece_matches?("P", nil), do: true
  defp piece_matches?(piece, piece), do: true
  defp piece_matches?(_piece, _expected), do: false

  defp file_matches?(_from, nil), do: true
  defp file_matches?(from, file), do: Position.file_index(from) == file

  defp rank_matches?(_from, nil), do: true
  defp rank_matches?(from, rank), do: Position.rank(from) == rank

  defp promotion_matches?(nil, nil), do: true
  defp promotion_matches?(piece, expected), do: to_string(piece) == expected

  # Castling is written without a destination square: the king lands on the
  # side the rook stands on.
  defp find_castle(game, side, token) do
    destination = Castling.king_destination(game.side_to_move, side)

    candidates =
      Enum.filter(Rules.legal_moves(game), fn
        {:castle, _from, to} -> to == destination
        _other -> false
      end)

    case candidates do
      [move] ->
        move

      [] ->
        raise ParseError, "no legal castling move matches #{inspect(token)}"

      many ->
        raise ParseError, "#{inspect(token)} matches #{length(many)} legal moves"
    end
  end

  # The marker has to agree with the position the move leads to.
  defp validate_marker!(move, marker, game, token) do
    actual = marker_kind(move, game)

    if actual != marker do
      raise ParseError,
            "#{inspect(token)} is marked #{marker} but the move gives #{actual}"
    end
  end

  ## Writing

  # The body of the token: the piece, the hints, the capture marker, the
  # destination and the promotion.
  defp san_body(game, move, from, to, promotion, piece) do
    case move do
      {:castle, _from, _to} = castle ->
        if Move.castle_side(castle) == :king_side, do: "O-O", else: "O-O-O"

      _other ->
        destination = to_string(to)
        promotion = if promotion, do: "=" <> to_string(promotion), else: ""

        case piece_letter(piece) do
          "P" ->
            if capture?(game, move) do
              to_string(Position.file(from)) <> "x" <> destination <> promotion
            else
              destination <> promotion
            end

          letter ->
            letter <>
              disambiguation(game, move, from, to, piece) <>
              capture_marker(capture?(game, move)) <> destination <> promotion
        end
    end
  end

  # Other pieces of the same type that can reach the same square. The file is
  # used when it tells the pieces apart, else the rank, else both.
  defp disambiguation(game, move, from, to, piece) do
    case siblings(game, move, to, piece) do
      [] ->
        ""

      others ->
        file = Position.file_index(from)
        rank = Position.rank(from)
        files = Enum.map(others, &Position.file_index/1)
        ranks = Enum.map(others, &Position.rank/1)

        cond do
          file not in files -> file_letter(file)
          rank not in ranks -> to_string(rank)
          true -> file_letter(file) <> to_string(rank)
        end
    end
  end

  defp siblings(game, move, to, piece) do
    Rules.legal_moves(game)
    |> Enum.reject(&(&1 == move))
    |> Enum.filter(fn candidate ->
      Move.to(candidate) == to and Board.at(game.board, Move.from(candidate)) == piece
    end)
    |> Enum.map(&Move.from/1)
  end

  defp file_letter(index), do: <<?a + index - 1>>

  defp capture_marker(true), do: "x"
  defp capture_marker(false), do: ""

  # A capture leaves a piece on the square the move takes on: the destination,
  # or the square beside the destination for en passant.
  defp capture?(game, move) do
    case Move.capture_square(move) do
      nil -> false
      square -> Board.at(game.board, square) != nil
    end
  end

  # The check and checkmate markers describe the position the move leads to.
  defp marker(move, game) do
    case marker_kind(move, game) do
      :mate -> "#"
      :check -> "+"
      :none -> ""
    end
  end

  defp marker_kind(move, game) do
    after_move = Rules.apply(game, move)

    case Rules.check_status(after_move) do
      :checkmate -> :mate
      :check -> :check
      _other -> :none
    end
  end

  ## Helpers

  # The letter a piece is written with; white and black use the same letter.
  defp piece_letter(piece), do: piece |> to_string() |> String.upcase()
end
