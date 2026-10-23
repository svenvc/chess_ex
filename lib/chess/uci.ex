defmodule Chess.UCI do
  @moduledoc """
  The Universal Chess Interface (UCI) for `Chess.Search`.

  UCI is a line-based text protocol over the standard input and output of the
  engine process: the GUI writes commands to the engine's stdin and reads the
  engine's answers from its stdout. `Chess.UCI.CLI` drives this module on
  stdio; the functions here are free of IO and processes, so they can be
  tested on their own.

  The supported commands are the core of the protocol:

    * `uci` - identify the engine
    * `isready` - answer `readyok`
    * `ucinewgame` - start over from the initial position
    * `position startpos|fen ... [moves ...]` - set the position
    * `go` - search, with `depth`, `movetime`, the clock options and
      `infinite`
    * `stop` - stop a running search
    * `quit` - leave

  No options are advertised: in particular there is no `UCI_LimitStrength`
  or `UCI_Elo`, because the engine has no strength limiting.

  A move is written as its from and to square, followed by the lower case
  promotion piece when there is one: `e2e4`, `e1g1` for castling, `e5d6` for
  an en passant capture and `e7e8q` for a promotion. Castling and en passant
  are ordinary king and pawn moves in this notation; the legal moves of the
  position tell them apart.
  """

  alias Chess.{FEN, Game, Move, Position, Rules}

  @version Mix.Project.config()[:version]
  @name "ChessEx"
  @author "ChessEx contributors"

  @default_depth 3
  @max_auto_depth 4

  @mate_score 100_000
  @mate_threshold 90_000

  @promotions ["", "q", "r", "b", "n"]

  defstruct game: nil

  @type plan :: %{max_depth: pos_integer(), budget_ms: nil | pos_integer()}

  @doc """
  Return a new UCI session in the initial position.
  """
  def new, do: %__MODULE__{game: Game.new()}

  @doc """
  Handle one line of UCI input and return what has to happen next.

    * `{:reply, lines, state}` - write the lines and wait for the next command
    * `{:search, plan, state}` - start a search with `plan`
    * `{:stop, state}` - stop the running search
    * `{:quit, state}` - stop and exit
  """
  def handle(%__MODULE__{} = state, line) do
    case line |> String.trim() |> String.split(~r/\s+/, trim: true) do
      [] ->
        {:reply, [], state}

      ["uci"] ->
        {:reply, identity_lines(), state}

      ["isready"] ->
        {:reply, ["readyok"], state}

      ["ucinewgame"] ->
        {:reply, [], %{state | game: Game.new()}}

      ["position" | arguments] ->
        position(state, arguments)

      ["go" | arguments] ->
        {:search, plan_go(arguments, state.game.side_to_move), state}

      ["stop"] ->
        {:stop, state}

      ["quit"] ->
        {:quit, state}

      ["debug" | _arguments] ->
        {:reply, [], state}

      ["setoption" | _arguments] ->
        {:reply, [], state}

      [command | _arguments] ->
        {:reply, ["info string unknown command: #{command}"], state}
    end
  end

  @doc """
  Parse a UCI move in the given position.

  Returns `{:ok, move}` when the token names a legal move, `:error` otherwise.
  """
  def parse_move(%Game{} = game, <<from_file, from_rank, to_file, to_rank, rest::binary>>)
      when from_file in ?a..?h and from_rank in ?1..?8 and
             to_file in ?a..?h and to_rank in ?1..?8 do
    promotion = String.downcase(rest)

    if promotion in @promotions do
      from = Position.from_string(<<from_file, from_rank>>)
      to = Position.from_string(<<to_file, to_rank>>)
      find_move(game, from, to, promotion)
    else
      :error
    end
  end

  def parse_move(_game, _token), do: :error

  @doc """
  Write a move in UCI notation.
  """
  def to_uci(move) do
    Atom.to_string(Move.from(move)) <>
      Atom.to_string(Move.to(move)) <> promotion_suffix(move)
  end

  @doc """
  Turn the arguments of a `go` command into a search plan.

  `max_depth` is the deepest iteration to run and `budget_ms` is a soft time
  budget in milliseconds, or `nil` when there is no time limit.

  An explicit `depth` wins over a time limit. Otherwise `movetime` is used,
  then the clock of the side to move, then the default depth.
  """
  def plan_go(arguments, side_to_move) do
    options = parse_go(arguments, %{})

    cond do
      depth = options[:depth] ->
        %{max_depth: max(depth, 1), budget_ms: nil}

      options[:infinite] ->
        %{max_depth: @max_auto_depth, budget_ms: nil}

      movetime = options[:movetime] ->
        %{max_depth: @max_auto_depth, budget_ms: max(movetime, 10)}

      time = options[clock_key(side_to_move, :time)] ->
        increment = options[clock_key(side_to_move, :increment)] || 0

        %{
          max_depth: @max_auto_depth,
          budget_ms: clock_budget(time, increment, options[:movestogo])
        }

      true ->
        %{max_depth: @default_depth, budget_ms: nil}
    end
  end

  @doc """
  Format a search score the way an `info` line expects it.

  Ordinary scores are centipawns from the point of view of the side to move.
  Scores near mate are written as a distance in moves, positive when the side
  to move mates and negative when it is mated.
  """
  def format_score(score) when score >= @mate_threshold,
    do: "mate #{mate_moves(@mate_score - score)}"

  def format_score(score) when score <= -@mate_threshold,
    do: "mate -#{mate_moves(@mate_score + score)}"

  def format_score(score), do: "cp #{score}"

  @doc """
  Build an `info` line for one completed search iteration.
  """
  def info_line(depth, score, elapsed_ms, move) do
    "info depth #{depth} score #{format_score(score)} time #{elapsed_ms} pv #{to_uci(move)}"
  end

  ## Commands

  defp identity_lines do
    # The version is baked in at compile time, so the escript reports the
    # version of the project it was built from.
    [
      "id name #{@name} #{@version}",
      "id author #{@author}",
      "uciok"
    ]
  end

  # The position command is atomic: the new game is only stored once both the
  # position and the whole move list have been read successfully.
  defp position(state, arguments) do
    {position_arguments, moves} = split_moves(arguments)

    with {:ok, game} <- build_position(position_arguments),
         {:ok, game} <- play_moves(game, moves) do
      {:reply, [], %{state | game: game}}
    else
      {:error, message} -> {:reply, ["info string #{message}"], state}
    end
  end

  # Everything before the "moves" keyword describes the position; everything
  # behind it is the move list.
  defp split_moves(arguments) do
    case Enum.split_while(arguments, &(&1 != "moves")) do
      {position, ["moves" | moves]} -> {position, moves}
      {position, []} -> {position, []}
    end
  end

  # A start position needs no parsing, while a FEN record can be rejected by
  # the reader. Only the record's own error is turned into a UCI reply.
  defp build_position(["startpos"]), do: {:ok, Game.new()}

  defp build_position(["fen" | fields]) do
    try do
      {:ok, FEN.parse(Enum.join(fields, " "))}
    rescue
      _error in Chess.FEN.ParseError -> {:error, "invalid FEN"}
    end
  end

  defp build_position(_arguments), do: {:error, "position needs startpos or fen"}

  # Play the UCI move list from the given position. Every token is first
  # resolved against the legal moves, so Rules.apply/2 only sees legal moves.
  defp play_moves(game, moves) do
    Enum.reduce_while(moves, {:ok, game}, fn token, {:ok, game} ->
      case parse_move(game, token) do
        {:ok, move} -> {:cont, {:ok, Rules.apply(game, move)}}
        :error -> {:halt, {:error, "illegal move: #{token}"}}
      end
    end)
  end

  ## Move conversion

  # Resolve the from square, to square and promotion against the legal moves.
  # This is what tells an ordinary king move from castling and an ordinary
  # pawn move from an en passant capture.
  defp find_move(game, from, to, promotion) do
    Enum.find_value(Rules.legal_moves(game), :error, fn move ->
      if Move.from(move) == from and Move.to(move) == to and promotion_of(move) == promotion do
        {:ok, move}
      else
        false
      end
    end)
  end

  # The promotion piece of a move as a lower case UCI suffix, or "" for moves
  # that do not promote.
  defp promotion_of(move) do
    case Move.promotion_piece(move) do
      nil -> ""
      piece -> piece |> Atom.to_string() |> String.downcase()
    end
  end

  # The suffix written after the destination square; UCI uses lower case
  # letters even for White's promotion pieces.
  defp promotion_suffix(move) do
    case Move.promotion_piece(move) do
      nil -> ""
      piece -> piece |> Atom.to_string() |> String.downcase()
    end
  end

  ## Go options

  # The options with an integer value. Unknown options are skipped; their
  # values are skipped as unknown tokens as well.
  defp parse_go([], options), do: options

  defp parse_go([key, value | rest], options)
       when key in ["depth", "movetime", "wtime", "btime", "winc", "binc", "movestogo"] do
    case Integer.parse(value) do
      {number, ""} -> parse_go(rest, Map.put(options, String.to_atom(key), number))
      _error -> parse_go(rest, options)
    end
  end

  defp parse_go(["infinite" | rest], options) do
    parse_go(rest, Map.put(options, :infinite, true))
  end

  defp parse_go([_unknown | rest], options), do: parse_go(rest, options)

  # Map the side to move and the kind of clock value to the UCI option name.
  defp clock_key(:white, :time), do: :wtime
  defp clock_key(:black, :time), do: :btime
  defp clock_key(:white, :increment), do: :winc
  defp clock_key(:black, :increment), do: :binc

  # Spend the time of a move on the clock, assuming a game of about thirty
  # moves when the GUI does not say how many moves are left. Keep a little
  # time in reserve and never spend less than a minimal thought.
  defp clock_budget(time, increment, moves_to_go) do
    moves = max(moves_to_go || 30, 1)
    budget = div(max(time, 0), moves) + div(max(increment, 0), 2)
    limit = max(time - 100, 50)

    budget
    |> max(50)
    |> min(limit)
  end

  ## Scores

  # Convert a mate score in plies to the number of moves UCI reports.
  defp mate_moves(plies), do: div(plies + 1, 2)
end
