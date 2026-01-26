defmodule Modkit.ModTemplateTest do
  alias Modkit.Mod.Template
  alias Modkit.Mod.Template.DynamicSupervisorTemplate
  alias Modkit.Mod.Template.GenServerTemplate
  alias Modkit.Mod.Template.MixTaskTemplate
  alias Modkit.Mod.Template.SupervisorTemplate
  alias Modkit.Mod.Template.UnitTestTemplate
  use ExUnit.Case, async: true

  test "a module can be generated" do
    assert Template.render(TestArea) =~ "defmodule TestArea do"
  end

  test "the template will format according to given rules" do
    template = """
    defmodule <%= @module %> do
      def foo, do: :ok
    end
    """

    assert Template.render(TestArea, template: template) =~ "def foo, do: :ok"

    assert Template.render(TestArea,
             template: template,
             formatter: [force_do_end_blocks: true]
           ) =~
             """
               def foo do
                 :ok
               end
             """
  end

  test "the template can use a different flavor" do
    refute Template.render(TestArea) =~ "use GenServer"
    assert Template.render(TestArea, template: GenServerTemplate.template()) =~ "use GenServer"

    assert Template.render(TestArea, template: SupervisorTemplate.template()) =~
             "use Supervisor"

    assert Template.render(TestArea, template: DynamicSupervisorTemplate.template()) =~
             "use DynamicSupervisor"

    assert Template.render(TestArea, template: MixTaskTemplate.template()) =~
             "use Mix.Task"

    assert Template.render(TestArea, template: UnitTestTemplate.template()) =~
             "use ExUnit.Case, async: false"
  end
end
