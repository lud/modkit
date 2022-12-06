defmodule Modkit.ModTemplateTest do
  use ExUnit.Case, async: true
  alias Modkit.Mod.Template.UnitTestTemplate
  alias Modkit.Mod.Template.MixTaskTemplate
  alias Modkit.Mod.Template.DynamicSupervisorTemplate
  alias Modkit.Mod.Template.SupervisorTemplate
  alias Modkit.Mod.Template.GenServerTemplate
  alias Modkit.Mod.Template

  test "a module can be generated" do
    assert Template.render(TestArea) =~ "defmodule TestArea do"
  end

  defmodule FormattingTest do
    def template do
      """
      defmodule <%= @module %> do
        def foo, do: :ok
      end
      """
    end
  end

  test "the template will format according to given rules" do
    assert Template.render(TestArea, template: FormattingTest) =~ "def foo, do: :ok"

    assert Template.render(TestArea,
             template: FormattingTest,
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
    assert Template.render(TestArea, template: GenServerTemplate) =~ "use GenServer"

    assert Template.render(TestArea, template: SupervisorTemplate) =~
             "use Supervisor"

    assert Template.render(TestArea, template: DynamicSupervisorTemplate) =~
             "use DynamicSupervisor"

    assert Template.render(TestArea, template: MixTaskTemplate) =~
             "use Mix.Task"

    assert Template.render(TestArea, template: UnitTestTemplate) =~
             "use ExUnit.Case, async: false"
  end
end
