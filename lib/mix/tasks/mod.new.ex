defmodule Mix.Tasks.Mod.New do
  alias Modkit.CLI
  alias Modkit.Mod
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
        doc: """
        Use the given template for the module code.

        Accepts a path to an .eex file or a built-in template:

        #{Enum.map_intersperse(Template.public_names(), ", ", &[?`, &1, ?`])}.
        """
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
      path: [
        type: :string,
        short: :p,
        doc:
          "The path of the module file to write (must end with .ex). Only applies to the module file; when --test/--test-only is given, the test file path is derived from it. Unnecessary if the module prefix is mounted."
      ],
      overwrite: [
        type: :boolean,
        short: :o,
        doc: "Overwrite existing files.",
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
    project = Modkit.load_current_project()
    %{options: options, arguments: %{module: module}} = command
    options = expand_options(options)

    case generate(project, module, options) do
      {:ok, paths} ->
        CLI.halt_success([
          "Wrote module #{inspect(module)}:\n",
          Enum.map(paths, fn p -> ["  ", p, "\n"] end)
        ])

      {:error, {:exists, paths}} ->
        CLI.halt_error([
          "Eexisting files found:\n",
          Enum.map(paths, fn p -> ["- ", p, "\n"] end),
          "\n",
          "Use --overwrite option to ignore."
        ])

      {:error, {:template_not_found, template}} ->
        CLI.halt_error([
          "No template found matching ",
          inspect(template),
          ".\n",
          "Neither a built-in template nor a file could be found.\n\n",
          "Built-in templates:\n",
          Enum.map(Template.public_names(), fn name -> ["  - ", name, "\n"] end)
        ])

      {:error, :not_mounted} ->
        CLI.halt_error(
          "Could not figure out path for module #{inspect(module)}. Please provide the --path option."
        )

      {:error, {:ignored_mount, ignored_module}} ->
        CLI.halt_error(
          "Module #{inspect(ignored_module)} resolves to an :ignore mount point. Please provide the --path option."
        )

      {:error, {:path_outside_app_dir, bad_path}} ->
        CLI.halt_error(
          "The --path #{bad_path} is not under the application directory. Use a path relative to the project root, or an absolute path inside it."
        )

      {:error, {:invalid_path_extension, bad_path}} ->
        CLI.halt_error("The --path #{bad_path} must end with .ex.")

      {:error, reason} ->
        CLI.halt_error(inspect(reason))
    end
  end

  defp expand_options(options) do
    Map.merge(options, %{
      generate_mod: not options.test_only,
      generate_test: options.test or options.test_only
    })
  end

  def generate(project, module, options) do
    with {:ok, template} <- find_template(options),
         {:ok, generations} <- build_generations(project, module, template, options),
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
      {formatter, _} = Mix.Tasks.Format.formatter_for_file(path)
      formatted = formatter.(rendered)

      with :ok <- File.mkdir_p(Path.dirname(path)),
           :ok <- write_file(path, formatted) do
        {:cont, {:ok, [path | written_paths]}}
      else
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp write_file(path, content) do
    File.write(path, content)
    # IO.puts([IO.ANSI.magenta(), "write file #{path} (skipped)", IO.ANSI.reset()])
  end

  defp build_generations(project, module, template, options) do
    arg = {project, module, template, options}

    builders =
      Enum.filter(
        [
          options.generate_test && (&build_test_generation/1),
          options.generate_mod && (&build_mod_generation/1)
        ],
        & &1
      )

    Enum.reduce_while(builders, {:ok, []}, fn builder, {:ok, acc} ->
      case builder.(arg) do
        {:ok, gen} -> {:cont, {:ok, [gen | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp build_mod_generation({project, module, template, options}) do
    case resolve_path(module, project.mount, options) do
      {:ok, path} ->
        path = Path.join(project.app_dir, path)
        {:ok, {module, template, path, %{module: module}}}

      :ignore ->
        {:error, {:ignored_mount, module}}

      {:error, _} = err ->
        err
    end
  end

  defp build_test_generation({project, module, _template, %{path: mod_path}}) do
    with {:ok, rel} <- relative_to_app_dir(mod_path, project.app_dir),
         {:ok, test_rel} <- derive_test_path(rel) do
      test_path = Path.join(project.app_dir, test_rel)
      test_module = Mod.as_test(module)

      {:ok,
       {test_module, Template.unit_test_template(), test_path,
        %{module: module, test_module: test_module}}}
    end
  end

  defp build_test_generation({project, module, _template, _options}) do
    test_module = Mod.as_test(module)
    test_mount = Mount.as_test(project.mount)

    case resolve_path(test_module, test_mount, _no_path_options = %{}) do
      {:ok, test_path} ->
        test_path = Path.join(project.app_dir, test_path)

        {:ok,
         {test_module, Template.unit_test_template(), test_path,
          %{module: module, test_module: test_module}}}

      :ignore ->
        {:error, {:ignored_mount, module}}

      {:error, _} = err ->
        err
    end
  end

  defp relative_to_app_dir(path, app_dir) do
    case Path.type(path) do
      :relative ->
        {:ok, path}

      :absolute ->
        abs_app = Path.expand(app_dir)
        abs_path = Path.expand(path)

        cond do
          abs_path == abs_app ->
            {:error, {:path_outside_app_dir, path}}

          String.starts_with?(abs_path, abs_app <> "/") ->
            {:ok, Path.relative_to(abs_path, abs_app)}

          true ->
            {:error, {:path_outside_app_dir, path}}
        end
    end
  end

  defp derive_test_path(rel_path) do
    case Path.extname(rel_path) do
      ".ex" ->
        rootname = Path.rootname(rel_path, ".ex")
        {:ok, Mount.path_as_test(rootname) <> ".exs"}

      _ ->
        {:error, {:invalid_path_extension, rel_path}}
    end
  end

  defp find_template(%{template: template}) do
    case Template.fetch(template) do
      {:ok, content} ->
        {:ok, content}

      :error ->
        case File.read(template) do
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
    {:ok, Template.base_template()}
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

  defp check_overwrite(generations, _opts) do
    case (for {_, _, path, _} <- generations, File.exists?(path) do
            path
          end) do
      [] -> :ok
      existing -> {:error, {:exists, existing}}
    end
  end

  @doc false
  def cast_mod(v) do
    {:ok, Module.concat([v])}
  end
end
