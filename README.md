# chess_ex

ChessEx is an Elixir project implementing tools related to Chess, including an engine and support for various notations.

## usage

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
