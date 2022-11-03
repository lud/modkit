defmodule Mix.Tasks.Mod.New do
  use Mix.Task

  @shortdoc "Create a new module in the current application"

  import Modkit.Cli

  def run(argv) do
    Mix.Task.run("app.config")

    {opts, args} =
      command(__MODULE__)
      |> option(:gen_server, :boolean,
        alias: :g,
        doc: "use GenServer and define base functions",
        default: false
      )
      |> option(:supervisor, :boolean,
        alias: :s,
        doc: "use Supervisor and define base functions",
        default: false
      )
      |> option(:dynamic_supervisor, :boolean,
        alias: :d,
        doc: "use DynamicSupervisor and define base functions",
        default: false
      )
      |> option(:mix_task, :boolean,
        alias: :t,
        doc: "create a new mix task",
        default: false
      )
      |> option(:path, :string,
        alias: :p,
        doc: "The path of the module to write. Unnecessary if the module prefix is mounted."
      )
      |> option(:overwrite, :boolean,
        alias: :o,
        doc: "Overwrite the file if it exists. Always prompt.",
        default: false
      )
      |> argument(:module, required: true, cast: &Module.concat([&1]))
      |> parse(argv)

    opts =
      opts
      |> check_exclusive_opts()
      |> add_path_opt(args.module)

    parts_init = %{uses: [], attrs: [], apis: [], impls: [], top_docs: [default_moduledoc()]}

    parts =
      opts
      |> Map.take([:gen_server, :supervisor, :mix_task, :dynamic_supervisor])
      |> Enum.filter(fn {_kind, enabled?} -> enabled? end)
      |> Keyword.keys()
      |> Enum.reduce(parts_init, &collect_parts/2)

    code =
      assemble_parts(args.module, parts)
      |> :erlang.iolist_to_binary()
      |> Code.format_string!(formatter_opts())

    write_code(opts, code)
    success_stop("wrote code to #{opts.path}")
  end

  defp write_code(%{path: path, overwrite: over?}, code) do
    if can_write?(path, over?) do
      :ok = ensure_dir(Path.dirname(path))
      File.write!(path, code)
    else
      abort("file exists: #{path}")
    end
  end

  defp ensure_dir(path) do
    if File.dir?(path) do
      :ok
    else
      ensure_dir(Path.dirname(path))
      File.mkdir!(path)
    end
  end

  defp can_write?(path, prompt?) do
    if File.exists?(path) do
      if prompt? do
        Mix.Shell.IO.yes?("Overwrite file #{path}?", default: :no)
      else
        false
      end
    else
      true
    end
  end

  defp check_exclusive_opts(opts) do
    exclusive = %{
      gen_server: "--gen-server",
      supervisor: "--supervisor",
      mix_task: "--mix-task"
    }

    provided =
      opts
      |> Map.take(Map.keys(exclusive))
      |> Map.filter(fn {_, enabled} -> enabled == true end)
      |> Map.keys()

    case provided do
      [] ->
        opts

      [_single] ->
        opts

      [top | rest] ->
        rest
        |> Enum.map(&Map.fetch!(exclusive, &1))
        |> Enum.intersperse(", ")
        |> Kernel.++([" and ", Map.fetch!(exclusive, top), " are mutually exclusive"])
        |> abort
    end
  end

  defp add_path_opt(%{path: path} = opts, _) when is_binary(path),
    do: opts

  defp add_path_opt(opts, module) do
    # Use the preferred path if mounted or abort

    project = Modkit.Config.current_project()
    mount = Modkit.Config.mount(project)

    case Modkit.Mod.preferred_path(module, mount) do
      {:error, :no_mount_point} ->
        sample_config = Modkit.Config.project_get(project, [:modkit], [])
        new_mount = {module, "lib/path/to/#{Modkit.PathTool.to_snake(module)}"}

        new_conf =
          Keyword.update(sample_config, :mount, [new_mount], fn kw -> kw ++ [new_mount] end)

        abort("""
        The --path option is required when the module prefix is not mounted.

        Please export a mount point from project/0 for the following prefix in mix.exs:

            def project do
              [
                app: #{inspect(Modkit.Config.otp_app(project))},
                # ...
                # ...
                modkit: modkit()
              ]
            end

            defp modkit do
              #{indent(inspect(new_conf, pretty: true), 6)}
            end
        """)

      {:ok, path} ->
        Map.put(opts, :path, path)
    end
  end

  defp indent(text, count) do
    spaces = String.duplicate(" ", count)

    text
    |> String.split("\n")
    |> Enum.map_join("\n", &[spaces, &1])
    |> String.trim()
  end

  defp default_moduledoc do
    ~S(
      @moduledoc """
      TODO Start documenting the module by writing a short description of its purpose.
      """
    )
  end

  def collect_parts(:gen_server, parts) do
    parts
    |> add_part(:uses, "use GenServer")
    |> add_part(:attrs, "@gen_opts ~w(name timeout debug spawn_opt hibernate_after)a")
    |> add_part(:apis, """
        def start_link(opts) do
          {gen_opts, opts} = Keyword.split(opts, @gen_opts)
          GenServer.start_link(__MODULE__, opts, gen_opts)
        end
    """)
    |> add_part(:apis, """
        @impl GenServer
        def init(opts) do
          {:ok, opts}
        end
    """)
  end

  def collect_parts(:supervisor, parts) do
    parts
    |> add_part(:uses, "use Supervisor")
    |> add_part(:apis, """
        def start_link(arg) do
          Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
        end
    """)
    |> add_part(:apis, """
        @impl Supervisor
        def init(_init_arg) do
          children = [
            {Worker, key: :value}
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end
    """)
  end

  def collect_parts(:dynamic_supervisor, parts) do
    parts
    |> add_part(:uses, "use DynamicSupervisor")
    |> add_part(:attrs, "@gen_opts ~w(name)a")
    |> add_part(:apis, """
        def start_link(opts) do
          {gen_opts, opts} = Keyword.split(opts, @gen_opts)
          DynamicSupervisor.start_link(__MODULE__, opts, gen_opts)
        end
    """)
    |> add_part(:apis, """
        @impl DynamicSupervisor
        def init(_init_arg) do
          DynamicSupervisor.init(strategy: :one_for_one)
        end
    """)
  end

  defmodule Mix.Tasks.Echo do
  end

  def collect_parts(:mix_task, parts) do
    parts
    |> add_part(:top_docs, [
      ~S(@shortdoc "TODO short description of the task")
    ])
    |> add_part(:uses, "use Mix.Task")
    |> add_part(:apis, """
        @impl Mix.Task
        def run(argv) do
          # ...
        end
    """)
  end

  defp add_part(parts, group, code) do
    Map.update!(parts, group, &[code | &1])
  end

  defp assemble_parts(module, %{
         uses: uses,
         attrs: attrs,
         apis: apis,
         impls: impls,
         top_docs: top_docs
       }) do
    [uses, apis, impls, attrs, top_docs] = reverse_lists([uses, apis, impls, attrs, top_docs])

    [
      "defmodule #{inspect(module)} do",
      top_docs,
      uses,
      attrs,
      apis,
      impls,
      "end"
    ]
    |> :lists.flatten()
    |> Enum.intersperse("\n\n")
  end

  defp formatter_opts do
    file = ".formatter.exs"

    if File.regular?(file) do
      {opts, _} = Code.eval_file(file)
      opts
    else
      []
    end
  end

  defp reverse_lists([list | rest]) do
    [:lists.reverse(list) | reverse_lists(rest)]
  end

  defp reverse_lists([]) do
    []
  end
end
