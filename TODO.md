# TODO

Derived from the current codebase (stubs, missing tests, README scope).
Ordered roughly by dependency.

## Core game logic

- [x] `Chess.Move` representation: tagged tuples for normal, castling,
  en passant and promotion moves, with constructors and syntax-only
  `is_valid?/1`.
- [x] `Chess.Rules`: legal move generation per piece and per side, attack
  detection, check/checkmate/stalemate, move application (incl. special moves).
  Validated by perft (20 / 400 / 8902 / 197281).
- [x] `Chess.Game` state struct: board, side to move, castling rights,
  en passant target, move history.
- [ ] `Chess.Game` orchestration: draw conditions (threefold repetition,
  fifty-move rule, insufficient material) and game status/winner.
- [x] Board lookup: `Board.at/2` added (returns `nil` for empty squares,
  raises on invalid positions); `to_ascii/1` now uses it.
- [x] Board primitives: `pieces/2`, `king/2`, `put/3`, `remove/2`, `move/3`.
- [x] Board representation: canonical form is now a `%{position => piece}` map;
  `at/2` also accepts keyword lists at the API boundary.

## Notations (README scope, nothing implemented yet)

- [ ] FEN parsing/serialization (references in README).
- [ ] Algebraic (SAN) and long algebraic notation.
- [ ] PGN reading/writing.
- [ ] Unicode piece rendering — glyphs already documented in `doc/UNICODE.md`;
  `Board.to_ascii/1` only prints letters today.

## Engine (README scope, nothing implemented yet)

- [ ] Search + evaluation.
- [ ] UCI interface.

## Tests & docs

- [x] Tests for all modules, including perft from the initial position
  (`test/chess_test.exs` is still a dummy leftover from `mix new`).
- [x] Fill in `doc/RULES.md` — core moves done; draws section still open
  (see its TODO).
- [ ] README: usage examples (`iex -S mix`, `Board.print/1`) — no runnable
  example exists yet.
- [ ] Consider adding Credo/Dialyzer and CI; today `mix format` is the only
  quality gate.

