# chess_ex

ChessEx is an Elixir project implementing tools related to Chess, including an engine and support for various notations.

## usage

Play interactively in IEx with `Chess.Repl`:

```elixir
iex> {:ok, game} = Chess.Repl.new()
r n b q k b n r
...
White to move.
{:ok, #Chess.Game<>}

iex> {:ok, game} = Chess.Repl.move(game, "e4")
1. e4
...
Black to move.
{:ok, #Chess.Game<>}

iex> {:ok, game} = Chess.Repl.move(game)  # engine move
2. ...
...
White to move.
{:ok, #Chess.Game<>}

iex> Chess.Repl.clear()  # restore full game inspection
:ok
```

The board of the starting position:

```elixir
iex> Chess.Board.print(Chess.Board.initial())
r n b q k b n r
p p p p p p p p
. . . . . . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
P P P P P P P P
R N B Q K B N R
```

A game read from a PGN file. The moves are the moves of the game, in the
order they were played, and the game itself is the state after the last move:

```elixir
iex> pgn = Chess.PGN.parse_file("test/fixtures/The_Opera_game.pgn")
iex> pgn.result
"1-0"
iex> length(pgn.moves)
33
iex> Chess.Board.print(pgn.game.board)
. n . R k b . r
p . . . . p p p
. . . . q . . .
. . . . p . B .
. . . . P . . .
. . . . . . . .
P P P . . P P P
. . K . . . . .
```

A game written back as PGN:

```elixir
iex> IO.puts(Chess.PGN.to_pgn(pgn))
[Event "Paris"]
[Site "Paris FRA"]
...
1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8.
Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14.
Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8#
1-0
```

A position read from a FEN record. The record holds the placement of the
pieces, the side to move, the castling rights, the en passant target and the
two counters of the game:

```elixir
iex> game = Chess.FEN.parse("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")
iex> Chess.Board.print(game.board)
r . b q k b n r
p p p p . p p p
. . n . . . . .
. . . . p . . .
. . . . P . . .
. . . . . N . .
P P P P . P P P
R N B Q K B . R
iex> game.side_to_move
:white
```

The position is written back as a record:

```elixir
iex> IO.puts(Chess.FEN.to_fen(game))
r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3
```

A PGN game may start from a position of its own. The position then stands in
the tag pair `FEN`, and the moves of the game are read and written against
it.

A game described step by step. Every ply holds the move in algebraic notation,
the move in words, the board it leads to and the strength of the position, and
the text ends with how the game stopped:

```elixir
iex> pgn |> Chess.Narrator.describe() |> String.split("\n\n") |> Enum.take(3) |> Enum.join("\n\n") |> IO.puts()
Paul Morphy (White) vs Duke Karl / Count Isouard (Black)

Initial position
r n b q k b n r
p p p p p p p p
. . . . . . . .
. . . . . . . .
. . . . . . . .
. . . . . . . .
P P P P P P P P
R N B Q K B N R
Evaluation: +0.00 for White (material +0.00, positional +0.00)

1. e4
white pawn from e2 to e4, advances two squares
r n b q k b n r
p p p p p p p p
. . . . . . . .
. . . . . . . .
. . . . P . . .
. . . . . . . .
P P P P . P P P
R N B Q K B N R
Evaluation: +0.00 for White (material +0.00, positional +0.00)
```

Captures, castling, promotions and checks are spelled out as they happen:

```
19. Nxb5
white knight from c3 to b5, captures black pawn on b5

23. O-O-O
white king castles queen side from e1 to c1, rook from a1 to d1

33. Rd8#
white rook from d1 to d8, black is checkmated
```

`Chess.Narrator.print/1` writes the whole description out; the text ends with
a sentence about how the game stopped, as in `black is checkmated. White wins
(1-0).`

How a game stands, and who won it:

```elixir
iex> game = Chess.PGN.parse_file("test/fixtures/The_Opera_game.pgn").game
iex> Chess.Game.status(game)
:checkmate
iex> Chess.Game.winner(game)
:white
iex> Chess.Game.over?(game)
true
```

A game that is still running is `:ongoing`; a drawn game is one of
`:draw_repetition`, `:draw_fivefold_repetition`, `:draw_fifty_moves`,
`:draw_seventy_five_moves` or `:draw_insufficient_material`, and a drawn game
has no winner.

Playing a game automatically with the engine:

```elixir
iex> game = Chess.Game.new()
iex> {:ok, game, move} = Chess.Engine.play(game)
iex> move
{:e2, :e4}
iex> {:ok, game, _move} = Chess.Engine.play(game, strategy: :random)
iex> game.side_to_move
:white
iex> Chess.Engine.best_move(game)
{:ok, {:d7, :d5}}
```

`Chess.Engine.play/2` applies the move and returns `{:ok, game, move}`. It uses
1-ply evaluation by default (`:best` strategy) and can also pick a `:random`
move. When the game is over, it returns `{:error, reason}` with the game
status.

The `:search` strategy plays a move found by a depth-limited search:

```elixir
game = Chess.Game.new()
{:ok, game, move} = Chess.Engine.play(game, strategy: :search, depth: 3)
{:ok, reply} = Chess.Engine.search_move(game, depth: 2, randomize: false)
```

`depth` counts plies (half-moves), so `depth: 3` looks at a move, the reply
and one more move; the default is `3`. `Chess.Search` explains the search:
it uses **negamax** (minimax with a single side-to-move score and a sign flip
per move) with **alpha-beta pruning**, which skips lines that cannot change
the result. Captures are ordered first by **MVV-LVA** (Most Valuable Victim,
Least Valuable Attacker). Material and piece-square tables from
`Chess.Evaluation` score quiet positions. There is no opening book and no
endgame tablebase; deeper searches are stronger but slower.

## UCI interface

The UCI engine is an escript that speaks the protocol on stdin/stdout, the
way a GUI expects it:

```sh
mix escript.build
./chess_ex
```

Point a GUI at `./chess_ex`, or run a session by hand:

```sh
printf 'uci\nisready\nposition startpos moves e2e4\ngo depth 2\n' | ./chess_ex
```

```
id name ChessEx 0.1.0
id author ChessEx contributors
uciok
readyok
info depth 1 score cp 50 time 2 pv b8c6
info depth 2 score cp 0 time 10 pv b8c6
bestmove b8c6
```

The supported commands are `uci`, `isready`, `ucinewgame`, `position`
(`startpos` or `fen`, with an optional `moves` list), `go`, `stop` and `quit`.
`go` understands `depth`, `movetime`, `infinite`, and the clock options
`wtime`, `btime`, `winc`, `binc` and `movestogo`; the clock budget is shared
out over the moves left and the search deepens until the budget is used. An
automatic search stops at depth 4; `go depth N` can go deeper, and an explicit
`depth` wins over any time limit. `infinite` deepens to the automatic maximum
unless stopped. The search does not advertise `UCI_LimitStrength` or
`UCI_Elo`, because the engine has no strength setting.

A `go` runs in a process of its own, so `isready`, `stop` and `quit` are
answered while the engine is thinking. `stop` answers with the best move of
the last completed iteration. The search itself has no time check inside a
single iteration, so a time limit is soft: a deeper iteration that has already
started can overshoot it. Nothing but UCI lines is written to stdout.

## references

- https://en.wikipedia.org/wiki/Chess
- https://en.wikipedia.org/wiki/Chess_notation
- https://en.wikipedia.org/wiki/Forsyth–Edwards_Notation
- https://en.wikipedia.org/wiki/Portable_Game_Notation
- https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
- https://en.wikipedia.org/wiki/Chess_symbols_in_Unicode
- https://en.wikipedia.org/wiki/Chess_engine
- https://en.wikipedia.org/wiki/Universal_Chess_Interface

## documentation

- [the rules of Chess](doc/RULES.md)
- [the PGN test fixtures](test/fixtures/README.md)
