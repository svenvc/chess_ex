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
- `Chess.Game` and `Chess.Move` are **empty stubs** — the intended next modules.
- Tests mirror `lib/` one-to-one under `test/chess/`. Plain `ExUnit.Case`, no
  fixtures or services. `test/chess_test.exs` is a dummy leftover from `mix new`.

## Conventions that differ from defaults

- `Chess.Position.file/1`, `rank/1`, `file_index/1`, `is_black?/1`,
  `is_white?/1` are **hand-expanded exhaustive guard clauses**, not computed
  arithmetic. Match that style when extending (compile-time constants, no
  fallback clauses for known inputs).
- `Position.is_black?/1` and `is_white?/1` mean **square color**, not piece
  color. Piece color uses `Piece.is_black?/1` / `Piece.is_white?/1`.
- `String.to_atom/1` on the 64 bounded squares is fine; be careful if reusing
  that pattern for arbitrary future PGN/FEN input.

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
