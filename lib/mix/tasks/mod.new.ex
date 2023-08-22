defmodule Mix.Tasks.Mod.New do
  alias Modkit.Mod.Template
  alias Modkit.Mount
  alias Modkit.CLI
  use Mix.Task

  @shortdoc "Relocate all modules in the current application"

  @command [
    module: __MODULE__,
    options: [
      gen_server: [
        type: :boolean,
        short: :g,
        doc: "use GenServer and define base functions",
        default: false
      ],
      supervisor: [
        type: :boolean,
        short: :s,
        doc: "use Supervisor and define base functions",
        default: false
      ],
      dynamic_supervisor: [
        type: :boolean,
        short: :d,
        doc: "use DynamicSupervisor and define base functions",
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
    command = CLI.parse_or_halt!(argv, @command)

    %{mount: mount} = Modkit.load_current_project()
    %{options: options, arguments: arguments} = command
    options = check_exclusive_opts(options)
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

  defp check_exclusive_opts(options) do
    exclusive = %{
      gen_server: "--gen-server",
      supervisor: "--supervisor",
      mix_task: "--mix-task",
      unit_test: "--unit-test",
      dynamic_supervisor: "--dynamic-supervisor"
    }

    provided =
      options
      |> Map.take(Map.keys(exclusive))
      |> Map.filter(fn {_, enabled} -> enabled == true end)
      |> Map.keys()

    case provided do
      [] ->
        options

      [_single] ->
        options

      [top | rest] ->
        rest
        |> Enum.map(&Map.fetch!(exclusive, &1))
        |> Enum.intersperse(", ")
        |> Kernel.++([" and ", Map.fetch!(exclusive, top), " options are mutually exclusive"])
        |> CLI.halt_error()
    end
  end

  defp find_template(options) do
    cond do
      options.gen_server -> Template.GenServerTemplate
      options.supervisor -> Template.SupervisorTemplate
      options.dynamic_supervisor -> Template.DynamicSupervisorTemplate
      # options.mix_task -> Template.MixTaskTemplate
      # options.unit_test -> Template.UnitTestTemplate
      true -> Template.BaseModule
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
