defmodule Mix.Tasks.Mod.New do
  alias Modkit.CLI
  alias Modkit.Mod.Template
  alias Modkit.Mount
  use Mix.Task

  @shortdoc "Creates a new module in the current application"

  @command [
    module: __MODULE__,
    options: [
      template: [
        type: :string,
        short: :t,
        doc: "Use the given template. A path to an .eex file or a built-in template."
      ],
      test: [
        type: :boolean,
        short: :u,
        doc: "Create a unit test module for the generated module.",
        default: false
      ],
      test_only: [
        type: :boolean,
        short: :U,
        doc: "Create the unit test only, without generating the module.",
        default: false
      ],
      # mix_task: [type: :boolean, short: :t, doc: "create a new mix task", default: false],
      # unit_test: [type: :boolean, short: :u, doc: "create a new unit test", default: false],
      path: [
        type: :string,
        short: :p,
        doc: "The path of the module to write. Unnecessary if the module prefix is mounted."
      ],
      overwrite: [
        type: :boolean,
        short: :o,
        doc: "Overwrite the file if it exists. Always prompt.",
        default: false
      ]
    ],
    arguments: [
      module: [cast: {__MODULE__, :cast_mod, []}]
    ]
  ]

  @moduledoc """
  Creates a new module in the current application, based on a template.

  The location of the new module is defined  according to the `:mount` option in
  `:modkit` configuration defined in the project file (`mix.exs`).

  If not defined, default mount points are defined as follows:

      [
        {App, "lib/app"}
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

  #{CLI.format_usage(@command, format: :moduledoc)}
  """

  @impl Mix.Task
  def run(argv) do
    CLI.with_safe_path(:modkit, fn -> Mix.Task.run("app.config") end)

    command = CLI.parse_or_halt!(argv, @command)

    %{mount: mount} = Modkit.load_current_project() |> dbg()
    %{options: options, arguments: arguments} = command
    options = expand_options(options) |> dbg()
    module = arguments.module
    template = find_template(options)

    path = resolve_path(module, mount, options)

    rendered = Template.render(module, template: template)

    can_write? =
      cond do
        not File.exists?(path) -> true
        options.overwrite -> true
        Mix.shell().yes?("File #{path} exists, overwrite?", default: :no) -> true
        :_ -> false
      end

    if can_write? do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, rendered)
      CLI.halt_success("Wrote module #{inspect(module)} to #{path}")
    else
      CLI.writeln("cancelled")
    end
  end

  defp expand_options(options) do
    Map.put(options, :generate_mod, not options.test_only)
  end

  defp find_template(_options) do
    cond do
      true -> Template.BaseModule.template()
    end
  end

  defp resolve_path(module, mount, options) do
    if Map.has_key?(options, :path) do
      Map.fetch!(options, :path)
    else
      case Mount.preferred_path(mount, module) do
        {:ok, path} ->
          path

        {:error, :not_mounted} ->
          CLI.halt_error(
            "Could not figure out path for module #{inspect(module)}. Please provide the --path option."
          )
      end
    end
  end

  @doc false
  def cast_mod(v) do
    {:ok, Module.concat([v])}
  end
end
