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
        doc: "use GenServer",
        default: false
      )
      |> argument(:module, required: false)
      |> parse(argv)

    opts |> IO.inspect(label: "opts")
    args |> IO.inspect(label: "args")
  end
end
