defmodule Chess.Color do
  @moduledoc """
  Functionality related to the colors of a Chess game.

  A color is `:white` or `:black`.
  """

  @colors [:white, :black]

  @doc """
  Return both colors.
  """
  def all, do: @colors

  @doc """
  Return the other color.
  """
  def opponent(:white), do: :black
  def opponent(:black), do: :white
end
