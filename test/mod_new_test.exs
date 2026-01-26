defmodule Modkit.ModNewTest do
  alias Modkit.Support.Subapp
  use ExUnit.Case, async: false

  setup_all do
    Subapp.hard_reset()
  end

  setup do
    Subapp.soft_reset()
  end

  defp valid_existing_module(comment \\ "") do
    """
    defmodule Existing do
    # #{comment}
    end
    """
  end

  describe "basic module creation" do
    test "creating a new module" do
      Subapp.mod_new!(~w(ModkitDemo.Some.Mod))
      content = Subapp.read!("lib/modkit_demo/some/mod.ex")

      assert """
             defmodule ModkitDemo.Some.Mod do
             end\
             """ = content
    end
  end

  describe "custom templates" do
    test "creating a module with a custom template file" do
      template_path = "priv/custom_template.eex"

      Subapp.mod_new!(["ModkitDemo.Custom.Mod", "-t", template_path])
      content = Subapp.read!("lib/modkit_demo/custom/mod.ex") |> dbg()

      assert """
             defmodule ModkitDemo.Custom.Mod do
               # This is a custom template
             end\
             """ = content
    end

    test "fails when template path doesn't exist" do
      {output, exit_code} = Subapp.mod_new(~w(ModkitDemo.Missing.Mod -t priv/nonexistent.ex))

      assert exit_code != 0
      assert output =~ ~r{nonexistent.*was not found}
    end

    test "fails when module file already exists" do
      Subapp.create_file("lib/modkit_demo/existing/mod.ex", valid_existing_module("foo"))

      {output, exit_code} = Subapp.mod_new(~w(ModkitDemo.Existing.Mod))

      assert exit_code != 0
      assert output =~ "exists"
    end

    @tag :skip
    test "overwrites existing module with -o flag" do
      Subapp.create_file("lib/modkit_demo/overwrite/mod.ex", valid_existing_module("old content"))

      Subapp.mod_new!(~w(ModkitDemo.Overwrite.Mod -o))
      content = Subapp.read!("lib/modkit_demo/overwrite/mod.ex")

      assert content =~ "defmodule ModkitDemo.Overwrite.Mod do"
      refute content =~ "old content"
    end
  end

  describe "built-in templates" do
    @tag :skip
    test "creating a GenServer module" do
      Subapp.mod_new!(~w(ModkitDemo.MyGenServer -t GenServer))
      content = Subapp.read!("lib/modkit_demo/my_gen_server.ex")

      assert content =~ "defmodule ModkitDemo.MyGenServer do"
      assert content =~ "use GenServer"
    end

    @tag :skip
    test "creating a Supervisor module" do
      Subapp.mod_new!(~w(ModkitDemo.MySupervisor -t Supervisor))
      content = Subapp.read!("lib/modkit_demo/my_supervisor.ex")

      assert content =~ "defmodule ModkitDemo.MySupervisor do"
      assert content =~ "use Supervisor"
    end

    @tag :skip
    test "creating a DynamicSupervisor module" do
      Subapp.mod_new!(~w(ModkitDemo.MyDynamicSupervisor -t DynamicSupervisor))
      content = Subapp.read!("lib/modkit_demo/my_dynamic_supervisor.ex")

      assert content =~ "defmodule ModkitDemo.MyDynamicSupervisor do"
      assert content =~ "use DynamicSupervisor"
    end

    @tag :skip
    test "creating a Mix.Task module" do
      Subapp.mod_new!(~w(ModkitDemo.MyTask -t Mix.Task))
      content = Subapp.read!("lib/modkit_demo/my_task.ex")

      assert content =~ "defmodule ModkitDemo.MyTask do"
      assert content =~ "use Mix.Task"
    end
  end

  describe "unit test generation with -u flag" do
    @tag :skip
    test "creates both module and test file" do
      Subapp.mod_new!(~w(ModkitDemo.WithTest -u))

      assert Subapp.exists?("lib/modkit_demo/with_test.ex")
      assert Subapp.exists?("test/modkit_demo/with_test_test.exs")

      module_content = Subapp.read!("lib/modkit_demo/with_test.ex")
      test_content = Subapp.read!("test/modkit_demo/with_test_test.exs")

      assert module_content =~ "defmodule ModkitDemo.WithTest do"
      assert test_content =~ "defmodule ModkitDemo.WithTestTest do"
      assert test_content =~ "use ExUnit.Case"
    end

    @tag :skip
    test "fails when module exists and -u is used" do
      Subapp.create_file("lib/modkit_demo/existing_mod.ex", valid_existing_module("foo"))

      {output, exit_code} = Subapp.mod_new(~w(ModkitDemo.ExistingMod -u))

      assert exit_code != 0
      assert output =~ "exists"
      refute Subapp.exists?("test/modkit_demo/existing_mod_test.exs")
    end

    @tag :skip
    test "fails when test exists and -u is used" do
      Subapp.create_file("test/modkit_demo/existing_test_test.exs", valid_existing_module("foo"))

      {output, exit_code} = Subapp.mod_new(~w(ModkitDemo.ExistingTest -u))

      assert exit_code != 0
      assert output =~ "exists"
      refute Subapp.exists?("lib/modkit_demo/existing_test.ex")
    end

    @tag :skip
    test "overwrites existing module and creates test with -u and -o flags" do
      Subapp.create_file("lib/modkit_demo/overwrite_mod.ex", valid_existing_module("old module"))

      Subapp.mod_new!(~w(ModkitDemo.OverwriteMod -u -o))

      module_content = Subapp.read!("lib/modkit_demo/overwrite_mod.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_mod_test.exs")

      assert module_content =~ "defmodule ModkitDemo.OverwriteMod do"
      refute module_content =~ "old module"
      assert test_content =~ "defmodule ModkitDemo.OverwriteModTest do"
    end

    @tag :skip
    test "overwrites existing test and creates module with -u and -o flags" do
      Subapp.create_file(
        "test/modkit_demo/overwrite_test_test.exs",
        valid_existing_module("old test")
      )

      Subapp.mod_new!(~w(ModkitDemo.OverwriteTest -u -o))

      module_content = Subapp.read!("lib/modkit_demo/overwrite_test.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_test_test.exs")

      assert module_content =~ "defmodule ModkitDemo.OverwriteTest do"
      assert test_content =~ "defmodule ModkitDemo.OverwriteTestTest do"
      refute test_content =~ "old test"
    end

    @tag :skip
    test "overwrites both existing module and test with -u and -o flags" do
      Subapp.create_file("lib/modkit_demo/overwrite_both.ex", valid_existing_module("old module"))

      Subapp.create_file(
        "test/modkit_demo/overwrite_both_test.exs",
        valid_existing_module("old test")
      )

      Subapp.mod_new!(~w(ModkitDemo.OverwriteBoth -u -o))

      module_content = Subapp.read!("lib/modkit_demo/overwrite_both.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_both_test.exs")

      assert module_content =~ "defmodule ModkitDemo.OverwriteBoth do"
      refute module_content =~ "old module"
      assert test_content =~ "defmodule ModkitDemo.OverwriteBothTest do"
      refute test_content =~ "old test"
    end
  end

  describe "test-only generation with -U flag" do
    @tag :skip
    test "creates only the test file, not the module" do
      Subapp.mod_new!(~w(ModkitDemo.OnlyTest -U))

      refute Subapp.exists?("lib/modkit_demo/only_test.ex")
      assert Subapp.exists?("test/modkit_demo/only_test_test.exs")

      test_content = Subapp.read!("test/modkit_demo/only_test_test.exs")
      assert test_content =~ "defmodule ModkitDemo.OnlyTestTest do"
      assert test_content =~ "use ExUnit.Case"
    end

    @tag :skip
    test "fails when test exists and -U is used" do
      Subapp.create_file("test/modkit_demo/existing_only_test.exs", valid_existing_module("foo"))

      {output, exit_code} = Subapp.mod_new(~w(ModkitDemo.ExistingOnly -U))

      assert exit_code != 0
      assert output =~ "exists"
    end

    @tag :skip
    test "overwrites existing test with -U and -o flags" do
      Subapp.create_file(
        "test/modkit_demo/overwrite_only_test.exs",
        valid_existing_module("old test")
      )

      Subapp.mod_new!(~w(ModkitDemo.OverwriteOnly -U -o))

      refute Subapp.exists?("lib/modkit_demo/overwrite_only.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_only_test.exs")

      assert test_content =~ "defmodule ModkitDemo.OverwriteOnlyTest do"
      refute test_content =~ "old test"
    end
  end
end
