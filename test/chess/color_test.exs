defmodule Chess.ColorTest do
  use ExUnit.Case

  alias Chess.Color

  test "all/0 returns both colors" do
    assert Color.all() == [:white, :black]
  end

  test "opponent/1 returns the other color" do
    assert Color.opponent(:white) == :black
    assert Color.opponent(:black) == :white
  end
end
