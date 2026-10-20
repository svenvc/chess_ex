defmodule Chess.GameTest do
  use ExUnit.Case

  alias Chess.{Board, Game}

  test "new/0 starts from the initial position" do
    game = Game.new()

    assert game.board == Board.initial()
    assert game.side_to_move == :white
    assert game.en_passant == nil
    assert game.moves == []

    assert game.castling ==
             MapSet.new([
               {:white, :king_side},
               {:white, :queen_side},
               {:black, :king_side},
               {:black, :queen_side}
             ])
  end
end
