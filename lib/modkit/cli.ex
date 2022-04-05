defmodule Modkit.Cli do
  def color(content, color),
    do: [apply(IO.ANSI, color, []), content, IO.ANSI.default_color()]

  def yellow(content), do: color(content, :yellow)
  def red(content), do: color(content, :red)
  def green(content), do: color(content, :green)
  def blue(content), do: color(content, :blue)
  def cyan(content), do: color(content, :cyan)
  def magenta(content), do: color(content, :magenta)

  def abort do
    abort(1)
  end

  def abort(iodata) when is_list(iodata) or is_binary(iodata) do
    print(red(iodata))
    abort(1)
  end

  def abort(n) when is_integer(n) do
    halt(n)
  end

  def success_stop(iodata) do
    success(iodata)
    halt(0)
  end

  def halt(n) do
    # spawn(fn -> System.halt(n) end)
    Process.sleep(99999)
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

  require Record

  Record.defrecordp(:__opt, :option,
    key: nil,
    doc: nil,
    alias: nil,
    default: nil,
    keep: nil,
    type: nil
  )

  Record.defrecordp(:__arg, :argument,
    key: nil,
    required: true,
    cast: nil
  )

  Record.defrecordp(:__task, :argument,
    arguments: [],
    options: [],
    module: nil
  )

  @type option ::
          record(:__opt,
            key: atom,
            doc: String.t(),
            alias: atom,
            default: {:default, term} | :skip,
            keep: boolean,
            type: option_type
          )
  @type argument ::
          record(
            :__arg,
            key: atom,
            required: boolean,
            cast: (term -> term)
          )
  @type task ::
          record(
            :__task,
            arguments: [argument],
            options: %{atom => option},
            module: module
          )
  @type option_type :: :integer | :float | :string | :count | :boolean

  def task(module) when is_atom(module), do: __task(module: module, arguments: [], options: %{})

  @type option_opt :: {:alias, atom} | {:doc, String.t()} | {:default, term}
  @type opt_conf :: [option_opt]

  @spec option(task, key :: atom, Option.vtype(), opt_conf) :: task
  def option(__task(options: opts) = task, key, type, conf) do
    opt = make_option(key, type, conf)
    __task(task, options: Map.put(opts, key, opt))
  end

  defp make_option(key, type, conf) when is_atom(key) do
    keep = Keyword.get(conf, :keep, false)

    doc = Keyword.get(conf, :doc, "")

    alias_ = Keyword.get(conf, :alias, nil)

    default =
      case Keyword.fetch(conf, :default) do
        {:ok, term} -> {:default, term}
        :error -> :skip
      end

    __opt(key: key, doc: doc, type: type, alias: alias_, default: default, keep: keep)
  end

  @type argument_opt :: {:required, boolean()}
  @type arg_conf :: [argument_opt]

  @spec argument(task, key :: atom, arg_conf) :: task
  def argument(__task(arguments: args) = task, key, conf) do
    arg = make_argument(key, conf)
    __task(task, arguments: args ++ [arg])
  end

  defp make_argument(key, conf) do
    required = Keyword.get(conf, :required, false)
    cast = Keyword.get(conf, :cast, & &1)
    __arg(key: key, required: required, cast: cast)
  end

  def parse(__task(options: opts) = task, argv) do
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

  defp usage_args(task) do
    task.arguments
    |> Enum.map(fn __arg(key: key, required: req?) ->
      mark = if(req?, do: "", else: "*")
      "<#{key}>#{mark}"
    end)
    |> case do
      [] -> []
      list -> [" ", list]
    end
  end

  defp max_opt_name_width(task) do
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
        end)
    end
  end

  defp usage_options(task) do
    max_opt = max_opt_name_width(task) + 3

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
  end

  defp print_usage(task) do
    args = usage_args(task)

    options = usage_options(task)

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

  defp opt_to_switch(__opt(keep: true, type: t)), do: [t, :keep]
  defp opt_to_switch(__opt(keep: false, type: t)), do: t
  defp opt_alias(__opt(alias: nil)), do: []
  defp opt_alias(__opt(alias: a, key: key)), do: [{a, key}]

  defp take_opts(__task(options: schemes), opts) do
    Enum.reduce(schemes, %{}, fn scheme, acc -> collect_opt(scheme, opts, acc) end)
  end

  defp collect_opt({key, scheme}, opts, acc) do
    case __opt(scheme, :keep) do
      true ->
        list = collect_list_option(opts, key)
        Map.put(acc, key, list)

      false ->
        case get_opt_value(opts, key, __opt(scheme, :default)) do
          {:ok, value} -> Map.put(acc, key, value)
          :skip -> acc
        end
    end
  end

  def get_opt_value(opts, key, default) do
    case Keyword.fetch(opts, key) do
      :error ->
        case default do
          {:default, v} -> {:ok, v}
          :skip -> :skip
        end

      {:ok, v} ->
        {:ok, v}
    end
  end

  defp collect_list_option(opts, key) do
    opts |> Enum.filter(fn {k, _} -> k == key end) |> Enum.map(&elem(&1, 1))
  end

  defp take_args(__task(arguments: schemes) = task, args) do
    take_args(schemes, args, %{})
  catch
    {:missing_argument, key} ->
      print_usage(task)

      abort("missing required argument <#{Atom.to_string(key)}>")
  end

  defp take_args([__arg(required: false) | _], [], acc) do
    acc
  end

  defp take_args([__arg(required: true, key: key) | _], [], _acc) do
    throw({:missing_argument, key})
  end

  defp take_args([__arg(key: key, cast: cast) | schemes], [value | argv], acc) do
    acc = Map.put(acc, key, call_cast(cast, value))
    take_args(schemes, argv, acc)
  end

  defp take_args([], [extra | _], _) do
    abort("unexpected argument #{inspect(extra)}")
  end

  defp take_args([], [], acc) do
    acc
  end

  defp call_cast(nil, value), do: value
  defp call_cast(cast, value) when is_function(cast, 1), do: cast.(value)
end
