defmodule Chess.PGN.Game do
  @moduledoc """
  A game read from a PGN document.

  Fields:

    * `:headers` - the tag pairs of the game, as a map of name to value
    * `:moves` - the moves of the game, in the order they were played. Note
      that `Chess.Game` keeps its history the other way around, newest first.
    * `:result` - the result of the game: `"1-0"`, `"0-1"`, `"1/2-1/2"` or `"*"`
    * `:comments` - the comments of the game, keyed by the number of moves
      played before the comment
    * `:game` - the `Chess.Game` state after the last move
  """

  defstruct headers: %{}, moves: [], result: nil, comments: %{}, game: nil
end
