defmodule Mix.Tasks.Mod.New do
  alias Modkit.Mod.Template.UnitTestTemplate
  alias Modkit.Mod
  alias Modkit.CLI
  alias Modkit.Mod.Template
  alias Modkit.Mod.Template.DynamicSupervisorTemplate
  alias Modkit.Mod.Template.GenServerTemplate
  alias Modkit.Mod.Template.MixTaskTemplate
  alias Modkit.Mod.Template.SupervisorTemplate
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

    # case  do
    #         {:ok, path} ->

    #         {:error, :not_mounted} ->
    #           CLI.halt_error(
    #             "Could not figure out path for module #{inspect(module)}. Please provide the --path option."
    #           )
    #       end

    # can_write? =
    #   cond do
    #     not File.exists?(path) -> true
    #     options.overwrite -> true
    #     Mix.shell().yes?("File #{path} exists, overwrite?", default: :no) -> true
    #     :_ -> false
    #   end

    # if can_write? do
    #   File.mkdir_p!(Path.dirname(path))
    #   File.write!(path, rendered)
    #   CLI.halt_success("Wrote module #{inspect(module)} to #{path}")
    # else
    #   CLI.writeln("cancelled")
    # end

    #     CLI.halt_success("Wrote module #{inspect(module)} to #{path}")
    # CLI.writeln("cancelled")
  end

  defp expand_options(options) do
    Map.merge(options, %{
      generate_mod: not options.test_only,
      generate_test: options.test or options.test_only
    })
  end

  def generate(%{mount: mount}, module, options) do
    with {:ok, template} <- find_template(options),
         {:ok, path} <- resolve_path(module, mount, options),
         {:ok, generations} <- build_generations(module, mount, template, path, options),
         :ok <- check_overwrite(generations, options) do
      write_generations(generations)
    else
      {:error, _} = err -> err
    end
  end

  defp write_generations(generations) do
    Enum.reduce_while(generations, {:ok, []}, fn gen, {:ok, written_paths} ->
      {_module, template, path, vars} = gen
      rendered = Template.render(template, vars)

      with :ok <- File.mkdir_p(Path.dirname(path)),
           :ok <- File.write(path, rendered) do
        {:cont, {:ok, [path | written_paths]}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp build_generations(module, mount, template, path, options) do
    generations =
      if options.generate_mod do
        [{module, template, path, %{module: module}}]
      else
        []
      end

    if options.generate_test do
      test_module = Mod.as_test(module)
      test_mount = Mount.as_test(mount)

      with {:ok, test_path} <- resolve_path(test_module, test_mount, %{}) do
        {:ok,
         [
           {test_module, UnitTestTemplate.template(), test_path,
            %{module: module, test_module: test_module}}
         ]}
      end
    else
      generations
    end
  end

  defp find_template(%{template: template}) do
    case template do
      "GenServer" ->
        {:ok, GenServerTemplate.template()}

      "Supervisor" ->
        {:ok, SupervisorTemplate.template()}

      "DynamicSupervisor" ->
        {:ok, DynamicSupervisorTemplate.template()}

      "Mix.Task" ->
        {:ok, MixTaskTemplate.template()}

      path ->
        case File.read(path) do
          {:ok, content} ->
            {:ok, content}

          {:error, :enoent} ->
            {:error, {:template_not_found, template}}

          {:error, _} = err ->
            err
        end
    end
  end

  defp find_template(_) do
    {:ok, Template.BaseModule.template()}
  end

  defp resolve_path(module, mount, options) do
    case options do
      %{path: path} -> {:ok, path}
      _ -> Mount.preferred_path(mount, module)
    end
  end

  defp check_overwrite(_, %{overwrite: true}) do
    :ok
  end

  defp check_overwrite(path, %{overwrite: false}) do
    if File.exists?(path) do
      File.read!(path) |> dbg()
      {:error, {:exists, path}} |> dbg()
    else
      :ok
    end
  end

  @doc false
  def cast_mod(v) do
    {:ok, Module.concat([v])}
  end
end
