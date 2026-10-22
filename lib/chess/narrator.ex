defmodule Chess.Narrator do
  @moduledoc """
  A plain-language description of a game, ply by ply.

  The narrator writes out what happened in a game: the board, the move in
  words, the board again and the evaluated strength of the position. It ends
  with a sentence about how the game stopped.

  The game is given as a `Chess.PGN.Game`, a `Chess.Game` or a plain list of
  moves in the order they were played:

      Chess.Narrator.print(Chess.PGN.parse_file("test/fixtures/The_Opera_game.pgn"))

  The moves of a `Chess.Game` are newest first; the narrator plays them back
  in the order they were played. A `Chess.Game` without moves is described
  as it stands.
  """

  alias Chess.{Board, Evaluation, Game, Piece, Position, Rules, SAN}
  alias Chess.PGN

  @doc """
  Describe the game and return the text.

  Every ply holds the move in algebraic notation, the move in words, the
  board the move leads to and the evaluated strength of that board. The text
  ends with a sentence about how the game stopped.
  """
  def describe(input) do
    %{moves: moves, result: result, headers: headers, start: start, label: label} = parts(input)

    {steps, final} = play(moves, start)

    all =
      [header_step(headers), position_step(start, label)] ++ steps ++ [ending_step(final, result)]

    all
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc """
  Describe the game and write it out.
  """
  def print(input), do: IO.puts(describe(input))

  @doc """
  Describe only the last move of a game, or the initial position if no moves
  have been played.
  """
  def describe_last_move(%Game{moves: []} = game) do
    position_step(game, "New game, initial position") <> "\n" <> describe_status(game)
  end

  def describe_last_move(%Game{} = game) do
    [last | earlier] = game.moves
    start = game.start || Game.new()
    before = replay_moves(Enum.reverse(earlier), start)

    unless Rules.legal_move?(before, last) do
      raise ArgumentError, "move #{length(game.moves)} is not legal in this position"
    end

    next = Rules.apply(before, last)
    ply = length(game.moves)
    move_step(last, ply, before, next) <> "\n" <> describe_status(next)
  end

  @doc """
  Print the last move of a game.
  """
  def print_last_move(game), do: IO.puts(describe_last_move(game))

  @doc """
  Describe the status of the game.
  """
  def describe_status(game) do
    status = Game.status(game)

    if status == :ongoing do
      "#{String.capitalize(to_string(game.side_to_move))} to move."
    else
      ending_step(game, nil)
    end
  end

  ## The parts of the game

  # A PGN game holds its moves in the order they were played and knows the
  # names of the players and the result. A game of our own holds its moves
  # newest first and is played back from the start. A game without moves is
  # a position and is described as it stands.
  defp parts(%PGN.Game{} = pgn) do
    %{
      moves: pgn.moves,
      result: pgn.result,
      headers: pgn.headers,
      start: game_start(pgn),
      label: "Initial position"
    }
  end

  defp parts(%Game{moves: []} = game) do
    %{moves: [], result: nil, headers: nil, start: game, label: "Position"}
  end

  defp parts(%Game{} = game) do
    %{
      moves: Enum.reverse(game.moves),
      result: nil,
      headers: nil,
      start: game.start || Game.new(),
      label: "Initial position"
    }
  end

  defp parts(moves) when is_list(moves) do
    %{moves: moves, result: nil, headers: nil, start: Game.new(), label: "Initial position"}
  end

  # The position the moves of a game are played from: the start of the final
  # game state, or the initial position when the game does not know.
  defp game_start(%PGN.Game{game: %Game{start: start}}) when not is_nil(start), do: start
  defp game_start(_input), do: Game.new()

  # Play the moves and collect a step for each of them.
  defp play(moves, start) do
    {steps, final} =
      moves
      |> Enum.with_index(1)
      |> Enum.reduce({[], start}, fn {move, ply}, {steps, state} ->
        unless Rules.legal_move?(state, move) do
          raise ArgumentError, "move #{ply} is not legal in this position"
        end

        next = Rules.apply(state, move)

        {[move_step(move, ply, state, next) | steps], next}
      end)

    {Enum.reverse(steps), final}
  end

  defp replay_moves([], state), do: state

  defp replay_moves([move | rest], state) do
    unless Rules.legal_move?(state, move) do
      raise ArgumentError, "move is not legal in this position"
    end

    replay_moves(rest, Rules.apply(state, move))
  end

  ## The steps

  # The names of the players, when the game knows them.
  defp header_step(nil), do: ""

  defp header_step(headers) do
    case {headers["White"], headers["Black"]} do
      {white, black} when is_binary(white) and is_binary(black) ->
        "#{white} (White) vs #{black} (Black)"

      _other ->
        ""
    end
  end

  # A position: its name, the board and the strength of the position.
  defp position_step(game, label) do
    "#{label}\n" <> Board.to_ascii(game.board) <> "\n" <> evaluation_line(game)
  end

  # A move: the notation, the move in words, the board it leads to and the
  # strength of that board.
  defp move_step(move, ply, before, next) do
    [
      "#{ply}. #{SAN.to_san(move, before)}",
      description(move, before, next),
      Board.to_ascii(next.board),
      evaluation_line(next)
    ]
    |> Enum.join("\n")
  end

  # The last sentence: how the game stopped.
  defp ending_step(game, result) do
    status = Game.status(game)

    check =
      if status != :checkmate and Rules.in_check?(game) do
        "#{game.side_to_move} is in check. "
      else
        ""
      end

    cond do
      status == :checkmate ->
        "#{game.side_to_move} is checkmated. #{String.capitalize(opponent(game.side_to_move))} wins#{result_suffix(result)}."

      status == :stalemate ->
        "#{game.side_to_move} is stalemated. The game is drawn#{result_suffix(result)}."

      status != :ongoing ->
        "#{draw_reason(status)}#{result_suffix(result)}."

      result == "1-0" ->
        check <> "White wins#{result_suffix(result)}."

      result == "0-1" ->
        check <> "Black wins#{result_suffix(result)}."

      result == "1/2-1/2" ->
        check <> "The game is drawn#{result_suffix(result)}."

      true ->
        check <> "The moves run out; the game is not over."
    end
  end

  # Why the game was drawn. The sentence is finished by the caller.
  defp draw_reason(:draw_fivefold_repetition),
    do: "The game is drawn by fivefold repetition"

  defp draw_reason(:draw_repetition),
    do: "The game is drawn by threefold repetition"

  defp draw_reason(:draw_seventy_five_moves),
    do: "The game is drawn by the seventy-five-move rule"

  defp draw_reason(:draw_fifty_moves),
    do: "The game is drawn by the fifty-move rule"

  defp draw_reason(:draw_insufficient_material),
    do: "The game is drawn: neither side has the material to mate"

  ## The move in words

  # The move and the details that only some moves have.
  defp description(move, before, next) do
    [base_clause(move, before) | details(move, before, next)]
    |> Enum.join(", ")
  end

  # What moved and where it went.
  defp base_clause({:castle, from, to}, before) do
    "#{color(before)} king castles #{castle_side(to)} from #{from} to #{to}"
  end

  defp base_clause(move, before) do
    {from, to} = shape(move)
    piece = Board.at(before.board, from)

    "#{color(before)} #{piece_name(piece)} from #{from} to #{to}"
  end

  # What else happened: the rook of a castle, a capture, a promotion, a pawn
  # that advanced two squares, a check.
  defp details(move, before, next) do
    rook_clause(move) ++
      capture_clause(move, before) ++
      promotion_clause(move) ++
      double_push_clause(move, before) ++
      check_clause(next)
  end

  # The rook of a castle stands on the other side of the king afterwards.
  defp rook_clause({:castle, from, to}) do
    rank = Position.rank(from)

    {rook_from, rook_to} =
      case Position.file(to) do
        :g -> {:h, :f}
        :c -> {:a, :d}
      end

    ["rook from #{Position.new(rook_from, rank)} to #{Position.new(rook_to, rank)}"]
  end

  defp rook_clause(_move), do: []

  # The piece that was taken. En passant is special: the pawn stands beside
  # the square the capturing pawn moves to.
  defp capture_clause({:en_passant, from, to}, before) do
    square = Position.new(Position.file(to), Position.rank(from))
    piece = Board.at(before.board, square)

    ["captures #{color_name(piece)} #{piece_name(piece)} on #{square} en passant"]
  end

  defp capture_clause(move, before) do
    case captured(move, before) do
      nil -> []
      {piece, square} -> ["captures #{color_name(piece)} #{piece_name(piece)} on #{square}"]
    end
  end

  defp captured({:castle, _from, _to}, _before), do: nil

  defp captured({:promotion, _from, to, _piece}, before),
    do: capture_at(before.board, to)

  defp captured({_from, to}, before), do: capture_at(before.board, to)

  # The piece on a square, if there is one.
  defp capture_at(board, square) do
    case Board.at(board, square) do
      nil -> nil
      piece -> {piece, square}
    end
  end

  # The piece a pawn became.
  defp promotion_clause({:promotion, _from, _to, piece}), do: ["promotes to #{piece_name(piece)}"]
  defp promotion_clause(_move), do: []

  # A pawn that advanced two squares.
  defp double_push_clause(move, before) do
    {from, to} = shape(move)
    piece = Board.at(before.board, from)

    if Piece.is_pawn?(piece) and abs(Position.rank(to) - Position.rank(from)) == 2 do
      ["advances two squares"]
    else
      []
    end
  end

  # The king that is in check after the move.
  defp check_clause(game) do
    cond do
      Rules.checkmate?(game) -> ["#{game.side_to_move} is checkmated"]
      Rules.in_check?(game) -> ["#{game.side_to_move} is in check"]
      true -> []
    end
  end

  ## The strength of a position

  # The score of the position, from White's point of view, and the terms it
  # is made of.
  defp evaluation_line(game) do
    terms =
      game
      |> Evaluation.breakdown()
      |> Enum.sort_by(fn {term, _value} -> term end)
      |> Enum.map_join(", ", fn {term, value} -> "#{term} #{pawns(value)}" end)

    "Evaluation: #{pawns(Evaluation.evaluate(game))} for White (#{terms})"
  end

  # A score in centipawns as signed pawns: 30 becomes "+0.30".
  defp pawns(centipawns) do
    sign = if centipawns < 0, do: "-", else: "+"
    value = abs(centipawns)
    cents = rem(value, 100)

    rest = if cents < 10, do: "0#{cents}", else: "#{cents}"

    "#{sign}#{div(value, 100)}.#{rest}"
  end

  ## Helpers

  # The origin and the destination of any move shape.
  defp shape({from, to}), do: {from, to}
  defp shape({:castle, from, to}), do: {from, to}
  defp shape({:en_passant, from, to}), do: {from, to}
  defp shape({:promotion, from, to, _piece}), do: {from, to}

  # The side of the board a castle goes to.
  defp castle_side(to) when to in [:g1, :g8], do: "king side"
  defp castle_side(_to), do: "queen side"

  # The name of a piece.
  defp piece_name(piece) do
    cond do
      Piece.is_pawn?(piece) -> "pawn"
      Piece.is_knight?(piece) -> "knight"
      Piece.is_bishop?(piece) -> "bishop"
      Piece.is_rook?(piece) -> "rook"
      Piece.is_queen?(piece) -> "queen"
      Piece.is_king?(piece) -> "king"
    end
  end

  # The color of a piece.
  defp color_name(piece) do
    if Piece.is_white?(piece), do: "white", else: "black"
  end

  # The color of the side to move.
  defp color(game), do: to_string(game.side_to_move)

  # The other color.
  defp opponent(:white), do: "black"
  defp opponent(:black), do: "white"

  # The result of the game, in brackets.
  defp result_suffix(nil), do: ""
  defp result_suffix("*"), do: ""
  defp result_suffix(result), do: " (#{result})"
end
