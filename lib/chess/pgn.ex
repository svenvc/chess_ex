defmodule Chess.PGN do
  @moduledoc """
  Reading and writing PGN (Portable Game Notation).

  A PGN document is a sequence of games. Each game starts with tag pairs, as
  in `[Event "Paris"]`, and continues with the moves in algebraic notation,
  ended by the result of the game.

  `parse/2` reads a document with a single game, `parse_all/2` reads all games
  of a document. `to_pgn/1` writes a game back as PGN text.

  The reader is forgiving about the shape of the movetext, as real world
  files are: move numbers may be missing, glued to the move or written for
  both sides, and comments may hold anything at all. It is strict about the
  moves themselves - a move that is not legal in the position it is played in
  is an error, not a warning.
  """

  alias Chess.{Rules, SAN}
  alias Chess.PGN.Game
  alias Chess.PGN.ParseError

  @results ~w(1-0 0-1 1/2-1/2 *)
  @castling ~w(O-O O-O-O 0-0 0-0-0)

  @roster ~w(Event Site Date Round White Black Result)

  @doc """
  Read a PGN document that holds a single game.

  Raises `Chess.PGN.ParseError` when the document holds no game or more than
  one. The options are passed on to `Chess.SAN.parse/3`.
  """
  def parse(text, opts \\ []) do
    case parse_all(text, opts) do
      [game] ->
        game

      [] ->
        raise ParseError, "the document holds no game"

      games ->
        raise ParseError, "the document holds #{length(games)} games, not one"
    end
  end

  @doc """
  Read all games of a PGN document.

  The options are passed on to `Chess.SAN.parse/3`.
  """
  def parse_all(text, opts \\ []) do
    text
    |> tokenize()
    |> split_games()
    |> Enum.map(&build_game(&1, opts))
  end

  @doc """
  Read a single game from a PGN file.

  The options are passed on to `Chess.SAN.parse/3`.
  """
  def parse_file(path, opts \\ []) do
    path
    |> File.read!()
    |> parse(opts)
  end

  @doc """
  Write a game as PGN text.

  The tag pairs of the seven tag roster are written first, the other tag
  pairs follow in alphabetical order. The moves are written in algebraic
  notation, wrapped at 80 columns, and the result ends the game.
  """
  def to_pgn(%Game{} = game) do
    headers = write_headers(game)
    movetext = write_movetext(game)

    Enum.join([headers, movetext], "\n\n") <> "\n"
  end

  ## Reading

  # The tokens of a document:
  #
  #   {:tag, name, value}     - a tag pair, as in [Event "Paris"]
  #   {:move_number, number}  - the number of a move, as in 1. or 1...
  #   {:san, token}           - a move in algebraic notation
  #   {:comment, text}        - a comment, without its braces
  #   {:nag, number}          - a numeric annotation glyph
  #   {:variation, tokens}    - a recursive annotation, in parentheses
  #   {:result, result}       - the result of the game
  defp tokenize(text), do: scan(text, [])

  defp scan("", acc), do: Enum.reverse(acc)

  defp scan(<<char, rest::binary>>, acc) do
    cond do
      char in [?\s, ?\n, ?\r, ?\t] -> scan(rest, acc)
      char == ?[ -> scan_tag(rest, acc)
      char == ?{ -> scan_comment(rest, acc)
      char == ?; -> scan_line_comment(rest, acc)
      char == ?( -> scan_variation(rest, acc)
      char == ?$ -> scan_nag(rest, acc)
      true -> scan_word(rest, char, acc)
    end
  end

  # A tag pair ends with the first "]"; the value may hold escaped quotes.
  defp scan_tag(text, acc) do
    case String.split(text, "]", parts: 2) do
      [body, rest] ->
        case parse_tag(body) do
          {name, value} -> scan(rest, [{:tag, name, value} | acc])
          :error -> raise ParseError, "invalid tag pair: [#{body}]"
        end

      _text ->
        raise ParseError, "unterminated tag pair"
    end
  end

  defp parse_tag(body) do
    case String.split(body, " ", parts: 2) do
      [name, quoted] ->
        case read_value(quoted) do
          {:ok, value} -> {name, value}
          :error -> :error
        end

      _body ->
        :error
    end
  end

  # A tag value is a quoted string; a quote inside it is escaped with a
  # backslash.
  defp read_value(<<?", rest::binary>>) do
    case unescape(rest, []) do
      {:ok, value, ""} -> {:ok, value}
      _other -> :error
    end
  end

  defp read_value(_quoted), do: :error

  defp unescape(<<?\\, char, rest::binary>>, acc),
    do: unescape(rest, [unescaped(char) | acc])

  defp unescape(<<?", rest::binary>>, acc),
    do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp unescape(<<char, rest::binary>>, acc), do: unescape(rest, [<<char>> | acc])
  defp unescape("", _acc), do: :error

  defp unescaped(?"), do: "\""
  defp unescaped(?\\), do: "\\"
  defp unescaped(char), do: <<char>>

  # A comment ends with the first "}" and may span several lines.
  defp scan_comment(text, acc) do
    case String.split(text, "}", parts: 2) do
      [body, rest] -> scan(rest, [{:comment, body} | acc])
      _text -> raise ParseError, "unterminated comment"
    end
  end

  # A comment behind a semicolon ends with the line.
  defp scan_line_comment(text, acc) do
    {body, rest} =
      case String.split(text, "\n", parts: 2) do
        [body, rest] -> {body, rest}
        [body] -> {body, ""}
      end

    scan(rest, [{:comment, String.trim(body)} | acc])
  end

  # A recursive annotation holds an alternative line. It is read, so that it
  # does not disturb the scan, but its moves are not part of the game.
  defp scan_variation(text, acc) do
    {inner, rest} = take_variation(text, 1, [])

    scan(rest, [{:variation, tokenize(inner)} | acc])
  end

  defp take_variation(text, depth, acc) do
    case text do
      "" ->
        raise ParseError, "unterminated variation"

      <<"{", rest::binary>> ->
        case String.split(rest, "}", parts: 2) do
          [comment, rest] -> take_variation(rest, depth, ["{" <> comment <> "}" | acc])
          _text -> raise ParseError, "unterminated comment"
        end

      <<";", rest::binary>> ->
        {line, rest} = String.split(rest, "\n", parts: 2)
        take_variation(rest, depth, [";" <> line | acc])

      <<"(", rest::binary>> ->
        take_variation(rest, depth + 1, ["(" | acc])

      <<")", rest::binary>> ->
        if depth == 1 do
          {acc |> Enum.reverse() |> Enum.join(), rest}
        else
          take_variation(rest, depth - 1, [")" | acc])
        end

      <<char, rest::binary>> ->
        take_variation(rest, depth, [<<char>> | acc])
    end
  end

  # An annotation glyph is a dollar sign followed by a number.
  defp scan_nag(text, acc) do
    case Regex.run(~r/^(\d+)/, text) do
      [_, number] ->
        rest = String.slice(text, String.length(number)..-1//1)
        scan(rest, [{:nag, String.to_integer(number)} | acc])

      _text ->
        raise ParseError, "invalid annotation glyph"
    end
  end

  # A word is a move number, a move or the result of the game.
  defp scan_word(text, first, acc) do
    {word, rest} = take_word(text, [first])

    cond do
      word in @results ->
        scan(rest, [{:result, word} | acc])

      word in @castling ->
        scan(rest, [{:san, word} | acc])

      true ->
        case Regex.run(~r/^(\d+)\.*$/, word) do
          [_, number] ->
            scan(rest, [{:move_number, String.to_integer(number)} | acc])

          _word ->
            case Regex.run(~r/^(\d+)\.*(.+)$/, word) do
              [_, number, san] ->
                acc = [{:move_number, String.to_integer(number)} | acc]
                scan(rest, [{:san, san} | acc])

              _word ->
                scan(rest, [{:san, word} | acc])
            end
        end
    end
  end

  defp take_word(text, acc) do
    case text do
      "" ->
        {acc |> Enum.reverse() |> IO.iodata_to_binary(), ""}

      <<char, rest::binary>> ->
        if char in [?\s, ?\n, ?\r, ?\t, ?[, ?], ?{, ?}, ?(, ?), ?$, ?;] do
          {acc |> Enum.reverse() |> IO.iodata_to_binary(), text}
        else
          take_word(rest, [<<char>> | acc])
        end
    end
  end

  # A game starts with its tag pairs and ends where the next game starts.
  defp split_games(tokens) do
    {games, current} =
      Enum.reduce(tokens, {[], %{tags: [], movetext: []}}, fn
        {:tag, name, value}, {games, current} ->
          if current.movetext == [] do
            {games, %{current | tags: current.tags ++ [{name, value}]}}
          else
            {games ++ [current], %{tags: [{name, value}], movetext: []}}
          end

        token, {games, current} ->
          {games, %{current | movetext: current.movetext ++ [token]}}
      end)

    if current.tags == [] and current.movetext == [] do
      games
    else
      games ++ [current]
    end
  end

  defp build_game(%{tags: tags, movetext: movetext}, opts) do
    headers = Map.new(tags)

    if Map.has_key?(headers, "FEN") do
      raise ParseError, "games that start from a FEN are not supported yet"
    end

    {moves, comments, result, game} = play(movetext, headers, opts)

    %Game{
      headers: headers,
      moves: moves,
      result: result,
      comments: comments,
      game: game
    }
  end

  # Play the moves of the game and collect what the document says about it.
  defp play(movetext, headers, opts) do
    {moves, _ply, comments, result, game} =
      Enum.reduce(movetext, {[], 0, %{}, nil, Chess.Game.new()}, fn token, acc ->
        {moves, ply, comments, result, game} = acc

        case token do
          {:move_number, number} ->
            validate_move_number!(number, ply)
            acc

          {:san, token} ->
            move = parse_move(token, game, ply, opts)
            {[move | moves], ply + 1, comments, result, Rules.apply(game, move)}

          {:comment, text} ->
            comments = Map.update(comments, ply, [text], &(&1 ++ [text]))
            {moves, ply, comments, result, game}

          {:nag, _number} ->
            acc

          {:variation, _tokens} ->
            acc

          {:result, result} ->
            {moves, ply, comments, result, game}
        end
      end)

    {moves |> Enum.reverse(), comments, result || headers["Result"], game}
  end

  # The number of a move is the number of the move of the side that starts.
  defp validate_move_number!(number, ply) do
    expected = div(ply, 2) + 1

    if number != expected do
      raise ParseError, "expected move #{expected}, found #{number}"
    end
  end

  # A move that cannot be played is a fault of the document, not of the
  # notation, and is reported as such.
  defp parse_move(token, game, ply, opts) do
    SAN.parse(token, game, opts)
  rescue
    error in SAN.ParseError ->
      raise ParseError, "ply #{ply + 1}: #{Exception.message(error)}"
  end

  ## Writing

  defp write_headers(game) do
    result = game.result || game.headers["Result"] || "*"

    values =
      %{
        "Event" => game.headers["Event"] || "?",
        "Site" => game.headers["Site"] || "?",
        "Date" => game.headers["Date"] || "????.??.??",
        "Round" => game.headers["Round"] || "?",
        "White" => game.headers["White"] || "?",
        "Black" => game.headers["Black"] || "?",
        "Result" => result
      }

    others =
      game.headers
      |> Map.drop(@roster)
      |> Enum.sort_by(fn {name, _value} -> name end)

    @roster
    |> Enum.map(&{&1, values[&1]})
    |> Kernel.++(others)
    |> Enum.map_join("\n", fn {name, value} -> ~s([#{name} "#{escape(value)}"]) end)
  end

  # A quote inside a tag value is escaped with a backslash.
  defp escape(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp write_movetext(game) do
    {tokens, _state} =
      game.moves
      |> Enum.with_index()
      |> Enum.reduce({[], Chess.Game.new()}, fn {move, ply}, {tokens, state} ->
        tokens = tokens ++ comment_tokens(game.comments, ply)
        san = write_san(move, state)
        tokens = if rem(ply, 2) == 0, do: tokens ++ ["#{div(ply, 2) + 1}."], else: tokens

        {tokens ++ [san], Rules.apply(state, move)}
      end)

    tokens = tokens ++ comment_tokens(game.comments, length(game.moves))

    {lines, last} = wrap(tokens, 80)
    lines = if last == "", do: lines, else: lines ++ [last]

    result = game.result || game.headers["Result"] || "*"

    Enum.join(lines ++ [result], "\n")
  end

  defp comment_tokens(comments, ply) do
    comments
    |> Map.get(ply, [])
    |> Enum.map(fn text -> "{" <> text <> "}" end)
  end

  # A move that cannot be played is a fault of the game, not of the notation,
  # and is reported as such.
  defp write_san(move, state) do
    SAN.to_san(move, state)
  rescue
    error in SAN.ParseError ->
      raise ParseError, Exception.message(error)
  end

  # Break the tokens into lines of at most the given width.
  defp wrap(tokens, width) do
    Enum.reduce(tokens, {[], ""}, fn token, {lines, line} ->
      candidate = if line == "", do: token, else: line <> " " <> token

      if String.length(candidate) > width and line != "" do
        {[line | lines], token}
      else
        {lines, candidate}
      end
    end)
    |> then(fn {lines, last} -> {Enum.reverse(lines), last} end)
  end
end
