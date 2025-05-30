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

  def define!(points) do
    case define(points) do
      {:ok, mount} -> mount
      {:error, reason} when is_binary(reason) -> raise ArgumentError, message: reason
    end
  end

  def define([]) do
    {:ok, []}
  end

  def define(raw_points) when is_list(raw_points) do
    raw_points
    |> Enum.reduce_while([], fn raw, acc ->
      case define_point(raw) do
        {:ok, point} -> {:cont, [point | acc]}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err -> err
      points -> {:ok, Enum.sort(points, &sort_points/2)}
    end
  end

  def define(other) do
    {:error, ":mount config option must be a list of points, got: #{inspect(other)}"}
  end

  def define_point({prefix, path} = p)
      when is_atom(prefix) and (is_binary(path) or path == :ignore) do
    define_point(prefix, path, [], p)
  end

  def define_point({prefix, path, opts} = p)
      when is_atom(prefix) and (is_binary(path) or path == :ignore) and is_list(opts) do
    define_point(prefix, path, opts, p)
  end

  def define_point(other) do
    invalid_point(other)
  end

  defp define_point(prefix, path, opts, original)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) and is_list(opts) do
    flavor = Keyword.get(opts, :flavor, :elixir)

    case validate(flavor in @flavors, {:invalid_flavor, flavor}) do
      :ok ->
        {:ok, %Point{prefix: prefix, path: path, pre_split: Module.split(prefix), flavor: flavor}}

      {:error, reason} ->
        invalid_point(original, reason)
    end
  end

  defp define_point(_, _, _, original) do
    invalid_point(original)
  end

  defp invalid_point(point) do
    {:error, "invalid point in :mount config option, got: #{inspect(point)}"}
  end

  defp invalid_point(point, reason) do
    {:error,
     "invalid point in :mount config option, got: #{inspect(point)}, error: #{inspect(reason)}"}
  end

  defp sort_points(%{pre_split: a}, %{pre_split: b}) do
    # higher precision goes first
    a > b
  end

  def resolve(mount, module) when is_atom(module) do
    resolve(mount, Module.split(module))
  end

  def resolve([p | points], mod_split) when is_list(mod_split) do
    if prefix_of?(p, mod_split) do
      case p do
        %{path: :ignore} -> :ignore
        _ -> {:ok, p}
      end
    else
      resolve(points, mod_split)
    end
  end

  def resolve([], mod_split) when is_list(mod_split) do
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

  def preferred_path(mount, module) when is_atom(module) do
    with {:ok, modsplit} <- split_mod(module),
         {:ok, point} <- resolve(mount, modsplit) do
      path_rest = unprefix(modsplit, point.pre_split)
      sub_path = create_path(path_rest, point.flavor)
      path = Path.join(:lists.flatten([point.path, sub_path])) <> ".ex"
      {:ok, path}
    end
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

  defp create_path(segments, flavor) do
    do_create_path(segments, flavor)
  end

  defp do_create_path(segments, :mix_task) do
    Enum.map_join(segments, ".", &SnakeCase.to_snake/1)
  end

  defp do_create_path([segment | rest], flavor) do
    [path_segment(segment, flavor) | create_path(rest, flavor)]
  end

  defp do_create_path([], _) do
    []
  end

  defp path_segment(segment, :elixir) do
    SnakeCase.to_snake(segment)
  end

  defp path_segment(segment, :phoenix) do
    basename = path_segment(segment, :elixir)

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

  defp path_segment(segment, :mix_task) do
    path_segment(segment, :elixir)
  end
end
