defmodule Modkit.Mod.Template do
  @moduledoc false

  @base_key "Base"
  @unit_test_key "ExUnit.Case"

  def templates do
    %{
      @base_key => """
      defmodule <%= @module %> do
      end
      """,
      "GenServer" => """
      defmodule <%= @module %> do
        use GenServer

        @gen_opts ~w(name timeout debug spawn_opt hibernate_after)a

        def start_link(opts) do
          {gen_opts, opts} = Keyword.split(opts, @gen_opts)
          GenServer.start_link(__MODULE__, opts, gen_opts)
        end

        @impl true
        def init(opts) do
          {:ok, opts}
        end
      end
      """,
      "Supervisor" => """
      defmodule <%= @module %> do
        use Supervisor

        def start_link(init_arg) do
          Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
        end

        @impl true
        def init(_init_arg) do
          children = [
            {Worker, key: :value}
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end
      end
      """,
      "DynamicSupervisor" => """
      defmodule <%= @module %> do
        use DynamicSupervisor

        def start_link(init_arg) do
          DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
        end

        @impl true
        def init(_init_arg) do
          DynamicSupervisor.init(strategy: :one_for_one)
        end
      end
      """,
      "Mix.Task" => """
      defmodule <%= @module %> do
        use Mix.Task

        @shortdoc "TODO short description of the task"

        @impl Mix.Task
        def run(argv) do
          # ...
        end
      end
      """,
      @unit_test_key => """
      defmodule <%= @test_module %> do
        use ExUnit.Case, async: false

        alias <%= @module %>

      end
      """
    }
  end

  def render(template, vars \\ %{}) when is_binary(template) and is_map(vars) do
    vars = vars_to_string(vars)

    template
    |> EEx.eval_string(assigns: vars)
    |> :erlang.iolist_to_binary()
  end

  def fetch(name) when is_binary(name) do
    Map.fetch(templates(), name)
  end

  def fetch!(name) when is_binary(name) do
    Map.fetch!(templates(), name)
  end

  def names do
    templates() |> Map.keys() |> Enum.sort()
  end

  def public_names do
    (templates() |> Map.keys() |> Enum.sort()) -- [@unit_test_key]
  end

  def base_template do
    fetch!(@base_key)
  end

  def unit_test_template do
    fetch!(@unit_test_key)
  end

  defp vars_to_string(vars) do
    Map.new(vars, fn
      {:module, mod} -> {:module, inspect(mod)}
      {:test_module, mod} -> {:test_module, inspect(mod)}
      {k, v} -> {k, v}
    end)
  end
end
