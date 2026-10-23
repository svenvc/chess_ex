defmodule Chess.UCI.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Chess.UCI.CLI

  @version Mix.Project.config()[:version]

  test "answers the handshake and quits" do
    output = capture_io("uci\nisready\nquit\n", fn -> CLI.run() end)

    assert output =~ "id name ChessEx #{@version}"
    assert output =~ "id author ChessEx contributors"
    assert output =~ "uciok"
    assert output =~ "readyok"
  end

  test "searches and answers with a best move" do
    output = capture_io("position startpos\ngo depth 1\n", fn -> CLI.run() end)

    assert output =~ ~r/info depth 1 score (cp|mate)/
    assert output =~ ~r/bestmove [a-h][1-8][a-h][1-8]/
  end

  test "stops on the end of the input" do
    assert capture_io("isready\n", fn -> CLI.run() end) =~ "readyok"
  end
end
