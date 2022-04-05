defmodule Mix.Tasks.Mod.New do
  use Mix.Task

  @shortdoc "Create a new module in the current application"

  import Modkit.Cli

  def run(argv) do
    Mix.Task.run("app.config")

    {opts, args} =
      task(__MODULE__)
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
      |> option(:path, :string,
        alias: :p,
        doc: "The path of the module to write. Unnecessary if the module prefix is mounted."
      )
      |> option(:overwrite, :boolean,
        alias: :o,
        doc: "Overwrite the file if it exists",
        default: false
      )
      |> argument(:module, required: true, cast: &Module.concat([&1]))
      |> parse(argv)

    opts =
      opts
      |> check_exclusive_opts()
      |> add_path_opt(args.module)

    parts_init = %{uses: [], attrs: [], apis: [], impls: []}

    parts =
      opts
      |> Map.take([:gen_server, :supervisor])
      |> IO.inspect(label: "optsreduce")
      |> Enum.filter(&elem(&1, 1))
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
    if File.exists?(path) and not over? do
      abort("file exists: #{path}")
    else
      File.write(path, code)
    end
  end

  defp check_exclusive_opts(%{gen_server: true, supervisor: true}) do
    abort("--gen-server and --supervisor are mutually exclusive")
  end

  defp check_exclusive_opts(opts) do
    opts
  end

  defp add_path_opt(%{path: path}, _),
    do: path

  defp add_path_opt(opts, module) do
    project = Modkit.Config.current_project()
    mount = Modkit.Config.mount(project)

    case Modkit.Mod.preferred_path(module, mount) do
      {:error, :no_mount_point} ->
        abort("The --path option is required when the module prefix is not mounted.")

      {:ok, path} ->
        Map.put(opts, :path, path)
    end
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
    |> add_part(:attrs, "@gen_opts ~w(name)a")
    |> add_part(:apis, """
      def start_link(opts) do
        {gen_opts, opts} = Keyword.split(opts, @gen_opts)
        Supervisor.start_link(__MODULE__, opts, gen_opts)
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

  defp add_part(parts, group, code) do
    Map.update!(parts, group, &[code | &1])
  end

  defp assemble_parts(module, %{uses: uses, attrs: attrs, apis: apis, impls: impls}) do
    uses = :lists.reverse(uses)
    apis = :lists.reverse(apis)
    impls = :lists.reverse(impls)
    attrs = :lists.reverse(attrs)

    [
      "defmodule #{inspect(module)} do",
      ~S(
      @moduledoc """
      Write a little description of the module …
      """
      ),
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
end
