defmodule Modkit.ModTemplateTest do
  alias Modkit.Mod.Template
  alias Modkit.Mod.Template.BaseModuleTemplate
  alias Modkit.Mod.Template.DynamicSupervisorTemplate
  alias Modkit.Mod.Template.GenServerTemplate
  alias Modkit.Mod.Template.MixTaskTemplate
  alias Modkit.Mod.Template.SupervisorTemplate
  alias Modkit.Mod.Template.UnitTestTemplate
  use ExUnit.Case, async: true

  test "a module can be generated" do
    assert Template.render(BaseModuleTemplate, %{module: TestArea}) =~ "defmodule TestArea do"
  end

  test "the template will format according to given rules" do
    template = """
    defmodule <%= @module %> do
      def foo, do: :ok
    end
    """

    rendered = Template.render(template, %{module: SomeMod})
    assert rendered =~ "defmodule SomeMod do"
    assert rendered =~ "def foo, do: :ok"
  end

  test "the template can use a different flavor" do
    refute Template.render(BaseModuleTemplate, %{module: Foo}) =~ "use GenServer"
    assert Template.render(GenServerTemplate.template(), %{module: Foo}) =~ "use GenServer"

    assert Template.render(SupervisorTemplate.template(), %{module: Foo}) =~
             "use Supervisor"

    assert Template.render(DynamicSupervisorTemplate.template(), %{module: Foo}) =~
             "use DynamicSupervisor"

    assert Template.render(MixTaskTemplate.template(), %{module: Foo}) =~
             "use Mix.Task"
  end

  test "the test template uses both module and test_module variables" do
    rendered = Template.render(UnitTestTemplate.template(), %{module: Foo, test_module: SomeTest})

    assert rendered =~ "defmodule SomeTest do"
    assert rendered =~ "alias Foo"
    assert rendered =~ "use ExUnit.Case, async: false"
  end
end
