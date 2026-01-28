defmodule Modkit.Mod.Template do
  def render(module, opts \\ []) when is_list(opts) do
    module = inspect(module)
    template = Keyword.get(opts, :template, __MODULE__.BaseModule.template())

    if not is_binary(template) do
      raise "invalid template (not a string): #{inspect(template)}"
    end

    format_opts = Keyword.get(opts, :formatter, [])

    template
    |> EEx.eval_string(assigns: %{module: module})
    |> Code.format_string!(format_opts)
    |> :erlang.iolist_to_binary()
  end

  @moduledoc false

  defmodule BaseModule do
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
