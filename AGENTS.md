# AGENTS.md

Elixir/Mix library (`:chess_ex`, namespace `Chess`) for chess domain logic.
Single package, **zero dependencies**, no `config/`, no lockfile.

## Commands

- `mix test` — run all tests. Single file: `mix test test/chess/board_test.exs`
- `mix format --check-formatted` — the **only** quality gate. There is no CI,
  Credo, or Dialyzer. Run `mix format` before committing.
- `mix escript.build` — build the UCI engine executable `./chess_ex`.
- `iex -S mix` — REPL; try `Chess.Board.initial() |> Chess.Board.print()`

Requires Elixir `~> 1.20` (`mix.exs`). `mix deps.get` is a no-op.

## Architecture

- `lib/chess.ex` — doc-only stub. Real code lives in `lib/chess/`.
- **Position** = atom from a fixed set of 64, e.g. `:a1` (`lib/chess/position.ex`).
  Never a tuple or string. `from_string/1` guards on `<<letter, digit>>` and
  raises `FunctionClauseError` on invalid input — errors-as-crashes is the
  established style; there are no `{:error, _}` returns anywhere. `at/2`,
  `offset/3` and `rotate/1` keep board arithmetic off the caller.
- **Piece** = atom; **uppercase = white** (`:K :Q :R :B :N :P`), lowercase =
  black (`:k :q :r :b :n :p`). Knight is `:N`. `Piece.type/1` and
  `Piece.color/1` name the two facets; `Piece.of_color?/2` compares a color.
  `Piece.pawn_direction/1`, `start_rank/1` and `promotion_rank/1` are the
  color-dependent rank facts of a pawn.
- **Color** = `:white` or `:black`; `Chess.Color.opponent/1` is the other one.
- **Castling** = `Chess.Castling`, which names the rights (`{color, side}`),
  the king and rook squares, the empty and safe paths, and the FEN letters.
- **Board** = map of `position => piece`, only occupied squares
  (32 entries for `Board.initial/0`). Always read squares via `Board.at/2`; it
  accepts a map or a keyword list of `{position, piece}` tuples. Don't access
  the container directly from new code. `Board.rows/1` is the rank-by-rank
  view that `to_ascii/1` and FEN writing share.
- `Chess.Move` — tagged-tuple value type, syntax-only validation via
  `Move.valid?/1`: `{from, to}` normal (incl. captures),
  `{:castle, from, to}` (king squares), `{:en_passant, from, to}`,
  `{:promotion, from, to, piece}`. Constructors: `new/2`, `castle/2`,
  `en_passant/2`, `promotion/3`. Shape helpers: `from/1`, `to/1`,
  `promotion_piece/1`, `capture_square/1`, `castle_side/1`,
  `skipped_square/1`, `promotions/1`.
- `Chess.Rules` — `attacked?/3`, `in_check?/1,2`, `pseudo_legal_moves/1`,
  `legal_moves/1`, `legal_move?/2`, `apply/2`, `checkmate?/1`, `stalemate?/1`,
  `check_status/1`.
  The draw rules live here too: `insufficient_material?/1`,
  `fifty_move_rule?/1`, `seventy_five_move_rule?/1`, `repetition_count/1`,
  `threefold_repetition?/1`, `fivefold_repetition?/1`.
  It defines `apply/2`, shadowing `Kernel.apply/2` via
  `import Kernel, except: [apply: 2]` — don't remove that line.
- `Chess.Game` — struct (`board`, `side_to_move`, `castling`, `en_passant`,
  `halfmove_clock`, `fullmove_number`, `moves`, `start`); `Game.new/0` is the
  initial position. `moves` is newest-first. `start` is the position the game
  began at (`nil` = the initial position); `Chess.FEN.parse/1` sets it, so
  that the moves of a game can be played back from there. Castling rights, the
  en passant target and the two counters live here because they **cannot**
  be derived from the board alone. Generation/applying go through `Chess.Rules`.
  `Game.start_position/1`, `Game.moves_in_order/1` and `Game.replay/1,2` are
  the shared way to work the history again.
  `Game.status/1` names how the game stands (`:ongoing`, `:checkmate`,
  `:stalemate` or one of the draws), `Game.over?/1` and `Game.winner/1` answer
  the two questions that follow from it.
- `Chess.Engine` — move selection/play: `play/2` applies a chosen move and
  returns `{:ok, game, move}` or `{:error, status}` when terminal; strategies
  `:best` (1-ply via `Evaluation.evaluate/1`, random among ties by default),
  `:random` (uniform from `Rules.legal_moves/1`) and `:search` (delegates to
  `Chess.Search`, takes `:depth` in plies, default 3). `random_move/1`,
  `best_move/1,2` and `search_move/1,2` return `{:ok, move}` or
  `{:error, status}`.
- `Chess.Search` — depth-limited search for the best move: negamax (one
  sign-flipping minimax instead of separate max/min functions) with
  alpha-beta pruning, MVV-LVA capture ordering (Most Valuable Victim, Least
  Valuable Attacker) and mate scores that prefer faster mates. Returns
  `{:ok, move, score}` in centipawns from the side to move. No opening book,
  no endgame tablebase, no transposition table.
- `Chess.Evaluation` — static score in centipawns, White-relative (positive =
  White is better): `evaluate/1` (a game or a bare board), `evaluate/2` (score
  from `:white`/`:black`), `breakdown/1` (map of terms: `:material`,
  `:positional`), `piece_value/1` (the material value of one piece, also used
  by the search's move ordering). `evaluate/1` sums the breakdown, so new
  terms (mobility, pawn structure, king safety) are added by adding a key and
  a function.
- `Chess.SAN` — algebraic notation. `parse/2` turns a token into a
  `Chess.Move`, `to_san/2` turns a `Chess.Move` back into a token. Both
  resolve against `Rules.legal_moves/1`, so a token always names exactly one
  move; the `+`/`#` markers are checked against the engine (opt out with
  `validate_marker: false`). Raises `Chess.SAN.ParseError`.
- `Chess.FEN` — the FEN record. `parse/1` reads a record into a
  `Chess.Game`, `to_fen/1` writes a game back. The reader is strict about the
  shape of a record and forgiving about the position it describes; the writer
  is canonical (the castling rights come out as `KQkq`). Raises
  `Chess.FEN.ParseError`.
- `Chess.PGN` — reading and writing PGN: `parse/2`, `parse_all/2`,
  `parse_file/2`, `to_pgn/1`. The reader is forgiving about the shape of the
  movetext (move numbers, comments, variations, NAGs) and strict about the
  moves: a move that is not legal raises `Chess.PGN.ParseError`. A game is a
  `Chess.PGN.Game` struct (`headers`, `moves`, `result`, `comments`, `game`).
  Its `moves` are **chronological**, the other way around than `Chess.Game`.
  A game that starts from a FEN holds the position in the tag pair `FEN`; the
  moves are then read and written against that position.
- `Chess.Narrator` — turns a game into readable text: `describe/1` returns it,
  `print/1` writes it out. Every ply is the SAN token, the move in words
  (with captures, promotions, castling and check), the board `Board.to_ascii/1`
  renders and `Evaluation.evaluate/1`; a closing sentence says how the game
  stopped, taken from `Game.status/1`. Accepts a `Chess.PGN.Game`, a
  `Chess.Game` (its newest-first `moves` are played back in order, a game
  without moves is described as it stands) or a plain chronological move list.
  A move that is not legal raises `ArgumentError`. `describe_last_move/1`,
  `print_last_move/1`, `describe_status/1` print/describe just the latest step.
- `Chess.Repl` — IEx helpers: `new/0`, `move/1` (engine), `move/2` (SAN).
  Returns `{:ok, game}` or `{:error, reason}`, prints narrator-style steps.
  Sets process dictionary flag `:chess_repl_compact` so `Chess.Game` inspects
  compactly; clear with `Chess.Repl.clear/0`.
- `Chess.UCI` — the UCI protocol core: `handle/2` turns one input line into
  replies, a search plan or stop/quit; `parse_move/2` and `to_uci/1` convert
  moves; `plan_go/2` turns the `go` arguments into a depth and a soft time
  budget. No IO and no processes, so it is tested directly. `Chess.UCI.CLI`
  is the escript entry point (`main/1`): it reads stdin, writes stdout, runs
  the search in its own process for `stop`/`isready`, and never prints
  anything but UCI lines to stdout. `mix escript.build` writes `./chess_ex`.
- Tests mirror `lib/` one-to-one under `test/chess/`. Plain `ExUnit.Case`, no
  fixtures or services. `test/chess_test.exs` is a dummy leftover from `mix new`.
  `rules_test.exs` includes perft from the initial position
  (20 / 400 / 8902 / 197281), which is the main regression net for generation,
  and replays every game of `test/fixtures/` ply by ply, holding the state of
  the game after every ply against a second derivation of the castling rights,
  the en passant target and the two counters of a FEN record.
  `test/fixtures/` holds ten well known games in PGN plus two synthetic games:
  one that covers the special moves the famous games lack and one that starts
  from a FEN; the files are read by `pgn_test.exs`, the results of that suite
  stand in `test/fixtures/README.md`.

## Conventions that differ from defaults

- `Chess.Position.file/1`, `rank/1`, `file_index/1`, `dark?/1`,
  `light?/1` are **hand-expanded exhaustive guard clauses**, not computed
  arithmetic. Match that style when extending (compile-time constants, no
  fallback clauses for known inputs).
- `Position.dark?/1` and `Position.light?/1` mean **square color**, not piece
  color. Piece color uses `Piece.black?/1` / `Piece.white?/1`.
- `String.to_atom/1` on the 64 bounded squares is fine; be careful if reusing
  that pattern for arbitrary future PGN/FEN input.
- A **position** of a game (the thing the repetition rules count) is the board,
  the side to move, the castling rights and the en passant target; the
  halfmove clock and the number of the move are not part of it. The en passant
  target only counts when the side to move can really take a pawn with it.
- The repetition rules work the moves of a game again through
  `Game.replay/1` instead of keeping a history of positions around;
  `Rules.apply/2` stays free of them, so perft is not slowed down by them. A
  game that does not start from the initial position has to know where its
  moves begin: that is what `Game.start` is for.
- Text that comes from a file is handled **byte by byte** (`IO.iodata_to_binary/1`,
  `List.to_string/1` is *not* the same thing): a tag value like `Łódź` has to
  survive the round trip. `Enum.join/1` on a list of char codes turns them
  into decimal numbers.

## Docs

- `doc/RULES.md` is the compact rule set to implement against (moves and draws
  are both in there now); `doc/UNICODE.md` lists the 12 piece glyphs. A board
  SVG lives in `doc/`.
- README's Wikipedia links (FEN, PGN, algebraic notation, UCI) are the
  roadmap for the notations of the library; FEN, PGN and algebraic notation are
  implemented, UCI is not.

## Not part of the project

- `.expert/` is local tooling state: an Elixir code-indexing/LSP server
  (Expert/XPForge) keeps its build cache, indexes, and logs there and ignores
  itself via its own `.gitignore`. Don't delete, edit, or commit it.
