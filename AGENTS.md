# AGENTS.md

Elixir/Mix library (`:chess_ex`, namespace `Chess`) for chess domain logic.
Single package, **zero dependencies**, no `config/`, no lockfile.

## Commands

- `mix test` — run all tests. Single file: `mix test test/chess/board_test.exs`
- `mix format --check-formatted` — the **only** quality gate. There is no CI,
  Credo, or Dialyzer. Run `mix format` before committing.
- `iex -S mix` — REPL; try `Chess.Board.initial() |> Chess.Board.print()`

Requires Elixir `~> 1.20` (`mix.exs`). `mix deps.get` is a no-op.

## Architecture

- `lib/chess.ex` — doc-only stub. Real code lives in `lib/chess/`.
- **Position** = atom from a fixed set of 64, e.g. `:a1` (`lib/chess/position.ex`).
  Never a tuple or string. `from_string/1` guards on `<<letter, digit>>` and
  raises `FunctionClauseError` on invalid input — errors-as-crashes is the
  established style; there are no `{:error, _}` returns anywhere.
- **Piece** = atom; **uppercase = white** (`:K :Q :R :B :N :P`), lowercase =
  black (`:k :q :r :b :n :p`). Knight is `:N`.
- **Board** = map of `position => piece`, only occupied squares
  (32 entries for `Board.initial/0`). Always read squares via `Board.at/2`; it
  accepts a map or a keyword list of `{position, piece}` tuples. Don't access
  the container directly from new code.
- `Chess.Move` — tagged-tuple value type, syntax-only validation via
  `Move.is_valid?/1`: `{from, to}` normal (incl. captures),
  `{:castle, from, to}` (king squares), `{:en_passant, from, to}`,
  `{:promotion, from, to, piece}`. Constructors: `new/2`, `castle/2`,
  `en_passant/2`, `promotion/3`.
- `Chess.Rules` — `attacked?/3`, `in_check?/1,2`, `pseudo_legal_moves/1`,
  `legal_moves/1`, `legal_move?/2`, `apply/2`, `checkmate?/1`, `stalemate?/1`.
  It defines `apply/2`, shadowing `Kernel.apply/2` via
  `import Kernel, except: [apply: 2]` — don't remove that line.
- `Chess.Game` — struct (`board`, `side_to_move`, `castling`, `en_passant`,
  `moves`); `Game.new/0` is the initial position. `moves` is newest-first.
  Castling rights and the en passant target live here because they **cannot**
  be derived from the board alone. Generation/applying go through `Chess.Rules`.
- `Chess.Evaluation` — static score in centipawns, White-relative (positive =
  White is better): `evaluate/1` (a game or a bare board), `evaluate/2` (score
  from `:white`/`:black`), `breakdown/1` (map of terms: `:material`,
  `:positional`). `evaluate/1` sums the breakdown, so new terms (mobility,
  pawn structure, king safety) are added by adding a key and a function.
- `Chess.SAN` — algebraic notation. `parse/2` turns a token into a
  `Chess.Move`, `to_san/2` turns a `Chess.Move` back into a token. Both
  resolve against `Rules.legal_moves/1`, so a token always names exactly one
  move; the `+`/`#` markers are checked against the engine (opt out with
  `validate_marker: false`). Raises `Chess.SAN.ParseError`.
- `Chess.PGN` — reading and writing PGN: `parse/2`, `parse_all/2`,
  `parse_file/2`, `to_pgn/1`. The reader is forgiving about the shape of the
  movetext (move numbers, comments, variations, NAGs) and strict about the
  moves: a move that is not legal raises `Chess.PGN.ParseError`. A game is a
  `Chess.PGN.Game` struct (`headers`, `moves`, `result`, `comments`, `game`).
  Its `moves` are **chronological**, the other way around than `Chess.Game`.
  Games that start from a FEN are not supported yet.
- `Chess.Narrator` — turns a game into readable text: `describe/1` returns it,
  `print/1` writes it out. Every ply is the SAN token, the move in words
  (with captures, promotions, castling and check), the board `Board.to_ascii/1`
  renders and `Evaluation.evaluate/1`; a closing sentence says how the game
  stopped. Accepts a `Chess.PGN.Game`, a `Chess.Game` (its newest-first
  `moves` are played back in order, a game without moves is described as it
  stands) or a plain chronological move list. A move that is not legal raises
  `ArgumentError`.
- Tests mirror `lib/` one-to-one under `test/chess/`. Plain `ExUnit.Case`, no
  fixtures or services. `test/chess_test.exs` is a dummy leftover from `mix new`.
  `rules_test.exs` includes perft from the initial position
  (20 / 400 / 8902 / 197281), which is the main regression net for generation,
  and replays every game of `test/fixtures/` ply by ply, holding the state of
  the game after every ply against a second derivation of the castling rights
  and the en passant target.
  `test/fixtures/` holds ten well known games in PGN plus one synthetic game
  that covers the special moves the famous games lack; the files are read by
  `pgn_test.exs`, the results of that suite stand in `test/fixtures/README.md`.

## Conventions that differ from defaults

- `Chess.Position.file/1`, `rank/1`, `file_index/1`, `is_black?/1`,
  `is_white?/1` are **hand-expanded exhaustive guard clauses**, not computed
  arithmetic. Match that style when extending (compile-time constants, no
  fallback clauses for known inputs).
- `Position.is_black?/1` and `is_white?/1` mean **square color**, not piece
  color. Piece color uses `Piece.is_black?/1` / `Piece.is_white?/1`.
- `String.to_atom/1` on the 64 bounded squares is fine; be careful if reusing
  that pattern for arbitrary future PGN/FEN input.
- Text that comes from a file is handled **byte by byte** (`IO.iodata_to_binary/1`,
  `List.to_string/1` is *not* the same thing): a tag value like `Łódź` has to
  survive the round trip. `Enum.join/1` on a list of char codes turns them
  into decimal numbers.

## Docs

- `doc/RULES.md` is the compact rule set to implement against (draws still
  marked TODO); `doc/UNICODE.md` lists the 12 piece glyphs. A board SVG lives
  in `doc/`.
- README's Wikipedia links (FEN, PGN, algebraic notation, UCI) are the
  roadmap for notations not yet implemented.

## Not part of the project

- `.expert/` is local tooling state: an Elixir code-indexing/LSP server
  (Expert/XPForge) keeps its build cache, indexes, and logs there and ignores
  itself via its own `.gitignore`. Don't delete, edit, or commit it.
