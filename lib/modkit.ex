defmodule Modkit do
  alias Modkit.Mount
  alias Modkit.SnakeCase

  def load_current_project do
    config = Mix.Project.config()
    otp_app = Keyword.fetch!(config, :app)
    default_root = main_module_from_current_project()

    mount =
      case get_in(config, [:modkit, :mount]) do
        nil -> Mount.define!(default_mount(otp_app, default_root, config))
        v -> Mount.define!(v)
      end

    %{otp_app: otp_app, mount: mount}
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
