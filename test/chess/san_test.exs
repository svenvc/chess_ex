defmodule Chess.SANTest do
  use ExUnit.Case

  alias Chess.{Game, Rules, SAN}
  alias Chess.SAN.ParseError

  defp game(board, side \\ :white, castling \\ MapSet.new(), en_passant \\ nil) do
    %Game{
      board: board,
      side_to_move: side,
      castling: castling,
      en_passant: en_passant
    }
  end

  describe "parse/2" do
    test "a pawn push" do
      assert SAN.parse("e4", game(%{e2: :P, e1: :K, a8: :k})) == {:e2, :e4}
    end

    test "a piece move" do
      assert SAN.parse("Nf3", game(%{g1: :N, e1: :K, a8: :k})) == {:g1, :f3}
    end

    test "a capture" do
      assert SAN.parse("exd5", game(%{e4: :P, d5: :p, e1: :K, a8: :k})) == {:e4, :d5}
    end

    test "a capture of a piece" do
      assert SAN.parse("Qxf3", game(%{d1: :Q, f3: :p, e1: :K, h8: :k})) == {:d1, :f3}
    end

    test "the file tells two knights apart" do
      board = %{b1: :N, f3: :N, e1: :K, a8: :k}

      assert SAN.parse("Nbd2", game(board)) == {:b1, :d2}
      assert_raise ParseError, ~r/matches 2 legal moves/, fn -> SAN.parse("Nd2", game(board)) end
    end

    test "the rank tells two knights apart" do
      board = %{d3: :N, d5: :N, e1: :K, a8: :k}

      assert SAN.parse("N3f4", game(board)) == {:d3, :f4}
      assert_raise ParseError, ~r/matches 2 legal moves/, fn -> SAN.parse("Ndf4", game(board)) end
    end

    test "the file and the rank tell three queens apart" do
      board = %{a1: :Q, a5: :Q, e1: :Q, h1: :K, h6: :k}

      assert SAN.parse("Qa1e5", game(board)) == {:a1, :e5}
      assert_raise ParseError, ~r/matches 3 legal moves/, fn -> SAN.parse("Qe5", game(board)) end
    end

    test "a promotion" do
      board = %{e7: :P, e1: :K, a6: :k}

      assert SAN.parse("e8=Q", game(board)) == {:promotion, :e7, :e8, :Q}
    end

    test "an underpromotion" do
      board = %{e7: :P, e1: :K, a6: :k}

      assert SAN.parse("e8=N", game(board)) == {:promotion, :e7, :e8, :N}
    end

    test "an en passant capture" do
      board = %{e5: :P, d5: :p, e1: :K, a8: :k}

      assert SAN.parse("exd6", game(board, :white, MapSet.new(), :d6)) ==
               {:en_passant, :e5, :d6}
    end

    test "castling to the king side" do
      board = %{e1: :K, h1: :R, c8: :k}
      castling = MapSet.new([{:white, :king_side}])

      assert SAN.parse("O-O", game(board, :white, castling)) == {:castle, :e1, :g1}
    end

    test "castling to the queen side" do
      board = %{e1: :K, a1: :R, c8: :k}
      castling = MapSet.new([{:white, :queen_side}])

      assert SAN.parse("O-O-O", game(board, :white, castling)) == {:castle, :e1, :c1}
    end

    test "castling written with zeros" do
      board = %{e1: :K, h1: :R, c8: :k}
      castling = MapSet.new([{:white, :king_side}])

      assert SAN.parse("0-0", game(board, :white, castling)) == {:castle, :e1, :g1}
    end

    test "a check" do
      board = %{d1: :Q, e1: :K, e8: :k}

      assert SAN.parse("Qd8+", game(board)) == {:d1, :d8}
    end

    test "a checkmate" do
      board = %{g6: :Q, h6: :B, e1: :K, h8: :k}

      assert SAN.parse("Qg7#", game(board)) == {:g6, :g7}
    end

    test "a malformed token" do
      assert_raise ParseError, ~r/not a valid SAN token/, fn ->
        SAN.parse("Z9", game(%{e2: :P, e1: :K, a8: :k}))
      end
    end

    test "a move that is not legal" do
      assert_raise ParseError, ~r/no legal move matches/, fn ->
        SAN.parse("e5", game(%{e2: :P, e1: :K, a8: :k}))
      end
    end

    test "a marker that does not match the move" do
      board = %{e2: :P, e1: :K, a8: :k}

      assert_raise ParseError, ~r/is marked check but the move gives none/, fn ->
        SAN.parse("e4+", game(board))
      end
    end

    test "a missing marker" do
      board = %{d1: :Q, e1: :K, e8: :k}

      assert_raise ParseError, ~r/is marked none but the move gives check/, fn ->
        SAN.parse("Qd8", game(board))
      end
    end

    test "the marker is not checked when it should not be" do
      board = %{d1: :Q, e1: :K, e8: :k}

      assert SAN.parse("Qd8", game(board), validate_marker: false) == {:d1, :d8}
    end
  end

  describe "to_san/2" do
    test "a pawn push" do
      assert SAN.to_san({:e2, :e4}, game(%{e2: :P, e1: :K, a8: :k})) == "e4"
    end

    test "a piece move" do
      assert SAN.to_san({:g1, :f3}, game(%{g1: :N, e1: :K, a8: :k})) == "Nf3"
    end

    test "a pawn capture keeps the file of the pawn" do
      assert SAN.to_san({:e4, :d5}, game(%{e4: :P, d5: :p, e1: :K, a8: :k})) == "exd5"
    end

    test "a piece capture" do
      assert SAN.to_san({:d1, :f3}, game(%{d1: :Q, f3: :p, e1: :K, h8: :k})) == "Qxf3"
    end

    test "castling" do
      board = %{e1: :K, h1: :R, c8: :k}
      castling = MapSet.new([{:white, :king_side}])

      assert SAN.to_san({:castle, :e1, :g1}, game(board, :white, castling)) == "O-O"
    end

    test "queen side castling" do
      board = %{e1: :K, a1: :R, c8: :k}
      castling = MapSet.new([{:white, :queen_side}])

      assert SAN.to_san({:castle, :e1, :c1}, game(board, :white, castling)) == "O-O-O"
    end

    test "a promotion" do
      board = %{e7: :P, e1: :K, a6: :k}

      assert SAN.to_san({:promotion, :e7, :e8, :Q}, game(board)) == "e8=Q"
    end

    test "the file tells two knights apart" do
      board = %{b1: :N, f3: :N, e1: :K, a8: :k}

      assert SAN.to_san({:b1, :d2}, game(board)) == "Nbd2"
    end

    test "the rank tells two knights apart" do
      board = %{d3: :N, d5: :N, e1: :K, a8: :k}

      assert SAN.to_san({:d3, :f4}, game(board)) == "N3f4"
    end

    test "the file and the rank tell three queens apart" do
      board = %{a1: :Q, a5: :Q, e1: :Q, h1: :K, h6: :k}

      assert SAN.to_san({:a1, :e5}, game(board)) == "Qa1e5"
    end

    test "a check" do
      board = %{d1: :Q, e1: :K, e8: :k}

      assert SAN.to_san({:d1, :d8}, game(board)) == "Qd8+"
    end

    test "a checkmate" do
      board = %{g6: :Q, h6: :B, e1: :K, h8: :k}

      assert SAN.to_san({:g6, :g7}, game(board)) == "Qg7#"
    end

    test "a move that is not legal" do
      assert_raise ParseError, ~r/not a legal move/, fn ->
        SAN.to_san({:e2, :e5}, game(%{e2: :P, e1: :K, a8: :k}))
      end
    end
  end

  describe "parse/2 and to_san/2" do
    test "a token describes the move it was written for" do
      board = %{b1: :N, f3: :N, d3: :P, d5: :P, e1: :K, a8: :k}
      state = game(board)

      for move <- Rules.legal_moves(state) do
        san = SAN.to_san(move, state)

        assert SAN.parse(san, state) == move
      end
    end
  end
end
