defmodule Modkit.Config do
  def current_project do
    Mix.Project.config()
  end

  def otp_app(project) do
    project_get(project, :app)
  end

  def mount(project) do
    project
    |> project_get([:modkit, :mount], default_mount(project))
    |> Modkit.Mount.from_points()
  end

  defp default_mount(project) do
    [base_path | _] = project_get(project, :elixirc_paths)

    app_mod =
      Mix.Project.get!()
      |> Module.split()
      |> :lists.reverse()
      |> case do
        ["MixProject" | rest] -> rest
      end
      |> :lists.reverse()
      |> Module.concat()

    mount_path = Path.join(base_path, Macro.underscore(app_mod))
    [{app_mod, mount_path}]
  end

  # -- Data reader ------------------------------------------------------------

  def project_get(mod, key_or_path) do
    _project_get(mod, key_or_path)
  end

  def project_get(mod, key_or_path, default) do
    _project_get(mod, key_or_path)
  rescue
    _ in KeyError -> default
  end

  defp _project_get(project, key) when is_atom(key) do
    project_get(project, [key])
  end

  defp _project_get(project, keys) when is_list(project) do
    fetch_in!(project, keys)
  end

  defp fetch_in!(data, []) do
    data
  end

  defp fetch_in!(data, [key | keys]) when is_list(data) do
    sub_data = Keyword.fetch!(data, key)
    fetch_in!(sub_data, keys)
  end
end
