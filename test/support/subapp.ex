defmodule Modkit.Support.Subapp do
  alias Modkit.SnakeCase
  # The orginal copy of the app that is not modified, and under version control.
  @source_dir Path.absname("priv/modkit_demo-master")

  # The copy used and modified in tests, ignored by git
  @target_dir Path.absname("tmp/modkit_demo")

  defp source_path(subpath \\ []) do
    Path.join([@source_dir | List.wrap(subpath)])
  end

  defp target_path(subpath \\ []) do
    Path.join([@target_dir | List.wrap(subpath)])
  end

  def hard_reset do
    :ok = check_not_installed()

    _ = File.rm_rf!(target_path())
    _ = File.cp_r!(source_path(), target_path())

    {_, 0} =
      System.cmd("mix", ~w"do deps.update --all + deps.compile + compile",
        cd: target_path(),
        into: IO.stream(),
        env: %{"MIX_ENV" => nil}
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
    _ = File.rm_rf!(target_path("lib"))
    _ = File.cp_r!(source_path("lib"), target_path("lib"))

    {_, 0} =
      System.cmd("mix", ~w"compile",
        cd: target_path(),
        into: IO.stream(),
        env: %{"MIX_ENV" => nil}
      )

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

  def relocate(argv \\ []) do
    System.cmd("mix", ["mod.relocate" | argv],
      cd: target_path(),
      stderr_to_stdout: true,
      env: %{"MIX_ENV" => nil}
    )
  end

  def relocate!(argv \\ []) do
    case relocate(argv) do
      {output, 0} ->
        output

      {output, _} ->
        IO.puts([IO.ANSI.yellow(), output, IO.ANSI.reset()])
        raise "relocation command failed"
    end
  end
end
