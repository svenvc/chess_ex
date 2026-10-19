# TODO

Derived from the current codebase (stubs, missing tests, README scope).
Ordered roughly by dependency.

## Core game logic

- [x] `Chess.Move` representation: `{from, to}` tuple with `new/2`, plus
  syntax-only `is_valid?/1`.
- [ ] `Chess.Move` legality: legal move generation per piece,
  check/checkmate/stalemate detection.
- [ ] `Chess.Game` (currently an empty stub): game state, turn switching,
  move application, castling / en passant / promotion, draw conditions.
- [x] Board lookup: `Board.at/2` added (returns `nil` for empty squares,
  raises on invalid positions); `to_ascii/1` now uses it.
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

- [ ] Tests for `Chess.Game` once implemented (it is the only module without
  coverage; `test/chess_test.exs` is a dummy leftover from `mix new`).
- [x] Fill in `doc/RULES.md` — core moves done; draws section still open
  (see its TODO).
- [ ] README: usage examples (`iex -S mix`, `Board.print/1`) — no runnable
  example exists yet.
- [ ] Consider adding Credo/Dialyzer and CI; today `mix format` is the only
  quality gate.

