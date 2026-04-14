defmodule Modkit.Support.Subapp do
  alias Modkit.SnakeCase
  # The orginal copy of the app that is not modified, and under version control.
  defp source_dir do
    Path.absname("priv/modkit_demo-master")
  end

  # The copy used and modified in tests, ignored by git
  defp target_dir do
    Path.absname("_build/test/demo-app")
  end

  defp subapp_env do
    %{"MIX_TEST" => nil, "MODKIT_DEP_ROOT" => Path.expand(File.cwd!())}
  end

  defp source_path(subpath \\ []) do
    Path.join([source_dir() | List.wrap(subpath)])
  end

  def target_path(subpath \\ []) do
    Path.join([target_dir() | List.wrap(subpath)])
  end

  def hard_reset do
    :ok = check_not_installed()
    IO.puts("\nhard resetting subapp")

    _ = File.rm_rf!(target_path())
    _ = File.mkdir_p!(Path.dirname(target_path()))
    _ = File.cp_r!(source_path(), target_path())

    {_, 0} =
      System.cmd("mix", ~w"do deps.get + deps.compile + compile",
        cd: target_path(),
        into: IO.stream(),
        env: subapp_env()
      )

    :ok
  end

  defp check_not_installed do
    Mix.path_for(:archives)
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.any?(&String.contains?(&1, "modkit"))
    |> case do
      true -> raise "modkit is installed globally, test app will not use current code"
      false -> :ok
    end
  end

  def soft_reset do
    :ok = check_not_installed()
    IO.puts("\nsoft resetting subapp")

    _ = File.rm_rf!(target_path("_build/dev/lib/modkit_demo"))
    _ = File.rm_rf!(target_path("lib"))
    _ = File.cp_r!(source_path("lib"), target_path("lib"))
    _ = File.rm_rf!(target_path("test"))
    _ = File.cp_r!(source_path("test"), target_path("test"))

    {_, 0} =
      System.cmd("mix", ~w"compile",
        cd: target_path(),
        into: IO.stream(),
        env: subapp_env()
      )

    # Backdate .app so compile.app's mtime check always sees it as stale when
    # a test adds new modules within the same filesystem-mtime second.
    app_file = target_path("_build/dev/lib/modkit_demo/ebin/modkit_demo.app")

    if File.exists?(app_file) do
      File.touch!(app_file, 0)
    end

    :ok
  end

  def create_module(subpath, module) do
    create_file(subpath, "defmodule #{SnakeCase.as_string(module)} do\nend")
  end

  def create_file(subpath, content) do
    path = target_path(subpath)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    path
  end

  def read!(subpath) do
    File.read!(target_path(subpath))
  end

  def exists?(subpath) do
    File.exists?(target_path(subpath))
  end

  def relocate(argv \\ []) do
    System.cmd("mix", ["mod.relocate" | argv],
      cd: target_path(),
      stderr_to_stdout: true,
      env: subapp_env()
    )
  end

  def relocate!(argv \\ []) do
    case relocate(argv) do
      {output, 0} ->
        IO.puts([IO.ANSI.cyan(), output, IO.ANSI.reset()])
        output

      {output, _} ->
        IO.puts([IO.ANSI.yellow(), output, IO.ANSI.reset()])
        raise "relocation command failed"
    end
  end

  def mod_new(argv) do
    System.cmd("mix", ["mod.new" | argv],
      cd: target_path(),
      stderr_to_stdout: true,
      env: subapp_env()
    )
  end

  def mod_new!(argv) do
    case mod_new(argv) do
      {output, 0} ->
        IO.puts([IO.ANSI.cyan(), output, IO.ANSI.reset()])
        output

      {output, _} ->
        IO.puts([IO.ANSI.yellow(), output, IO.ANSI.reset()])
        raise "mod new command failed"
    end
  end
end
