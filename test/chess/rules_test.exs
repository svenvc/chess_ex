defmodule Chess.RulesTest do
  use ExUnit.Case

  alias Chess.{Board, Game, Move, PGN, Piece, Position, Rules}

  defp game(board, side \\ :white, castling \\ MapSet.new(), en_passant \\ nil) do
    %Game{
      board: board,
      side_to_move: side,
      castling: castling,
      en_passant: en_passant
    }
  end

  defp castling_game(extra \\ %{}, rights \\ [:king_side, :queen_side]) do
    board = Map.merge(%{e1: :K, a1: :R, h1: :R, a8: :k}, extra)
    rights = MapSet.new(Enum.map(rights, fn side -> {:white, side} end))

    game(board, :white, rights)
  end

  defp en_passant_game(en_passant) do
    game(%{e1: :K, e5: :P, d5: :p, a8: :k}, :white, MapSet.new(), en_passant)
  end

  describe "attacked?/3" do
    test "pawns attack diagonally forward only" do
      board = %{d4: :P, d5: :p}

      assert Rules.attacked?(board, :c5, :white)
      assert Rules.attacked?(board, :e5, :white)
      refute Rules.attacked?(board, :d5, :white)
      refute Rules.attacked?(board, :c3, :white)

      assert Rules.attacked?(board, :c4, :black)
      assert Rules.attacked?(board, :e4, :black)
      refute Rules.attacked?(board, :d4, :black)
    end

    test "knights jump" do
      board = %{b1: :N, g8: :n}

      assert Rules.attacked?(board, :a3, :white)
      assert Rules.attacked?(board, :c3, :white)
      assert Rules.attacked?(board, :d2, :white)
      refute Rules.attacked?(board, :b3, :white)

      assert Rules.attacked?(board, :f6, :black)
      assert Rules.attacked?(board, :h6, :black)
      assert Rules.attacked?(board, :e7, :black)
    end

    test "kings attack adjacent squares" do
      board = %{e1: :K}

      for square <- [:d1, :d2, :e2, :f1, :f2] do
        assert Rules.attacked?(board, square, :white)
      end

      refute Rules.attacked?(board, :e3, :white)
      refute Rules.attacked?(board, :a1, :white)
    end

    test "sliding pieces" do
      assert Rules.attacked?(%{a1: :R}, :a8, :white)
      assert Rules.attacked?(%{a1: :R}, :h1, :white)
      assert Rules.attacked?(%{c1: :B}, :h6, :white)
      assert Rules.attacked?(%{c1: :B}, :a3, :white)
      assert Rules.attacked?(%{d1: :Q}, :d8, :white)
      assert Rules.attacked?(%{d1: :Q}, :h5, :white)
      assert Rules.attacked?(%{d1: :Q}, :a1, :white)
    end

    test "sliding pieces are blocked by the first piece" do
      board = %{a1: :R, a4: :P}

      refute Rules.attacked?(board, :a8, :white)
      assert Rules.attacked?(%{a1: :R, a4: :p}, :a4, :white)
      refute Rules.attacked?(%{a1: :R, a4: :p}, :a8, :white)
    end
  end

  describe "in_check?/2" do
    test "detects check along a file" do
      board = %{e1: :K, e8: :r, a8: :k}

      assert Rules.in_check?(game(board), :white)
    end

    test "a blocker prevents check" do
      board = %{e1: :K, e4: :P, e8: :r, a8: :k}

      refute Rules.in_check?(game(board), :white)
    end

    test "detects check along a diagonal" do
      board = %{e1: :K, b4: :b, a8: :k}

      assert Rules.in_check?(game(board), :white)
    end
  end

  describe "legal_moves/1" do
    test "the initial position has 20 legal moves" do
      assert length(Rules.legal_moves(Game.new())) == 20
    end

    test "a pinned piece cannot leave the pin line" do
      board = %{e1: :K, e2: :R, e8: :r, a8: :k}
      game = game(board)

      refute Rules.legal_move?(game, Move.new(:e2, :d2))
      assert Rules.legal_move?(game, Move.new(:e2, :e3))
      assert Rules.legal_move?(game, Move.new(:e2, :e8))
    end

    test "the king cannot move into check" do
      board = %{e1: :K, d8: :r, a8: :k}
      game = game(board)

      refute Rules.legal_move?(game, Move.new(:e1, :d1))
      assert Rules.legal_move?(game, Move.new(:e1, :f1))
    end
  end

  describe "castling" do
    test "both sides are legal when the path is clear" do
      game = castling_game()

      assert Rules.legal_move?(game, Move.castle(:e1, :g1))
      assert Rules.legal_move?(game, Move.castle(:e1, :c1))
    end

    test "applying castling moves the rook too" do
      game = Rules.apply(castling_game(), Move.castle(:e1, :g1))

      assert game.board == %{g1: :K, f1: :R, a1: :R, a8: :k}
      assert game.side_to_move == :black
      assert game.castling == MapSet.new()
    end

    test "a blocked path prevents castling" do
      game = castling_game(%{f1: :B})

      refute Rules.legal_move?(game, Move.castle(:e1, :g1))
      assert Rules.legal_move?(game, Move.castle(:e1, :c1))
    end

    test "passing through check prevents castling" do
      game = castling_game(%{f8: :r})

      refute Rules.legal_move?(game, Move.castle(:e1, :g1))
    end

    test "castling is not allowed while in check" do
      game = castling_game(%{e8: :r})

      assert Rules.in_check?(game)
      refute Rules.legal_move?(game, Move.castle(:e1, :g1))
    end

    test "castling requires the right and the rook" do
      refute Rules.legal_move?(castling_game(%{}, []), Move.castle(:e1, :g1))
      refute Rules.legal_move?(castling_game(%{h1: nil}), Move.castle(:e1, :g1))
    end
  end

  describe "en passant" do
    test "captures the pawn behind the target square" do
      game = en_passant_game(:d6)

      assert Rules.legal_move?(game, Move.en_passant(:e5, :d6))

      next = Rules.apply(game, Move.en_passant(:e5, :d6))

      assert next.board == %{e1: :K, d6: :P, a8: :k}
      assert next.side_to_move == :black
      assert next.en_passant == nil
    end

    test "is not available without an en passant target" do
      refute Rules.legal_move?(en_passant_game(nil), Move.en_passant(:e5, :d6))
    end

    test "is rejected when it exposes the king" do
      game = game(%{e1: :K, e5: :P, d5: :p, e8: :r, a8: :k}, :white, MapSet.new(), :d6)

      refute Rules.legal_move?(game, Move.en_passant(:e5, :d6))
    end
  end

  describe "promotion" do
    test "offers queen, rook, bishop and knight" do
      game = game(%{e1: :K, a7: :P, e8: :k})

      promotions =
        game
        |> Rules.legal_moves()
        |> Enum.filter(&match?({:promotion, :a7, :a8, _piece}, &1))

      assert length(promotions) == 4

      for piece <- [:Q, :R, :B, :N] do
        assert Move.promotion(:a7, :a8, piece) in promotions
      end
    end

    test "applying a promotion places the chosen piece" do
      game = Rules.apply(game(%{e1: :K, a7: :P, e8: :k}), Move.promotion(:a7, :a8, :N))

      assert game.board[:a8] == :N
      refute Map.has_key?(game.board, :a7)
    end

    test "black promotes on rank 1" do
      game = game(%{e1: :K, h2: :p, a8: :k}, :black)

      assert Rules.legal_move?(game, Move.promotion(:h2, :h1, :q))
    end
  end

  describe "apply/2" do
    test "switches sides and sets the en passant target after a double push" do
      game = Game.new() |> Rules.apply(Move.new(:e2, :e4))

      assert game.side_to_move == :black
      assert game.en_passant == :e3
      assert game.moves == [{:e2, :e4}]
    end

    test "clears the en passant target after any other move" do
      game =
        Game.new()
        |> Rules.apply(Move.new(:e2, :e4))
        |> Rules.apply(Move.new(:a7, :a6))

      assert game.en_passant == nil
    end

    test "a king move revokes both castling rights" do
      game =
        Game.new()
        |> Rules.apply(Move.new(:e2, :e4))
        |> Rules.apply(Move.new(:e7, :e5))
        |> Rules.apply(Move.new(:e1, :e2))

      refute MapSet.member?(game.castling, {:white, :king_side})
      refute MapSet.member?(game.castling, {:white, :queen_side})
    end

    test "a rook move revokes its castling right" do
      game =
        game(%{e1: :K, h1: :R, e8: :k}, :white, MapSet.new([{:white, :king_side}]))
        |> Rules.apply(Move.new(:h1, :h2))

      refute MapSet.member?(game.castling, {:white, :king_side})
    end

    test "capturing a rook revokes the opponent's castling right" do
      game =
        game(
          %{a1: :K, h1: :R, h8: :r, a8: :k},
          :white,
          MapSet.new([{:black, :king_side}, {:white, :king_side}])
        )
        |> Rules.apply(Move.new(:h1, :h8))

      refute MapSet.member?(game.castling, {:black, :king_side})
    end
  end

  describe "game end" do
    test "detects fool's mate" do
      game =
        Game.new()
        |> Rules.apply(Move.new(:f2, :f3))
        |> Rules.apply(Move.new(:e7, :e5))
        |> Rules.apply(Move.new(:g2, :g4))
        |> Rules.apply(Move.new(:d8, :h4))

      assert Rules.in_check?(game)
      assert Rules.checkmate?(game)
      refute Rules.stalemate?(game)
    end

    test "detects checkmate" do
      game = game(%{a8: :k, c7: :K, b7: :Q}, :black)

      assert Rules.in_check?(game)
      assert Rules.checkmate?(game)
    end

    test "detects stalemate" do
      game = game(%{a8: :k, c7: :K, b6: :Q}, :black)

      refute Rules.in_check?(game)
      assert Rules.legal_moves(game) == []
      assert Rules.stalemate?(game)
      refute Rules.checkmate?(game)
    end
  end

  # Perft ("performance test") counts the leaf nodes reachable in a given
  # number of plies by recursively enumerating legal moves. Comparing the counts
  # against the known values for the initial position is the standard way to
  # catch move-generation and legality bugs (missed or illegal moves).
  test "perft from the initial position" do
    game = Game.new()

    assert perft(game, 1) == 20
    assert perft(game, 2) == 400
    assert perft(game, 3) == 8902
    assert perft(game, 4) == 197_281
  end

  # The games in `test/fixtures` are played out again here, ply by ply. The
  # reader of a PGN already replays every move, but this test looks at the
  # state of the game after every ply and holds it against a second
  # derivation of the rules: the castling rights and the en passant target
  # are worked out from the rules again and the board is read move by move.
  describe "the games of the fixtures" do
    @fixture_files Path.wildcard(Path.join([__DIR__, "..", "fixtures", "*.pgn"]))

    for file <- @fixture_files do
      test "plays #{Path.basename(file)} ply by ply" do
        file = unquote(Macro.escape(file))
        pgn = PGN.parse_file(file)

        final = replay(pgn)

        assert final.board == pgn.game.board
        assert final.side_to_move == pgn.game.side_to_move
        assert final.castling == pgn.game.castling
        assert final.en_passant == pgn.game.en_passant
        assert final.moves == pgn.game.moves
      end
    end
  end

  defp perft(_game, 0), do: 1

  defp perft(game, depth) do
    game
    |> Rules.legal_moves()
    |> Enum.map(fn move -> perft(Rules.apply(game, move), depth - 1) end)
    |> Enum.sum()
  end

  # Play the moves of a game and check the state of the game after every ply.
  defp replay(pgn) do
    start = pgn.game.start || Game.new()

    Enum.reduce(Enum.with_index(pgn.moves, 1), start, fn {move, ply}, game ->
      context = "ply #{ply}: #{inspect(move)}"

      assert move in Rules.legal_moves(game), "#{context}: the move is not legal"

      next = Rules.apply(game, move)
      mover = game.side_to_move

      # the side to move alternates
      assert next.side_to_move == opponent(mover),
             "#{context}: the side to move does not alternate"

      # the mover does not stand in check after its own move
      refute Rules.in_check?(next, mover), "#{context}: the mover stands in check"

      # the history grows by one move and the new move stands at its head
      assert length(next.moves) == length(game.moves) + 1, "#{context}: the history does not grow"

      assert List.first(next.moves) == move, "#{context}: the history does not hold the move"

      # the board holds the move
      assert_board(game, next, move, context)

      # the castling rights and the en passant target are worked out again
      assert next.castling == expected_castling(game, move), "#{context}: wrong castling rights"

      assert next.en_passant == expected_en_passant(game, move),
             "#{context}: wrong en passant target"

      # the counters of the FEN record are worked out again
      assert next.halfmove_clock == expected_halfmove_clock(game, move),
             "#{context}: wrong halfmove clock"

      assert next.fullmove_number == expected_fullmove_number(game),
             "#{context}: wrong fullmove number"

      next
    end)
  end

  # Read the change of the board move by move: the piece that moves stands on
  # its new square, the square it comes from is empty and the piece it takes
  # is gone.
  defp assert_board(game, next, move, context) do
    board = game.board
    color = game.side_to_move
    from = move_from(move)
    to = move_to(move)
    piece = Board.at(board, from)

    assert piece != nil, "#{context}: no piece stands on #{from}"
    assert color_of(piece) == color, "#{context}: the piece belongs to the other side"

    case move do
      {:castle, _from, _to} ->
        {rook_from, rook_to} = castling_rook(color, to)

        assert Board.at(next.board, to) == king_of(color), "#{context}: the king is not on #{to}"

        assert Board.at(next.board, rook_to) == rook_of(color),
               "#{context}: the rook is not on #{rook_to}"

        assert Board.at(next.board, from) == nil, "#{context}: #{from} is not empty"
        assert Board.at(next.board, rook_from) == nil, "#{context}: #{rook_from} is not empty"

      {:en_passant, _from, _to} ->
        victim = Position.new(Position.file(to), Position.rank(from))

        assert Board.at(next.board, to) == piece, "#{context}: the pawn is not on #{to}"
        assert Board.at(next.board, from) == nil, "#{context}: #{from} is not empty"

        assert Board.at(next.board, victim) == nil,
               "#{context}: the pawn on #{victim} is not taken"

      {:promotion, _from, _to, promoted} ->
        assert Board.at(next.board, to) == promoted, "#{context}: the new piece is not on #{to}"
        assert Board.at(next.board, from) == nil, "#{context}: #{from} is not empty"

      {_from, _to} ->
        assert Board.at(next.board, to) == piece, "#{context}: the piece is not on #{to}"
        assert Board.at(next.board, from) == nil, "#{context}: #{from} is not empty"
    end

    # the number of pieces on the board tells a capture from a quiet move
    captured = captured_square(board, move)

    assert map_size(next.board) == map_size(board) - if(captured, do: 1, else: 0),
           "#{context}: the number of pieces does not fit"
  end

  # The castling rights of the next position, worked out from the rules again:
  # a king that moves loses both rights of its color, a rook that leaves its
  # home corner loses the right of that corner and a rook that is taken on its
  # home corner loses it as well.
  defp expected_castling(game, move) do
    board = game.board
    color = game.side_to_move
    from = move_from(move)
    to = move_to(move)
    king_moved = Piece.is_king?(Board.at(board, from))

    for side_color <- [:white, :black],
        side <- [:king_side, :queen_side],
        reduce: game.castling do
      rights ->
        corner = corner(side_color, side)

        lost? =
          (king_moved and side_color == color) or
            (from == corner and Board.at(board, corner) != nil) or
            (to == corner and Board.at(board, to) != nil)

        if lost?, do: MapSet.delete(rights, {side_color, side}), else: rights
    end
  end

  # The en passant target of the next position: the square a pawn skipped over
  # when it moved two squares, and nothing for every other move.
  defp expected_en_passant(game, move) do
    board = game.board
    from = move_from(move)
    to = move_to(move)

    if Piece.is_pawn?(Board.at(board, from)) and
         abs(Position.rank(to) - Position.rank(from)) == 2 do
      Position.new(Position.file(from), div(Position.rank(from) + Position.rank(to), 2))
    else
      nil
    end
  end

  # The halfmove clock of the next position: it starts over after a capture
  # or a pawn move and grows by one after every other move.
  defp expected_halfmove_clock(game, move) do
    board = game.board
    from = move_from(move)

    if captured_square(board, move) != nil or Piece.is_pawn?(Board.at(board, from)) do
      0
    else
      game.halfmove_clock + 1
    end
  end

  # The number of the full move goes up after the move of Black.
  defp expected_fullmove_number(game) do
    if game.side_to_move == :black, do: game.fullmove_number + 1, else: game.fullmove_number
  end

  # The square a move takes a piece on: the destination of an ordinary move,
  # the square beside the destination for a pawn that takes en passant, and
  # nothing for a castling.
  defp captured_square(board, {_from, to}), do: if(Board.at(board, to), do: to)

  defp captured_square(board, {:en_passant, from, to}) do
    victim = Position.new(Position.file(to), Position.rank(from))

    if Board.at(board, victim), do: victim
  end

  defp captured_square(board, {:promotion, _from, to, _piece}),
    do: if(Board.at(board, to), do: to)

  defp captured_square(_board, {:castle, _from, _to}), do: nil

  # The rook that castles and the square it stands on: the king side uses the
  # h file, the queen side the a file.
  defp castling_rook(color, to) do
    rank = home_rank(color)

    if Position.file(to) == :g do
      {Position.new(:h, rank), Position.new(:f, rank)}
    else
      {Position.new(:a, rank), Position.new(:d, rank)}
    end
  end

  defp corner(:white, :king_side), do: :h1
  defp corner(:white, :queen_side), do: :a1
  defp corner(:black, :king_side), do: :h8
  defp corner(:black, :queen_side), do: :a8

  defp home_rank(:white), do: 1
  defp home_rank(:black), do: 8

  defp king_of(:white), do: :K
  defp king_of(:black), do: :k

  defp rook_of(:white), do: :R
  defp rook_of(:black), do: :r

  defp color_of(piece) do
    if Piece.is_white?(piece), do: :white, else: :black
  end

  defp opponent(:white), do: :black
  defp opponent(:black), do: :white

  defp move_from({from, _to}), do: from
  defp move_from({:castle, from, _to}), do: from
  defp move_from({:en_passant, from, _to}), do: from
  defp move_from({:promotion, from, _to, _piece}), do: from

  defp move_to({_from, to}), do: to
  defp move_to({:castle, _from, to}), do: to
  defp move_to({:en_passant, _from, to}), do: to
  defp move_to({:promotion, _from, to, _piece}), do: to
end
