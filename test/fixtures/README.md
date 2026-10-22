# Test fixtures

Ten well known games in PGN and two synthetic games, used as the regression
suite for the PGN reader and the SAN parser. `test/chess/pgn_test.exs` reads
every file, checks the headers, the number of moves, the final position and
the state the game ends in, and writes each game back out and reads it again.
`test/chess/rules_test.exs` plays every file a second time, ply by ply, and
holds the state of the game after every ply against a second derivation of the
rules: the castling rights, the en passant target and the two counters of a
FEN record are worked out again and the board is read move by move.

The files are not part of the library; they are only used by the tests.

## Results

Every game is played out by the rules engine of this library without an
error, and the number of moves matches the `PlyCount` tag of the file (where
the file has one). Every `+` and `#` marker of the files agrees with the
engine: the reader rejects a marker that does not fit the move, so a file that
is read at all is a file whose markers are right.

| File | Event | White | Black | Result | Moves | `PlyCount` | Last move | Ends in |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `The_Opera_game.pgn` | Paris | Paul Morphy | Duke Karl / Count Isouard | 1-0 | 33 | 33 | `17.Rd8#` | checkmate |
| `The-Game-of-the-Century-Byrnne-Fisher.pgn` | Third Rosenwald Trophy | Donald Byrne | Robert James Fischer | 0-1 | 82 | 82 | `41...Rc2#` | checkmate |
| `anderssen-kieseritzky-1851.pgn` | Casual game: traditional score and illustrative finish | Adolf Anderssen | Lionel Kieseritzky | 1-0 | 45 | – | `23.Be7#` | checkmate |
| `anderssen_dufresne_1852.pgn` | Casual Game | Adolf Anderssen | Jean Dufresne | 1-0 | 40 | 40 | `20.Rxe7+ Nxe7` | resignation, quiet |
| `steinitz-bardeleben-1895.pgn` | ? | Wilhelm Steinitz | Curt von Bardeleben | 1-0 | 49 | – | `25.Rxh7+` | resignation, black in check |
| `rotlewi-rubinstein-1907.pgn` | ? | Gersz Rotlewi | Akiba Rubinstein | 0-1 | 50 | – | `25.Qg2 Rh3` | resignation, quiet |
| `Deep_Blue_vs_Kasparov.pgn` | IBM Man-Machine | Deep Blue (Computer) | Garry Kasparov | 1-0 | 37 | 37 | `19.c4` | resignation, quiet |
| `karpov-kasparov-game-16.pgn` | World Chess Championship, Game 16 | Anatoly Karpov | Garry Kasparov | 0-1 | 80 | – | `40...Re1+` | resignation, white in check |
| `Kasparovs-Immortal-Kasparov-Topalov.pgn` | Hoogovens Group A | Garry Kasparov | Veselin Topalov | 1-0 | 87 | 87 | `44.Qa7` | resignation, quiet |
| `aronian-anand-2013.pgn` | Tata Steel-A 75th | Levon Aronian | Viswanathan Anand | 0-1 | 46 | – | `23.Qd3 Be3` | resignation, quiet |
| `synthetic_special_moves.pgn` | Synthetic Special Moves | Engine | Engine | 1-0 | 31 | – | `16.O-O-O` | resignation, quiet |
| `fen_start.pgn` | FEN Start | Engine | Engine | 1-0 | 16 | – | `10...Nbd7` | resignation, quiet |

Three games end in checkmate, two in a resignation with the loser in check,
seven in a quiet resignation. The games without a `PlyCount` tag are the older
ones and the synthetic ones; their number of moves was counted by hand. The
synthetic games are not games that were played; they end in a quiet position
like the other resignations, only to cover what the famous games lack.

## Notes on the files

- **Anderssen - Dufresne (1852)**: the mate in four that ends the game stands
  in a comment, not in the moves of the file. The game therefore ends after
  40 moves with `20...Nxe7`, and the comment holds the rest:

  ```
  20.Rxe7+ Nxe7 {White gives mate in 4 moves.  21.Qxd7+ Kxd7 22.Bf5+ Ke8 23.Bd7+ Kf8 24.Bxe7#}
  ```

- **Anderssen - Kieseritzky (1851)**: the file goes on after the end of
  Kieseritzky's own account. A comment marks the spot, the traditional
  continuation follows and the game ends in mate with `23.Be7#`.

- **Synthetic Special Moves** (`synthetic_special_moves.pgn`): not a game that
  was played, but a game put together to hold the special moves that the ten
  famous games do not contain:

  | what | where |
  | --- | --- |
  | a pawn that takes en passant | `3.exd6` |
  | a pawn that promotes and takes a piece | `15.bxa8=Q` |
  | a rook that is taken on its home corner, with the right to castle still alive | `15.bxa8=Q` |
  | castling on both sides | `15...O-O`, `16.O-O-O` |
  | a double push whose target is never used | `11.b4` |

  The game has no mate in it: it ends in a quiet position after `16.O-O-O`
  with the result `1-0`.

- **FEN Start** (`fen_start.pgn`): not a game that was played, but a game that
  starts in the middle of one. The position stands in the tag pair `FEN` -
  the one after `2...Nc6` in the Ruy Lopez - and the moves of the file are
  read and written against it, with the move numbers of the file counting
  from the third move on:

  ```
  [SetUp "1"]
  [FEN "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"]

  3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 1-0
  ```

- **Move numbers**: the files are not consistent about them. The Dufresne file
  writes `7.O-O d3`, without a number for the move of Black, and the
  Kieseritzky file writes `20... Na6`, with one. Both are read; the reader only
  checks that a number that is written is the number of the move it stands for.

- **Line endings and encoding**: `rotlewi-rubinstein-1907.pgn` uses CRLF line
  endings and UTF-8 (`[Site "Łódź"]`), the other files use LF and ASCII. The
  reader keeps the bytes of a tag value as they are.

- **Tag pairs**: `karpov-kasparov-game-16.pgn` has no `Round` tag. The writer
  writes the tag pairs of the seven tag roster, so it adds `[Round "?"]` when
  it writes that game back. The other games keep their tag pairs unchanged.

## Writing a game back

`Chess.PGN.to_pgn/1` writes a game as PGN text: the tag pairs of the seven
tag roster first, the other tag pairs in alphabetical order, the moves in
algebraic notation, wrapped at 80 columns, and the result at the end.

```
iex> pgn = Chess.PGN.parse_file("test/fixtures/The_Opera_game.pgn")
iex> IO.puts(Chess.PGN.to_pgn(pgn))
[Event "Paris"]
[Site "Paris FRA"]
[Date "1858.??.??"]
[Round "?"]
[White "Paul Morphy"]
[Black "Duke Karl / Count Isouard"]
[Result "1-0"]
[BlackElo "?"]
[ECO "C41"]
[EventDate "?"]
[PlyCount "33"]
[Source "(London) Field, London, 1858.12.04, p458"]
[WhiteElo "?"]

1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8.
Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14.
Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8#
1-0
```
