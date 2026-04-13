defmodule Modkit.Mod.Template do
  @moduledoc false
  def render(template, vars \\ %{})

  def render(template, vars) when is_binary(template) and is_map(vars) do
    vars = vars_to_string(vars)

    template
    |> EEx.eval_string(assigns: vars)
    |> :erlang.iolist_to_binary()
  end

  def render(template, vars) when is_atom(template) and is_map(vars) do
    render(template.template(), vars)
  end

  defp vars_to_string(vars) do
    Map.new(vars, fn
      {:module, mod} -> {:module, inspect(mod)}
      {:test_module, mod} -> {:test_module, inspect(mod)}
      {k, v} -> {k, v}
    end)
  end

  defmodule BaseModuleTemplate do
    def template do
      """
      defmodule <%= @module %> do
      end
      """
    end
  end

  defmodule GenServerTemplate do
    def template do
      """
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
      """
    end
  end

  defmodule SupervisorTemplate do
    def template do
      """
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
      """
    end
  end

  defmodule DynamicSupervisorTemplate do
    def template do
      """
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
      """
    end
  end

  defmodule MixTaskTemplate do
    def template do
      """
      defmodule <%= @module %> do
        use Mix.Task

        @shortdoc "TODO short description of the task"

        @impl Mix.Task
        def run(argv) do
          # ...
        end
      end
      """
    end
  end

  defmodule UnitTestTemplate do
    def template do
      """
      defmodule <%= @test_module %> do
        use ExUnit.Case, async: false

        alias <%= @module %>

      end
      """
    end
  end
end
