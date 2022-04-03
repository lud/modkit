defmodule Modkit.Cli do
  def color(content, color),
    do: [apply(IO.ANSI, color, []), content, IO.ANSI.default_color()]

  def yellow(content), do: color(content, :yellow)
  def red(content), do: color(content, :red)
  def green(content), do: color(content, :green)
  def blue(content), do: color(content, :blue)
  def cyan(content), do: color(content, :cyan)
  def magenta(content), do: color(content, :magenta)

  def abort(iodata) do
    print(red(iodata))
    abort()
  end

  def abort do
    System.halt(1)
    Process.sleep(:infinity)
  end

  def success_stop(iodata) do
    success(iodata)
    System.halt()
    Process.sleep(:infinity)
  end

  def success(iodata) do
    print(green(iodata))
  end

  def danger(iodata) do
    print(red(iodata))
  end

  def warn(iodata) do
    print(yellow(iodata))
  end

  def notice(iodata) do
    print(magenta(iodata))
  end

  def print(iodata) do
    IO.puts(iodata)
  end

  def ensure_string(str) when is_binary(str) do
    str
  end

  def ensure_string(term) do
    inspect(term)
  end

  defmodule Option do
    @enforce_keys [:key, :doc, :type, :alias, :default, :keep]
    defstruct @enforce_keys

    @type vtype :: :integer | :float | :string | :count | :boolean
    @type t :: %__MODULE__{
            key: atom,
            doc: binary,
            type: vtype,
            alias: atom,
            default: term,
            keep: boolean
          }
  end

  defmodule Argument do
    @enforce_keys [:key, :required]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            required: boolean,
            key: atom
          }
  end

  defmodule Task do
    @enforce_keys [:arguments, :options, :module]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            arguments: [Argument.t()],
            options: %{atom => Option.t()},
            module: module
          }
  end

  def task(module) when is_atom(module), do: %Task{module: module, arguments: [], options: %{}}

  @type option_opt :: {:alias, atom} | {:doc, String.t()} | {:default, term}
  @type opt_conf :: [option_opt]

  @spec option(Task.t(), key :: atom, Option.vtype(), opt_conf) :: Task.t()
  def option(%Task{options: opts} = task, key, type, conf) do
    opt = make_option(key, type, conf)
    %Task{task | options: Map.put(opts, key, opt)}
  end

  defp make_option(key, type, conf) when is_atom(key) do
    keep = Keyword.get(conf, :keep, false)

    doc = Keyword.get(conf, :doc, "")

    alias_ = Keyword.get(conf, :alias, nil)

    default =
      case Keyword.fetch(conf, :default) do
        {:ok, term} -> {true, term}
        :error -> false
      end

    %Option{key: key, doc: doc, type: type, alias: alias_, default: default, keep: keep}
  end

  @type argument_opt :: {:required, boolean()}
  @type arg_conf :: [argument_opt]

  @spec argument(Task.t(), key :: atom, arg_conf) :: Task.t()
  def argument(%Task{arguments: args} = task, key, conf) do
    arg = make_argument(key, conf)
    %Task{task | arguments: args ++ [arg]}
  end

  defp make_argument(key, conf) do
    required = Keyword.get(conf, :required, false)
    %Argument{key: key, required: required}
  end

  def parse(%Task{options: opts, arguments: args} = task, argv) do
    strict = Enum.map(opts, fn {key, opt} -> {key, opt_to_switch(opt)} end)
    aliases = Enum.flat_map(opts, fn {_, opt} -> opt_alias(opt) end)

    case OptionParser.parse(argv, strict: strict, aliases: aliases) do
      {opts, args, []} ->
        opts = take_opts(task, opts)
        args = take_args(task, args)
        {opts, args}

      {_, _, invalid} ->
        print_usage(task)
        error_invalid_opts(invalid)
        abort()
    end
  end

  defp error_invalid_opts(kvs) do
    Enum.map(kvs, fn {k, _v} -> danger("invalid option #{k}") end)
  end

  defp print_usage(task) do
    args =
      task.arguments
      |> Enum.map(fn %Argument{key: key, required: req?} ->
        mark = if(req?, do: "", else: "*")
        "<#{key}>#{mark}"
      end)
      |> case do
        [] -> []
        list -> [" ", list]
      end

    max_opt =
      case map_size(task.options) do
        0 ->
          0

        _ ->
          Enum.reduce(task.options, 0, fn opt, acc ->
            opt
            |> elem(1)
            |> Map.fetch!(:key)
            |> Atom.to_string()
            |> String.length()
            |> max(acc)
          end) + 3
      end

    options =
      task.options
      |> Enum.map(fn {key, %{alias: ali, doc: doc}} ->
        [
          case ali do
            nil -> "    "
            _ -> "-#{ali}, "
          end,
          "--",
          String.pad_trailing(Atom.to_string(key), max_opt, " "),
          doc,
          ?\n
        ]
      end)
      |> case do
        [] -> []
        opts -> ["Options\n\n", opts]
      end

    print([
      "Usage\n",
      case Mix.Task.shortdoc(task.module) do
        nil -> []
        doc -> [?\n, doc]
      end,
      "\n\n",
      """
      mix #{Mix.Task.task_name(task.module)}#{args}
      #{options}\
      """
    ])
  end

  defp opt_to_switch(%{keep: true, type: t}), do: [t, :keep]
  defp opt_to_switch(%{keep: false, type: t}), do: t
  defp opt_alias(%{alias: nil}), do: []
  defp opt_alias(%{alias: a, key: key}), do: [{a, key}]

  defp take_opts(%Task{options: schemes}, opts) do
    Enum.reduce(schemes, %{}, fn {key, opt}, acc ->
      case opt.keep do
        true ->
          list = opts |> Enum.filter(fn {k, _} -> k == key end) |> Enum.map(&elem(&1, 1))
          Map.put(acc, key, list)

        false ->
          case Keyword.fetch(opts, key) do
            :error ->
              case opt.default do
                {true, v} -> Map.put(acc, key, v)
                false -> acc
              end

            {:ok, v} ->
              Map.put(acc, key, v)
          end
      end
    end)
  end

  defp take_args(%Task{arguments: schemes} = task, args) do
    take_args(schemes, args, %{})
  catch
    {:missing_argument, key} ->
      print_usage(task)

      abort("missing required argument <#{Atom.to_string(key)}>")
  end

  defp take_args([%{required: false} | _], [], acc) do
    acc
  end

  defp take_args([%{required: true, key: key} | _], [], acc) do
    throw({:missing_argument, key})
  end

  defp take_args([%{key: key} | schemes], [value | argv], acc) do
    acc = Map.put(acc, key, value)
    take_args(schemes, argv, acc)
  end

  defp take_args([], _, acc) do
    acc
  end
end
