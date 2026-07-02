defmodule Modkit.Mount do
  @moduledoc """
  Maps module name prefixes to directory paths.

  A mount is a list of mount points, each one associating a module prefix with
  the directory where the modules under that prefix belong. In a Mix project it
  is defined by the `:mount` entry of the `:modkit` configuration in `mix.exs`:

      def project do
        [
          # ...
          modkit: [
            mount: [
              {MyApp, "lib/my_app"},
              {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
            ]
          ]
        ]
      end

  Once defined, a mount gives the preferred file path of any module it covers:

      iex> mount = Modkit.Mount.define!([{MyApp, "lib/my_app"}])
      iex> Modkit.Mount.preferred_path(mount, MyApp.Some.Worker)
      {:ok, "lib/my_app/some/worker.ex"}

  Mount points are tried from the most precise prefix to the least precise one,
  so a module always resolves to the deepest prefix that covers it.
  """

  alias Modkit.SnakeCase
  @flavors [:elixir, :phoenix, :mix_task]

  defmodule Point do
    @moduledoc """
    A single mount point of a `Modkit.Mount`.

    The struct defines the following fields:

    * `:prefix` - the module prefix, as given in the configuration.
    * `:pre_split` - the prefix segments, as returned by `Module.split/1`.
    * `:path` - the directory for the modules under the prefix, or `:ignore`.
    * `:flavor` - the path building flavor, as described in
      `Modkit.Mount.define!/2`.
    """

    @enforce_keys [:prefix, :pre_split, :path, :flavor]

    defstruct @enforce_keys
  end

  @enforce_keys [:points, :to_snake]
  defstruct @enforce_keys

  @doc """
  Builds a mount from a list of mount points. Raises an `ArgumentError` when a
  point is invalid.

  Each point is a `{prefix, path}` or `{prefix, path, opts}` tuple:

  * `prefix` - a module whose namespace is mounted on the path.
  * `path` - the directory for the modules under the prefix, or `:ignore` to
    exclude those modules from path resolution.
  * `opts` - accepts a `:flavor` option with one of the following values:
    * `:elixir` (the default) - path segments are the snake cased module
      segments, as in `lib/my_app/some/worker.ex`.
    * `:mix_task` - segments are joined with dots, as in
      `lib/mix/tasks/mod.new.ex`.
    * `:phoenix` - controllers, views, components, live views, channels and
      sockets are placed in the conventional Phoenix sub-directories, as in
      `lib/my_app_web/controllers/user_controller.ex`.

  ### Options

  * `:names` - custom snake case forms for words found in module names, given as
    `{word, snake_form}` pairs in a keyword list or a map. For instance with
    `names: [RabbitMQ: "rabbitmq"]`, the module `MyApp.RabbitMQConsumer`
    resolves to `my_app/rabbitmq_consumer.ex` instead of
    `my_app/rabbit_mq_consumer.ex`.
  """
  def define!(points, opts \\ [])

  def define!(points, opts) when is_list(points) do
    to_snake =
      case opts[:names] do
        nil -> &SnakeCase.to_snake/1
        names -> fn segment -> SnakeCase.to_snake(segment, names: names) end
      end

    %__MODULE__{points: build_points(points), to_snake: to_snake}
  end

  def define!(other, _opts) do
    raise ArgumentError, ":mount config option must be a list of tuples, got: #{inspect(other)}"
  end

  @doc """
  Builds a mount from a list of mount points.

  Accepts the same points and options as `define!/2` but returns
  `{:ok, mount}`, or `{:error, exception}` when a point is invalid.
  """
  def define(raw_points, opts \\ [])

  def define(points, opts) do
    {:ok, define!(points, opts)}
  rescue
    e -> {:error, e}
  end

  defp build_points(raw_points) do
    raw_points
    |> Enum.map(&define_point!/1)
    |> Enum.sort(&sort_points/2)
  end

  defp define_point!({prefix, path} = p)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) do
    define_point!(prefix, path, [], p)
  end

  defp define_point!({prefix, path, opts} = p)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) and is_list(opts) do
    define_point!(prefix, path, opts, p)
  end

  defp define_point!(other) do
    invalid_point!(other)
  end

  defp define_point!(prefix, path, opts, original)
       when is_atom(prefix) and (is_binary(path) or path == :ignore) and is_list(opts) do
    flavor = Keyword.get(opts, :flavor, :elixir)

    case validate(flavor in @flavors, {:invalid_flavor, flavor}) do
      :ok -> %Point{prefix: prefix, path: path, pre_split: Module.split(prefix), flavor: flavor}
      {:error, reason} -> invalid_point!(original, reason)
    end
  end

  defp define_point!(_, _, _, original) do
    invalid_point!(original)
  end

  @spec invalid_point!(term) :: no_return()
  defp invalid_point!(point) do
    raise ArgumentError, "invalid point in :mount config option, got: #{inspect(point)}"
  end

  @spec invalid_point!(term, term) :: no_return()
  defp invalid_point!(point, reason) do
    raise ArgumentError,
          "invalid point in :mount config option, got: #{inspect(point)}, error: #{inspect(reason)}"
  end

  @doc """
  Derives a mount for test modules from the given mount.

  Each mount point is replaced by two points targeting the test directory: one
  keeping the original prefix, and one with a `Test` suffix on the prefix. For
  instance `{MyApp, "lib/my_app"}` produces `{MyApp, "test/my_app"}` and
  `{MyAppTest, "test/my_app_test"}`. Paths resolved from the derived mount use
  the `.exs` extension:

      iex> mount = Modkit.Mount.define!([{MyApp, "lib/my_app"}])
      iex> test_mount = Modkit.Mount.as_test(mount)
      iex> Modkit.Mount.preferred_path(test_mount, MyApp.WorkerTest)
      {:ok, "test/my_app/worker_test.exs"}

  Points mounted on `:ignore` are kept as they are.
  """
  def as_test(%__MODULE__{} = mount) do
    points =
      Enum.flat_map(mount.points, fn point ->
        # Return 2 points for each point.
        # - AAA -> AAA on test/aaa
        # - AAA -> AAATest on test/aaa_test
        #
        # - lib/aaa         -> test/aaa
        # - dev/aaa         -> test/dev/aaa
        # - test/support/aa -> test/support/aa

        case point.path do
          :ignore ->
            [point]

          path ->
            base_path = swap_test_root(path)
            test_path = append_test_suffix(base_path)
            test_pre_split = List.update_at(point.pre_split, -1, &(&1 <> "Test"))

            [
              %{point | path: base_path, flavor: :test},
              %{point | path: test_path, pre_split: test_pre_split, flavor: :test}
            ]
        end
      end)

    %{mount | points: points}
  end

  @doc """
  Transforms a module file path (without extension) into the corresponding test
  file path (also without extension).

  The transformation replaces a leading `lib/` or `test/` segment with `test/`,
  or prepends `test/` otherwise, then appends `_test` to the last segment.

      iex> Modkit.Mount.path_as_test("lib/my_app/foo")
      "test/my_app/foo_test"

      iex> Modkit.Mount.path_as_test("dev/my_app/foo")
      "test/dev/my_app/foo_test"

      iex> Modkit.Mount.path_as_test("test/support/my_app/foo")
      "test/support/my_app/foo_test"
  """
  def path_as_test(path) when is_binary(path) do
    path
    |> swap_test_root()
    |> append_test_suffix()
  end

  defp swap_test_root(path) do
    case Path.split(path) do
      ["lib" | rest] -> Path.join(["test" | rest])
      ["test" | rest] -> Path.join(["test" | rest])
      rest -> Path.join(["test" | rest])
    end
  end

  defp append_test_suffix(path) do
    path
    |> Path.split()
    |> List.update_at(-1, &(&1 <> "_test"))
    |> Path.join()
  end

  defp sort_points(%{pre_split: a}, %{pre_split: b}) do
    # higher precision goes first
    a > b
  end

  @doc """
  Returns the mount point covering the given module.

  The mount can be given as a `Modkit.Mount` struct or a list of
  `Modkit.Mount.Point` structs, and the module as a module name or a list of
  segments as returned by `Module.split/1`.

  Returns `{:ok, point}` for the first point whose prefix covers the module,
  `:ignore` when that point is mounted on `:ignore`, and
  `{:error, :not_mounted}` when no point matches.

  ### Examples

      iex> mount = Modkit.Mount.define!([{MyApp, "lib/my_app"}, {MyApp.Ecto, :ignore}])
      iex> {:ok, point} = Modkit.Mount.resolve(mount, MyApp.Worker)
      iex> point.path
      "lib/my_app"
      iex> Modkit.Mount.resolve(mount, MyApp.Ecto.Repo)
      :ignore
      iex> Modkit.Mount.resolve(mount, Other.Worker)
      {:error, :not_mounted}
  """
  def resolve(%__MODULE__{} = mount, mod_split) do
    resolve(mount.points, mod_split)
  end

  def resolve(points, module) when is_atom(module) do
    resolve(points, Module.split(module))
  end

  def resolve(points, mod_split) do
    do_resolve(points, mod_split)
  end

  @doc false
  def do_resolve([p | points], mod_split) when is_list(mod_split) do
    if prefix_of?(p, mod_split) do
      case p do
        %{path: :ignore} -> :ignore
        _ -> {:ok, p}
      end
    else
      do_resolve(points, mod_split)
    end
  end

  def do_resolve([], mod_split) when is_list(mod_split) do
    {:error, :not_mounted}
  end

  @doc """
  Returns whether the given mount point covers the module, that is whether the
  point prefix is a prefix of the module name. The module is given as a list of
  segments as returned by `Module.split/1`.
  """
  def prefix_of?(%{pre_split: pre_split}, mod_split) do
    List.starts_with?(mod_split, pre_split)
  end

  defp validate(true, _) do
    :ok
  end

  defp validate(false, reason) do
    {:error, reason}
  end

  @doc """
  Returns the file path where the given module belongs according to the mount.

  The path joins the mount point directory with the snake cased module segments
  that follow the point prefix. The extension is `.ex`, or `.exs` for mounts
  derived with `as_test/1`.

  Returns `{:ok, path}` on success, `:ignore` when the module resolves to an
  `:ignore` point, `{:error, :not_mounted}` when no point covers the module,
  and `{:error, :not_elixir}` for module names without the `Elixir.` namespace,
  such as Erlang module names.

  ### Examples

      iex> mount = Modkit.Mount.define!([{MyApp, "lib/my_app"}, {MyApp.Schemas, "lib/schemas"}])
      iex> Modkit.Mount.preferred_path(mount, MyApp.Some.Worker)
      {:ok, "lib/my_app/some/worker.ex"}
      iex> Modkit.Mount.preferred_path(mount, MyApp.Schemas.User)
      {:ok, "lib/schemas/user.ex"}
      iex> Modkit.Mount.preferred_path(mount, Other.Module)
      {:error, :not_mounted}
  """
  def preferred_path(%__MODULE__{} = mount, module) when is_atom(module) do
    with {:ok, mod_split} <- split_mod(module),
         {:ok, point} <- resolve(mount, mod_split) do
      {:ok, point_to_path(point, mod_split, mount.to_snake)}
    end
  end

  defp point_to_path(point, mod_split, to_snake) do
    path_rest = unprefix(mod_split, point.pre_split)
    sub_path = path_segments(path_rest, point.flavor, to_snake)

    Path.join(:lists.flatten([point.path, sub_path])) <> file_suffix(point.flavor)
  end

  defp file_suffix(:test) do
    ".exs"
  end

  defp file_suffix(_) do
    ".ex"
  end

  defp split_mod(module) do
    {:ok, Module.split(module)}
  rescue
    _ in ArgumentError -> {:error, :not_elixir}
  end

  defp unprefix([a | modrest], [a | prefrest]) do
    unprefix(modrest, prefrest)
  end

  defp unprefix(modrest, []) do
    modrest
  end

  defp path_segments(segments, :mix_task, to_snake) do
    Enum.map_join(segments, ".", to_snake)
  end

  defp path_segments([segment | rest], flavor, to_snake) do
    [format_segment(segment, flavor, to_snake) | path_segments(rest, flavor, to_snake)]
  end

  defp path_segments([], _, _) do
    []
  end

  defp format_segment(segment, flavor, to_snake) when flavor in [:elixir, :test] do
    to_snake.(segment)
  end

  defp format_segment(segment, :phoenix, to_snake) do
    basename = format_segment(segment, :elixir, to_snake)

    matchers = [
      {fn -> segment == "Layouts" end, ["components", basename]},
      {fn -> String.ends_with?(segment, "Component") end, ["components", basename]},
      {fn -> String.ends_with?(segment, "Components") end, ["components", basename]},
      # controllers
      {fn -> String.ends_with?(segment, "Controller") end, ["controllers", basename]},
      {fn -> String.ends_with?(segment, "HTML") end, ["controllers", basename]},
      {fn -> String.ends_with?(segment, "JSON") end, ["controllers", basename]},
      # live
      {fn -> String.ends_with?(segment, "Live") end, ["live", basename]},
      # views
      {fn -> String.ends_with?(segment, "View") end, ["views", basename]},
      # channels
      {fn -> String.ends_with?(segment, "Channel") end, ["channels", basename]},
      {fn -> String.ends_with?(segment, "Socket") end, ["channels", basename]}
    ]

    found =
      Enum.find(matchers, fn {match, result} ->
        if match.() do
          result
        else
          nil
        end
      end)

    case found do
      {_, result} -> result
      nil -> basename
    end
  end
end
