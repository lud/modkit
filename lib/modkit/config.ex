defmodule Modkit.Config do
  def current_project do
    Mix.Project.config()
  end

  def otp_app(project) do
    project_get(project, :app)
  end

  def mount(project) do
    mount = project_get(project, [:modkit, :mount], nil) || default_mount(project)

    Modkit.Mount.from_points(mount)
  end

  defp main_module_from_current_project() do
    Mix.Project.get!()
    |> Module.split()
    |> :lists.reverse()
    |> then(fn ["MixProject" | rest] -> rest end)
    |> :lists.reverse()
    |> Module.concat()
  end

  defp default_mount(project) do
    app_mod = main_module_from_current_project()

    [first_path | _] = elixirc_paths = project_get(project, :elixirc_paths)

    base_path = Enum.find(elixirc_paths, first_path, &(&1 == "lib"))

    # here we use the OTP app instead of the to_sname/1 function because the
    # apps generated with `mix new` will create that path by default. The module
    # to snake path conversion does not mirror exactly the snake to module
    # conversion.
    app_code_path =
      Path.join(
        base_path,
        project |> otp_app() |> Atom.to_string() |> Modkit.PathTool.to_snake()
      )

    mix_tasks_path = Path.join(base_path, "mix/tasks")

    [
      {app_mod, app_code_path},
      {Mix.Tasks, {:mix_task, mix_tasks_path}}
    ]
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
