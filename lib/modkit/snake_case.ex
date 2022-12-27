defmodule Modkit.SnakeCase do
  def to_snake(segment) when is_binary(segment) when is_atom(segment) do
    segment |> Macro.underscore() |> no_double_underscores()
  end

  defp no_double_underscores(segment) do
    if String.contains?(segment, "__") do
      segment |> String.replace("__", "_") |> no_double_underscores()
    else
      segment
    end
  end
end
