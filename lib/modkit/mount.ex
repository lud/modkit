defmodule Modkit.Mount do
  alias Modkit.SnakeCase
  @flavors [:elixir, :phoenix, :mix_task]

  defmodule Point do
    @enforce_keys [
      # This is the atom prefix name given in configuration
      :prefix,

      # This is the splitted version of the prefix, containing binaries
      :pre_split,

      # This is the mount path for the prefix.
      :path,

      # This is the used flavor
      :flavor
    ]

    defstruct @enforce_keys
  end

  @enforce_keys [:points, :to_snake]
  defstruct @enforce_keys

  def define!(points, opts \\ [])

  def define!(points, opts) when is_list(points) do
    to_snake =
      case opts[:names] do
        nil -> &SnakeCase.to_snake/1
        names -> fn segment -> SnakeCase.to_snake(segment, names: names) end
      end

    %__MODULE__{points: build_points(points), to_snake: to_snake}
  end

  def define!(other, _opts) do
    raise ArgumentError, ":mount config option must be a list of tuples, got: #{inspect(other)}"
  end

  def define(raw_points, opts \\ [])

  def define(points, opts) do
    {:ok, define!(points, opts)}
  rescue
    e -> {:error, e}
  end

  defp build_points(raw_points) do
    raw_points
    |> Enum.map(&define_point!/1)
    |> Enum.sort(&sort_points/2)
  end

  defp define_point!({prefix, path} = p)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) do
    define_point!(prefix, path, [], p)
  end

  defp define_point!({prefix, path, opts} = p)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) and is_list(opts) do
    define_point!(prefix, path, opts, p)
  end

  defp define_point!(other) do
    invalid_point!(other)
  end

  defp define_point!(prefix, path, opts, original)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) and is_list(opts) do
    flavor = Keyword.get(opts, :flavor, :elixir)

    case validate(flavor in @flavors, {:invalid_flavor, flavor}) do
      :ok -> %Point{prefix: prefix, path: path, pre_split: Module.split(prefix), flavor: flavor}
      {:error, reason} -> invalid_point!(original, reason)
    end
  end

  defp define_point!(_, _, _, original) do
    invalid_point!(original)
  end

  @spec invalid_point!(term) :: no_return()
  defp invalid_point!(point) do
    raise ArgumentError, "invalid point in :mount config option, got: #{inspect(point)}"
  end

  @spec invalid_point!(term, term) :: no_return()
  defp invalid_point!(point, reason) do
    raise ArgumentError,
          "invalid point in :mount config option, got: #{inspect(point)}, error: #{inspect(reason)}"
  end

  defp sort_points(%{pre_split: a}, %{pre_split: b}) do
    # higher precision goes first
    a > b
  end

  def resolve(%__MODULE__{} = mount, mod_split) do
    resolve(mount.points, mod_split)
  end

  def resolve(points, module) when is_atom(module) do
    resolve(points, Module.split(module))
  end

  def resolve(points, mod_split) do
    do_resolve(points, mod_split)
  end

  def do_resolve([p | points], mod_split) when is_list(mod_split) do
    if prefix_of?(p, mod_split) do
      case p do
        %{path: :ignore} -> :ignore
        _ -> {:ok, p}
      end
    else
      do_resolve(points, mod_split)
    end
  end

  def do_resolve([], mod_split) when is_list(mod_split) do
    {:error, :not_mounted}
  end

  def prefix_of?(%{pre_split: pre_split}, mod_split) do
    List.starts_with?(mod_split, pre_split)
  end

  defp validate(true, _) do
    :ok
  end

  defp validate(false, reason) do
    {:error, reason}
  end

  def preferred_path(%__MODULE__{} = mount, module) when is_atom(module) do
    with {:ok, mod_split} <- split_mod(module),
         {:ok, point} <- resolve(mount, mod_split) do
      {:ok, point_to_path(point, mod_split, mount.to_snake)}
    end
  end

  defp point_to_path(point, mod_split, to_snake) do
    path_rest = unprefix(mod_split, point.pre_split)
    sub_path = path_segments(path_rest, point.flavor, to_snake)

    Path.join(:lists.flatten([point.path, sub_path])) <> ".ex"
  end

  defp split_mod(module) do
    {:ok, Module.split(module)}
  rescue
    _ in ArgumentError -> {:error, :not_elixir}
  end

  defp unprefix([a | modrest], [a | prefrest]) do
    unprefix(modrest, prefrest)
  end

  defp unprefix(modrest, []) do
    modrest
  end

  defp path_segments(segments, :mix_task, to_snake) do
    Enum.map_join(segments, ".", to_snake)
  end

  defp path_segments([segment | rest], flavor, to_snake) do
    [format_segment(segment, flavor, to_snake) | path_segments(rest, flavor, to_snake)]
  end

  defp path_segments([], _, _) do
    []
  end

  defp format_segment(segment, :elixir, to_snake) do
    to_snake.(segment)
  end

  defp format_segment(segment, :phoenix, to_snake) do
    basename = format_segment(segment, :elixir, to_snake)

    matchers = [
      {fn -> segment == "Layouts" end, ["components", basename]},
      {fn -> String.ends_with?(segment, "Component") end, ["components", basename]},
      {fn -> String.ends_with?(segment, "Components") end, ["components", basename]},
      # controllers
      {fn -> String.ends_with?(segment, "Controller") end, ["controllers", basename]},
      {fn -> String.ends_with?(segment, "HTML") end, ["controllers", basename]},
      {fn -> String.ends_with?(segment, "JSON") end, ["controllers", basename]},
      # live
      {fn -> String.ends_with?(segment, "Live") end, ["live", basename]},
      # views
      {fn -> String.ends_with?(segment, "View") end, ["views", basename]},
      # channels
      {fn -> String.ends_with?(segment, "Channel") end, ["channels", basename]},
      {fn -> String.ends_with?(segment, "Socket") end, ["channels", basename]}
    ]

    found =
      Enum.find(matchers, fn {match, result} ->
        if match.() do
          result
        else
          nil
        end
      end)

    case found do
      {_, result} -> result
      nil -> basename
    end
  end
end
