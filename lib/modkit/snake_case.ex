defmodule Modkit.SnakeCase do
  def to_snake(segment, opts \\ []) when is_binary(segment) when is_atom(segment) do
    segment
    |> as_string()
    |> replace_names(opts[:names] || [])
    |> Macro.underscore()
    |> trim_leading_underscores()
    |> remove_double_underscores()
  end

  defp as_string(v) when is_binary(v) do
    v
  end

  defp as_string(a) when is_atom(a) do
    case Atom.to_string(a) do
      "Elixir." <> rest -> rest
      v -> v
    end
  end

  defp replace_names(base, names) do
    names
    |> Enum.map(fn {matcher, name} -> {as_string(matcher), "_" <> name} end)
    |> Enum.reduce(base, fn {matcher, name}, word -> String.replace(word, matcher, name) end)
  end

  # remove underscores from the start of the name
  defp trim_leading_underscores(<<"_", rest::binary>>) do
    trim_leading_underscores(rest)
  end

  defp trim_leading_underscores(segment) do
    segment
  end

  defp remove_double_underscores(<<"_", "_", rest::binary>>) do
    remove_double_underscores(<<"_", rest::binary>>)
  end

  defp remove_double_underscores(<<"_", rest::binary>>) do
    <<"_", remove_double_underscores(rest)::binary>>
  end

  defp remove_double_underscores(<<c::utf8, rest::binary>>) do
    <<c, remove_double_underscores(rest)::binary>>
  end

  defp remove_double_underscores(<<>>) do
    <<>>
  end
end
