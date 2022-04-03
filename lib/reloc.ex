defmodule Mix.Tasks.Mod.Relocate do
  use Mix.Task

  @shortdoc "Relocate one or all modules in the current application"

  import Modkit.Cli

  def run(argv) do
    {opts, args} =
      task(__MODULE__)
      |> option(:move, :boolean, alias: :m, doc: "Actually move the files", default: false)
      |> option(:force, :boolean,
        alias: :f,
        doc: "Move the files without confirmation",
        default: false
      )
      |> argument(:module, required: false)
      |> parse(argv)

    opts |> IO.inspect(label: "opts")
    args |> IO.inspect(label: "args")
  end
end
