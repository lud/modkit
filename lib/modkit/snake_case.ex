defmodule Modkit.SnakeCase do
  def to_snake(segment) when is_binary(segment) when is_atom(segment) do
    underscore(segment) |> no_double_underscores()
  end

  defp no_double_underscores(segment) do
    if String.contains?(segment, "__") do
      segment |> String.replace("__", "_") |> no_double_underscores()
    else
      segment
    end
  end

  #

  #

  #

  #

  # This is a copy of `Macro.underscore/1` but that does not add an underscore
  # after digits.
  defp underscore(atom) when is_atom(atom) do
    "Elixir." <> rest = Atom.to_string(atom)
    underscore(rest)
  end

  defp underscore(<<h, t::binary>>) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp underscore("") do
    ""
  end

  defp do_underscore(<<h, t, rest::binary>>, _)
       when h >= ?A and h <= ?Z and not (t >= ?A and t <= ?Z) and not (t >= ?0 and t <= ?9) and
              t != ?. and t != ?_ do
    <<?_, to_lower_char(h), t>> <> do_underscore(rest, t)
  end

  defp do_underscore(<<h, t::binary>>, prev)
       when h >= ?A and h <= ?Z and not (prev >= ?A and prev <= ?Z) and
              not (prev >= ?0 and prev <= ?9) and prev != ?_ do
    <<?_, to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<?., t::binary>>, _) do
    <<?/>> <> underscore(t)
  end

  defp do_underscore(<<h, t::binary>>, _) do
    <<to_lower_char(h)>> <> do_underscore(t, h)
  end

  defp do_underscore(<<>>, _) do
    <<>>
  end

  defp to_lower_char(char) when char >= ?A and char <= ?Z do
    char + 32
  end

  defp to_lower_char(char) do
    char
  end
end
