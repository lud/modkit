defmodule Modkit.Mod do
  alias Modkit.Mount
  alias Modkit.Mount.Point

  def get_preferred_path(module, mount, cwd) when is_atom(module) and is_binary(cwd) do
    modsplit = Module.split(module)

    case Enum.find(mount.points, &Point.prefix_of?(&1, modsplit)) do
      %Point{} = point -> {:ok, build_preferred_path(modsplit, point, cwd)}
      nil -> {:error, :no_mount_moint}
    end
  end

  @spec build_preferred_path([binary], Point.t(), binary) :: binary
  defp build_preferred_path(modsplit, point, cwd) do
    modsplit = remove_prefix(modsplit, point.splitfix)
    sub_path = create_path(modsplit, point.flavor)
    Path.join(:lists.flatten([cwd, point.path, sub_path])) <> ".ex"
  end

  defp remove_prefix([a | modrest], [a | prefrest]) do
    remove_prefix(modrest, prefrest)
  end

  defp remove_prefix(modrest, []) do
    modrest
  end

  defp create_path([], _),
    do: []

  defp create_path([segment | rest], flavor),
    do: [path_segment(segment, flavor) | create_path(rest, flavor)]

  defp path_segment(segment, :elixir), do: Macro.underscore(segment)
end
