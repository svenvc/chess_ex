# TODO

Derived from the current codebase (stubs, missing tests, README scope).
Ordered roughly by dependency.

## Core game logic

- [x] `Chess.Move` representation: tagged tuples for normal, castling,
  en passant and promotion moves, with constructors and syntax-only
  `Move.valid?/1`.
- [x] `Chess.Rules`: legal move generation per piece and per side, attack
  detection, check/checkmate/stalemate, move application (incl. special moves).
  Validated by perft (20 / 400 / 8902 / 197281).
- [x] `Chess.Game` state struct: board, side to move, castling rights,
  en passant target, move history, the two counters of a FEN record and the
  position the game started from.
- [x] `Chess.Game` orchestration: draw conditions (threefold repetition,
  fifty-move rule, insufficient material) and game status/winner.
  `Game.status/1` names the strongest rule that applies, `Game.over?/1` and
  `Game.winner/1` answer the two questions that follow from it. The fivefold
  repetition and the seventy-five-move rule are in there as well.
- [x] Board lookup: `Board.at/2` added (returns `nil` for empty squares,
  raises on invalid positions); `to_ascii/1` now uses it.
- [x] Board primitives: `pieces/2`, `king/2`, `put/3`, `remove/2`, `move/3`.
- [x] Board representation: canonical form is now a `%{position => piece}` map;
  `at/2` also accepts keyword lists at the API boundary.

## Notations

- [x] FEN parsing/serialization: `Chess.FEN` reads a record into a
  `Chess.Game` and writes one back.
- [x] Algebraic notation: `Chess.SAN` reads a SAN token and writes one,
  resolved against the legal moves of the position. Long algebraic notation is
  still open.
- [x] PGN reading/writing: `Chess.PGN` reads a document of games
  (`parse/2`, `parse_all/2`, `parse_file/2`) and writes a game back
  (`to_pgn/1`). Games that start from a FEN are read and written with the
  tag pairs `SetUp` and `FEN`.
- [x] Game description: `Chess.Narrator` writes a game out ply by ply — the
  SAN token, the move in words, the board and the evaluated strength — and
  ends with how the game stopped. `describe_last_move/1`, `print_last_move/1`,
  `describe_status/1` added for REPL use.
- [x] REPL helpers: `Chess.Repl` with `new/0`, `move/1`, `move/2` returning
  `{:ok, game}`/`{:error, reason}` and printing narrator-style steps; compact
  game inspection via `:chess_repl_compact` flag with `Chess.Repl.clear/0`.
- [ ] Unicode piece rendering — glyphs already documented in `doc/UNICODE.md`;
  `Board.to_ascii/1` only prints letters today.

## Engine (README scope)

- [x] Static evaluation: `Chess.Evaluation` scores a position in centipawns
  (material + piece-square tables), always from White's point of view.
  `breakdown/1` exposes the individual terms, so mobility, pawn structure and
  king safety can be added later.
- [x] Basic engine: `Chess.Engine` selects moves with random or 1-ply
  evaluation-based strategies and plays them via `play/2`.
- [ ] Search: depth-limited search on top of the evaluation.
- [ ] UCI interface.

## Tests & docs

- [x] Tests for all modules, including perft from the initial position
  (`test/chess_test.exs` is still a dummy leftover from `mix new`).
- [x] PGN regression suite: ten well known games and one synthetic game in
  `test/fixtures/`, read and written back by the tests; the results stand in
  `test/fixtures/README.md`.
- [x] Corpus replay: every game of `test/fixtures/` is played again ply by ply
  in `rules_test.exs`, and the state of the game after every ply is held
  against a second derivation of the castling rights, the en passant target
  and the two counters of a FEN record.
- [x] Fill in `doc/RULES.md` — core moves and draws done.
- [x] README: usage examples (`iex -S mix`, `Board.print/1`, reading a PGN).
- [ ] Consider adding Credo/Dialyzer and CI; today `mix format` is the only
  quality gate.

## Performance notes

- Perft depth 4 dominates the test suite: ~1.2s of ~1.9s total (~60%),
  ~5.9 µs/node. Depth 3 takes ~50ms (~4.4 µs/node).
- The corpus replay plays 580 plies of the eleven games and costs ~0.1s.
- `Rules.legal_moves/1` from the initial position takes ~98 µs: ~15 µs of
  generation and ~50 µs of check filtering (~20 × `in_check?`, ~2.45 µs each).
  `Rules.apply/2` is only ~0.47 µs, so avoiding the `Game` struct would save
  little.
- The draw rules are not on the path of `Rules.apply/2`, so perft is unaffected.
  `Game.status/1` costs one move generation (~120 µs) plus the replay of the
  game for the repetition rules: `Rules.repetition_count/1` works the moves
  again and takes ~0.5 µs per ply (33 plies ≈ 16 µs). A game that has to know
  whether it repeats therefore keeps its whole history around.
- Conclusion: don't optimize the engine yet; readability matters more. Real wins
  need precomputed neighbour/ray tables, board-only legality, king tracking or
  bitboards — engine-level design work that should wait for an actual search
  engine and benchmarking.
- [ ] If suite time matters later: keep perft 3 in the default run and tag
  depth 4 `@tag :slow`, excluded in `test_helper.exs`, run with
  `mix test --include slow`.

