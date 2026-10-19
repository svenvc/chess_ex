# TODO

Derived from the current codebase (stubs, missing tests, README scope).
Ordered roughly by dependency.

## Core game logic

- [ ] `Chess.Move` (currently an empty stub): move representation, legal move
  generation per piece, check/checkmate/stalemate detection.
- [ ] `Chess.Game` (currently an empty stub): game state, turn switching,
  move application, castling / en passant / promotion, draw conditions.
- [ ] Board lookup: add a non-keyword accessor (e.g. `Board.at/2`) so callers
  don't reach for `Keyword.get/2` directly.

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

- [ ] Tests for `Chess.Move` and `Chess.Game` once implemented (currently no
  coverage for them; `test/chess_test.exs` is a dummy leftover from `mix new`).
- [x] Fill in `doc/RULES.md` — core moves done; draws section still open
  (see its TODO).
- [ ] README: usage examples (`iex -S mix`, `Board.print/1`) — no runnable
  example exists yet.
- [ ] Consider adding Credo/Dialyzer and CI; today `mix format` is the only
  quality gate.

## Housekeeping

- [ ] `.expert/` holds untracked agent logs — not part of the project.
