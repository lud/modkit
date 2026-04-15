defmodule Modkit.ModTemplateTest do
  alias Modkit.Mod.Template
  use ExUnit.Case, async: true

  test "a module can be generated" do
    assert Template.render(Template.base_template(), %{module: TestArea}) =~
             "defmodule TestArea do"
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
    refute Template.render(Template.fetch!("Base"), %{module: Foo}) =~ "use GenServer"

    assert Template.render(Template.fetch!("GenServer"), %{module: Foo}) =~ "use GenServer"
    assert Template.render(Template.fetch!("Supervisor"), %{module: Foo}) =~ "use Supervisor"

    assert Template.render(Template.fetch!("DynamicSupervisor"), %{module: Foo}) =~
             "use DynamicSupervisor"

    assert Template.render(Template.fetch!("Mix.Task"), %{module: Foo}) =~ "use Mix.Task"
  end

  test "unknown built-in templates return :error" do
    assert :error = Template.fetch("Nope")
  end

  test "names lists all built-in templates" do
    assert Template.public_names() == [
             "Base",
             "DynamicSupervisor",
             "GenServer",
             "Mix.Task",
             "Supervisor"
           ]
  end

  test "the test template uses both module and test_module variables" do
    rendered =
      Template.render(Template.unit_test_template(), %{module: Foo, test_module: SomeTest})

    assert rendered =~ "defmodule SomeTest do"
    assert rendered =~ "alias Foo"
    assert rendered =~ "use ExUnit.Case, async: false"
  end
end
