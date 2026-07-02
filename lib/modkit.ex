defmodule Modkit do
  @moduledoc """
  Loads the modkit configuration of a Mix project.

  The Mix tasks `mix mod.relocate` and `mix mod.new` call
  `load_current_project/0` to know where the module files of the project belong.
  The returned project map contains the OTP application name, the mount built
  from the `:modkit` configuration (see `Modkit.Mount`), and the application
  directory.
  """

  alias Modkit.Mount
  alias Modkit.SnakeCase

  @doc """
  Loads the project map of the current Mix project.

  The default root module is derived from the project module in `mix.exs`, so
  `MyApp.MixProject` gives `MyApp`. See `load_project/3` for the contents of the
  project map.
  """
  def load_current_project do
    load_project(main_module_from_current_project(), Mix.Project.config())
  end

  @doc """
  Builds a project map from a Mix project configuration.

  Accepts the root module used for the default mount points, a project
  configuration such as returned by `Mix.Project.config/0`, and options. Returns
  a map with the following keys:

  * `:otp_app` - the `:app` value of the configuration.
  * `:mount` - a `Modkit.Mount` struct built from the `:mount` entry of the
    `:modkit` configuration. When that entry is missing, the root module is
    mounted on the application code directory (as in `{MyApp, "lib/my_app"}`)
    and `Mix.Tasks` is mounted on `lib/mix/tasks` with the `:mix_task` flavor.
  * `:app_dir` - the application directory.

  ### Options

  * `:app_dir` - the application directory to use in the project map. Defaults
    to the current working directory.
  """
  def load_project(default_root, config, opts \\ []) do
    otp_app = Keyword.fetch!(config, :app)

    names = get_in(config, [:modkit, :names])

    mount_points =
      case get_in(config, [:modkit, :mount]) do
        nil -> default_mount(otp_app, default_root, config)
        v -> v
      end

    mount = Mount.define!(mount_points, names: names)

    # Option used for demo-app in tests
    app_dir =
      case opts[:app_dir] do
        nil -> File.cwd!()
        dir -> Path.absname(dir)
      end

    %{otp_app: otp_app, mount: mount, app_dir: app_dir}
  end

  defp main_module_from_current_project do
    Mix.Project.get!()
    |> Module.split()
    |> Enum.slice(0..-2//1)
    |> Module.concat()
  end

  defp default_mount(otp_app, default_root_mod, config) do
    [first_path | _] = elixirc_paths = Keyword.fetch!(config, :elixirc_paths)
    lib_path = Enum.find(elixirc_paths, first_path, &(&1 == "lib"))

    # Here we use the OTP app name instead of the default root module name
    # because the apps generated with `mix new` will create that path by
    # default.
    app_code_path =
      Path.join(
        lib_path,
        otp_app |> Atom.to_string() |> SnakeCase.to_snake()
      )

    mix_tasks_path = Path.join([lib_path, "mix", "tasks"])

    [
      {default_root_mod, app_code_path, flavor: :elixir},
      {Mix.Tasks, mix_tasks_path, flavor: :mix_task}
    ]
  end
end
