defmodule Modkit.Mod do
  alias Modkit.Mount
  alias Modkit.Mount.Point

  def get_preferred_path(module, mount) when is_atom(module) do
    modsplit = Module.split(module)

    case Enum.find(mount.points, &Point.prefix_of?(&1, modsplit)) do
      %Point{} = point -> {:ok, build_preferred_path(modsplit, point)}
      nil -> {:error, :no_mount_point}
    end
  end

  @spec build_preferred_path([binary], Point.t()) :: binary
  defp build_preferred_path(modsplit, point) do
    modsplit = unprefix(modsplit, point.splitfix)
    sub_path = create_path(modsplit, point.flavor)
    Path.join(:lists.flatten([point.path, sub_path])) <> ".ex"
  end

  defp unprefix([a | modrest], [a | prefrest]) do
    unprefix(modrest, prefrest)
  end

  defp unprefix(modrest, []) do
    modrest
  end

  defp create_path([], _),
    do: []

  defp create_path([segment | rest], flavor),
    do: [path_segment(segment, flavor) | create_path(rest, flavor)]

  defp path_segment(segment, :elixir), do: Macro.underscore(segment)

  def list(project \\ Modkit.Config.current_project()) do
    app = Modkit.Config.otp_app(project)

    case :application.get_key(app, :modules) do
      {:ok, mods} ->
        mods

      :undefined ->
        raise ArgumentError, """
        could not list modules from app.

        Are you in a mix project?
        """
    end
  end

  def get_current_path(module, relative_to \\ File.cwd!()) do
    source = Keyword.fetch!(module.module_info(:compile), :source) |> List.to_string()
    Path.relative_to(source, relative_to)
  end
end