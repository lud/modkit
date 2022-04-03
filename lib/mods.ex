defmodule Modkit.Mod do
  def get_preferred_path(module, mount_points, cwd)
      when is_atom(module) and is_list(mount_points) and is_binary(cwd) do
    binding |> IO.inspect(label: "binding", pretty: true)
  end
end
