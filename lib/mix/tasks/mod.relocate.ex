defmodule Mix.Tasks.Mod.Relocate do
  use Mix.Task

  @shortdoc "Relocate one or all modules in the current application"

  defmodule Move do
    defstruct module: nil, good_path: nil, cur_path: nil, split: nil
  end

  import Modkit.Cli

  def run(argv) do
    Mix.Task.run("app.config")

    {opts, args} =
      command(__MODULE__)
      |> option(:prompt, :boolean,
        alias: :p,
        doc: "Prompt to move the files. Takes precedence over --force",
        default: false
      )
      |> option(:force, :boolean,
        alias: :f,
        doc: "Move the files without confirmation",
        default: false
      )
      |> argument(:module, required: false)
      |> parse(argv)

    project = Modkit.Config.current_project()

    modules =
      case args do
        %{module: mod} -> [Module.concat([mod])]
        _ -> Modkit.Mod.list(project)
      end

    do_run(project, modules, opts)
  end

  defp do_run(project, modules, opts) do
    mount = Modkit.Config.mount(project)
    print_mount(mount)
    cwd = File.cwd!()

    moves =
      modules
      |> Enum.reject(&is_protocol_impl?/1)
      |> map_filter_ok(&build_move(&1, mount, cwd))
      |> resolve_multis()
      |> ignore_generated()
      |> Enum.reject(&(in_good_path?(&1) or target_file_exists?(&1)))

    dir_actions = compute_dirs(moves)

    case dir_actions ++ moves do
      [] ->
        success_stop("nothing to do")

      actions ->
        run_actions(actions, opts)
    end
  end

  defp run_actions(actions, opts) do
    cond do
      opts.prompt ->
        print("Actions that would be executed:")
        Enum.each(actions, &print_action/1)

        if Mix.Shell.IO.yes?("Proceed with the moves") do
          Enum.each(actions, &print_run_action/1)
        else
          print("cancelled")
        end

      opts.force ->
        Enum.each(actions, &print_run_action/1)

      :_ ->
        print("Actions that would be executed:")
        Enum.each(actions, &print_action/1)
    end

    :ok
  end

  defp print_action({:mkdir, dir}) do
    print(["+dir ", cyan(dir)])
  end

  defp print_action(%Move{cur_path: from, good_path: to}) do
    {bad_rest, good_rest, common} = deviate_path(from, to)

    print([
      "move ",
      common,
      "/",
      magenta(bad_rest),
      "\n  -> ",
      common,
      "/",
      green(good_rest)
    ])
  end

  defp deviate_path(from, to) do
    deviate_path(Path.split(from), Path.split(to), [])
  end

  defp deviate_path([same | from], [same | to], acc) do
    deviate_path(from, to, [same | acc])
  end

  defp deviate_path(from_rest, to_rest, acc) do
    common_path =
      case acc do
        [] -> "."
        list -> Path.join(:lists.reverse(list))
      end

    {Path.join(from_rest), Path.join(to_rest), common_path}
  end

  defp print_run_action(action) do
    print_action(action)

    case run_action(action) do
      :ok ->
        print("  => ok")

      {:error, reason} ->
        reason = ensure_string(reason)
        danger(["  => ", reason])
        abort(["action failed, other actions aborted"])
    end
  end

  defp run_action(%Move{module: mod, split: ["Modkit", "Sample" | _]}) do
    notice("  ! skipped moving of #{inspect(mod)}")
  end

  defp run_action(%Move{cur_path: from, good_path: to}) do
    File.rename(from, to)
  end

  defp run_action({:mkdir, dir}) do
    File.mkdir(dir)
  end

  defp is_protocol_impl?(module) do
    {:__impl__, 1} in module.module_info(:exports)
  end

  defp build_move(module, mount, cwd) do
    case Modkit.Mod.preferred_path(module, mount) do
      {:ok, good_path} ->
        {:ok,
         %Move{
           module: module,
           good_path: good_path,
           cur_path: Modkit.Mod.current_path(module, cwd),
           split: Module.split(module)
         }}

      {:error, :no_mount_point} = err ->
        notice("module #{inspect(module)} is not mounted")
        err
    end
  end

  # group modules per source file and keep only modules that we can move, i.e.
  # they are alone in their source file, or they are a common prefix of all
  # modules in the file
  defp resolve_multis(moves) do
    moves
    |> Enum.group_by(& &1.cur_path)
    |> Enum.flat_map(fn
      {_file, [single]} -> [single]
      {_file, multis} -> parent_mod_or_empty(multis)
    end)
  end

  defp ignore_generated(moves) do
    moves
    |> Enum.filter(fn x ->
      x.cur_path |> IO.inspect(label: "x.cur_path")

      not String.contains?("/deps/", x.cur_path)
      |> IO.inspect(label: "is generated")
    end)

    # |> Enum.filter(&String.contains?("/deps/", &1.cur_path))
  end

  defp parent_mod_or_empty(moves) do
    moves
    |> Enum.find(fn %{split: split} ->
      Enum.all?(moves, fn %{split: submodule} -> List.starts_with?(submodule, split) end)
    end)
    |> case do
      nil ->
        modules = Enum.map_join(moves, "\n", &" * #{inspect(&1.module)}")

        warn("multiple modules defined in #{moves |> hd |> Map.get(:cur_path)}:\n#{modules}")
        []

      mv ->
        [mv]
    end
  end

  defp in_good_path?(%Move{good_path: path, cur_path: path}), do: true
  defp in_good_path?(_), do: false

  defp target_file_exists?(%Move{good_path: path}) do
    if File.regular?(path) do
      warn("file #{path} already exists")
      true
    else
      false
    end
  end

  defp compute_dirs(moves) do
    moves
    |> Enum.map(fn %{good_path: path} -> Path.dirname(path) end)
    |> Modkit.PathTool.list_create_dirs()
    |> Enum.map(&{:mkdir, &1})
  rescue
    e in ArgumentError -> e |> Exception.message() |> abort()
  end

  def print_mount(mount) do
    mount.points
    |> Enum.map(fn %Modkit.Mount.Point{prefix: pref, path: path} ->
      ["mount ", cyan(inspect(pref)), " on ", cyan(path)]
    end)
    |> Enum.intersperse("\n")
    |> print()
  end

  defp map_filter_ok(list, callback) do
    list
    |> Enum.map(callback)
    |> Enum.filter(&(elem(&1, 0) == :ok))
    |> Enum.map(&elem(&1, 1))
  end
end
