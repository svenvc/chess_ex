defmodule Chess.FEN do
  @moduledoc """
  Reading and writing FEN (Forsyth-Edwards Notation).

  A FEN record describes a position in six fields, separated by spaces:

      rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1

    * the placement of the pieces, rank by rank from the eighth rank down to
      the first, the empty squares of a rank written as a number
    * the side to move: `w` for white, `b` for black
    * the castling rights: `K`, `Q`, `k` and `q`, or `-` when there are none
    * the en passant target square, or `-` when there is none
    * the halfmove clock: the number of plies since the last capture or the
      last pawn move
    * the number of the full move that is being played

  `parse/1` reads a record and returns the `Chess.Game` it describes,
  `to_fen/1` writes a game back.

  The reader is strict about the shape of a record and forgiving about the
  position it describes: a record without a king, with a pawn on the back
  rank or with a side to move that stands in check is read as it stands. A
  record of four fields - the two counters left out - is read as well, with
  the counters set to zero and one.

  The writer is canonical: the castling rights come out in the order `KQkq`,
  the en passant target is written as the game holds it and the counters are
  written as they stand. A record read in any other order is written back in
  this one.
  """

  alias Chess.{Board, Castling, Game, Position}
  alias Chess.FEN.ParseError

  @piece_chars ~c"PNBRQKpnbrqk"

  @doc """
  Read a FEN record and return the game it describes.

  The game holds the position, the side to move, the castling rights, the en
  passant target and the two counters. Its `:start` field holds the position
  itself, so that the moves played from it can be played back later.

  Raises `Chess.FEN.ParseError` when the record is not a FEN record.
  """
  def parse(text) do
    fields = text |> String.trim() |> String.split(~r/\s+/)

    case fields do
      [board, side, castling, en_passant, halfmove, fullmove] ->
        build(board, side, castling, en_passant, halfmove, fullmove)

      [board, side, castling, en_passant] ->
        build(board, side, castling, en_passant, "0", "1")

      fields ->
        raise ParseError, "a FEN record holds four or six fields, found #{length(fields)}"
    end
  end

  @doc """
  Write a game as a FEN record.
  """
  def to_fen(%Game{} = game) do
    Enum.join(
      [
        board_field(game.board),
        side_field(game.side_to_move),
        castling_field(game.castling),
        en_passant_field(game.en_passant),
        Integer.to_string(game.halfmove_clock),
        Integer.to_string(game.fullmove_number)
      ],
      " "
    )
  end

  ## Reading

  # The game the record describes. The position is its own start, so that the
  # moves played from it can be played back from it.
  defp build(board, side, castling, en_passant, halfmove, fullmove) do
    position = %Game{
      board: parse_board(board),
      side_to_move: parse_side(side),
      castling: parse_castling(castling),
      en_passant: parse_en_passant(en_passant),
      halfmove_clock: parse_counter(halfmove, "halfmove clock"),
      fullmove_number: parse_fullmove(fullmove)
    }

    %{position | start: position}
  end

  # The board field: eight ranks, separated by slashes, from the eighth rank
  # down to the first. A rank holds the letters of its pieces and the numbers
  # of its empty squares.
  defp parse_board(field) do
    ranks = String.split(field, "/")

    if length(ranks) != 8 do
      raise ParseError, "the board holds eight ranks, found #{length(ranks)}"
    end

    ranks
    |> Enum.with_index()
    |> Enum.flat_map(fn {text, index} ->
      rank = 8 - index
      {file_index, entries} = parse_rank(text, rank, 1)

      if file_index != 9 do
        raise ParseError, "the rank #{rank} holds eight squares, found #{file_index - 1}"
      end

      entries
    end)
    |> Map.new()
  end

  # Read one rank and return its `{position, piece}` entries. The file index
  # walks along the rank and has to end up behind the eighth file.
  defp parse_rank(text, rank, file_index) do
    case text do
      "" ->
        {file_index, []}

      <<char, rest::binary>> ->
        cond do
          char in ?1..?8 ->
            count = char - ?0

            if file_index + count > 9 do
              raise ParseError, "the rank #{rank} holds more than eight squares"
            end

            {next, entries} = parse_rank(rest, rank, file_index + count)
            {next, entries}

          char in @piece_chars ->
            if file_index > 8 do
              raise ParseError, "the rank #{rank} holds more than eight squares"
            end

            {next, entries} = parse_rank(rest, rank, file_index + 1)
            {next, [{Position.new(file_index, rank), String.to_atom(<<char>>)} | entries]}

          true ->
            raise ParseError, "unknown piece #{inspect(<<char>>)} on rank #{rank}"
        end
    end
  end

  # The side to move.
  defp parse_side("w"), do: :white
  defp parse_side("b"), do: :black

  defp parse_side(field),
    do: raise(ParseError, "the side to move is not w or b: #{inspect(field)}")

  # The castling rights.
  defp parse_castling("-"), do: MapSet.new()

  defp parse_castling(field) do
    field
    |> String.graphemes()
    |> Enum.map(fn letter ->
      case Castling.right_for_letter(letter) do
        nil -> raise ParseError, "unknown castling right #{inspect(letter)}"
        right -> right
      end
    end)
    |> MapSet.new()
  end

  # The en passant target square.
  defp parse_en_passant("-"), do: nil

  defp parse_en_passant(field) do
    case field do
      <<file, rank>> when file in ?a..?h and rank in ?1..?8 ->
        Position.new(String.to_atom(<<file>>), rank - ?0)

      _other ->
        raise ParseError, "the en passant target is not a square: #{inspect(field)}"
    end
  end

  # The halfmove clock.
  defp parse_counter(text, name) do
    case Integer.parse(text) do
      {number, ""} when number >= 0 -> number
      _other -> raise ParseError, "the #{name} is not a number: #{inspect(text)}"
    end
  end

  # The number of the full move, which starts at one.
  defp parse_fullmove(text) do
    number = parse_counter(text, "fullmove number")

    if number < 1 do
      raise ParseError, "the fullmove number starts at 1: #{inspect(text)}"
    end

    number
  end

  ## Writing

  # The board, rank by rank from the eighth rank down to the first, with the
  # empty squares of a rank written as a number.
  defp board_field(board) do
    board
    |> Board.rows()
    |> Enum.map_join("/", fn row ->
      row
      |> Enum.map(fn {_position, piece} -> if piece, do: to_string(piece), else: "." end)
      |> collapse()
    end)
  end

  # A run of empty squares becomes the number of the squares in the run.
  defp collapse(squares) do
    squares
    |> Enum.chunk_by(& &1)
    |> Enum.map_join(fn run ->
      if Enum.all?(run, &(&1 == ".")) do
        Integer.to_string(length(run))
      else
        Enum.join(run)
      end
    end)
  end

  # The side to move.
  defp side_field(:white), do: "w"
  defp side_field(:black), do: "b"

  # The castling rights, always in the order KQkq.
  defp castling_field(castling) do
    letters =
      Castling.fen_letters()
      |> Enum.filter(fn {_letter, right} -> MapSet.member?(castling, right) end)
      |> Enum.map_join("", fn {letter, _right} -> letter end)

    if letters == "", do: "-", else: letters
  end

  # The en passant target square.
  defp en_passant_field(nil), do: "-"
  defp en_passant_field(position), do: to_string(position)
end
