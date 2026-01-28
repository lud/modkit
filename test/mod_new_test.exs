defmodule Modkit.ModNewTest do
  alias Modkit.Support.Subapp
  use ExUnit.Case, async: false

  # setup_all do
  #   Subapp.hard_reset()
  # end

  @moduletag :skip

  setup do
    Subapp.soft_reset()
  end

  defp project do
    # Demo app uses empty configuration for now
    project = Modkit.load_project(ModkitDemo, app: :modkit_demo, elixirc_paths: ["lib"])

    update_in(project.mount.points, fn points ->
      Enum.map(points, fn %{path: p} = point ->
        %{point | path: target(p)}
      end)
    end)
    |> dbg(limit: :infinity)
  end

  defp target(path) do
    Path.relative_to_cwd(Subapp.target_path(path))
  end

  defp valid_existing_module(comment \\ "") do
    """
    defmodule Existing_#{System.system_time(:millisecond)} do
    # #{comment}
    end
    """
  end

  describe "basic module creation" do
    test "creating a new module" do
      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.Some.Mod, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      assert [target("/lib/modkit_demo/some/mod.ex")] == paths
      content = Subapp.read!("lib/modkit_demo/some/mod.ex")

      assert """
             defmodule ModkitDemo.Some.Mod do
             end\
             """ = content
    end
  end

  describe "custom templates" do
    test "creating a module with a custom template file" do
      template_path = target("priv/custom_template.eex")

      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.Custom.Mod, %{
                 template: template_path,
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      assert [target("lib/modkit_demo/custom/mod.ex")] == paths
      content = Subapp.read!("lib/modkit_demo/custom/mod.ex") |> dbg()

      assert """
             defmodule ModkitDemo.Custom.Mod do
               # This is a custom template
             end\
             """ = content
    end

    test "fails when template path doesn't exist" do
      assert {:error, {:template_not_found, target("priv/nonexistent.ex")}} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.Missing.Mod, %{
                 template: target("priv/nonexistent.ex"),
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    test "fails when module file already exists" do
      Subapp.create_file("lib/modkit_demo/existing/mod.ex", valid_existing_module("foo"))

      assert {:error, {:exists, target("lib/modkit_demo/existing/mod.ex")}} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.Existing.Mod, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    test "overwrites existing module with overwrite flag" do
      Subapp.create_file("lib/modkit_demo/overwrite/mod.ex", valid_existing_module("old content"))

      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.Overwrite.Mod, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: false
               })

      assert [target("lib/modkit_demo/overwrite/mod.ex")] == paths
      content = Subapp.read!("lib/modkit_demo/overwrite/mod.ex")

      assert content =~ "defmodule ModkitDemo.Overwrite.Mod do"
      refute content =~ "old content"
    end
  end

  describe "built-in templates" do
    test "creating a GenServer module" do
      assert {:ok, [target("lib/modkit_demo/my_gen_server.ex")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.MyGenServer, %{
                 template: "GenServer",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      content = Subapp.read!("lib/modkit_demo/my_gen_server.ex")

      assert content =~ "defmodule ModkitDemo.MyGenServer do"
      assert content =~ "use GenServer"
    end

    test "creating a Supervisor module" do
      assert {:ok, [target("lib/modkit_demo/my_supervisor.ex")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.MySupervisor, %{
                 template: "Supervisor",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      content = Subapp.read!("lib/modkit_demo/my_supervisor.ex")

      assert content =~ "defmodule ModkitDemo.MySupervisor do"
      assert content =~ "use Supervisor"
    end

    test "creating a DynamicSupervisor module" do
      assert {:ok, [target("lib/modkit_demo/my_dynamic_supervisor.ex")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.MyDynamicSupervisor, %{
                 template: "DynamicSupervisor",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      content = Subapp.read!("lib/modkit_demo/my_dynamic_supervisor.ex")

      assert content =~ "defmodule ModkitDemo.MyDynamicSupervisor do"
      assert content =~ "use DynamicSupervisor"
    end

    test "creating a Mix.Task module" do
      assert {:ok, [target("lib/modkit_demo/my_task.ex")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.MyTask, %{
                 template: "Mix.Task",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      content = Subapp.read!("lib/modkit_demo/my_task.ex")

      assert content =~ "defmodule ModkitDemo.MyTask do"
      assert content =~ "use Mix.Task"
    end
  end

  describe "unit test generation with -u flag" do
    test "creates both module and test file" do
      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.WithTest, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      assert "lib/modkit_demo/with_test.ex" in paths
      assert "test/modkit_demo/with_test_test.exs" in paths
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

      assert {:error, {:exists, "lib/modkit_demo/existing_mod.ex"}} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.ExistingMod, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      refute Subapp.exists?("test/modkit_demo/existing_mod_test.exs")
    end

    @tag :skip
    test "fails when test exists and -u is used" do
      Subapp.create_file("test/modkit_demo/existing_test_test.exs", valid_existing_module("foo"))

      assert {:error, {:exists, "test/modkit_demo/existing_test_test.exs"}} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.ExistingTest, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      refute Subapp.exists?("lib/modkit_demo/existing_test.ex")
    end

    @tag :skip
    test "overwrites existing module and creates test with -u and -o flags" do
      Subapp.create_file("lib/modkit_demo/overwrite_mod.ex", valid_existing_module("old module"))

      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.OverwriteMod, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: true
               })

      assert "lib/modkit_demo/overwrite_mod.ex" in paths
      assert "test/modkit_demo/overwrite_mod_test.exs" in paths

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

      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.OverwriteTest, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: true
               })

      assert "lib/modkit_demo/overwrite_test.ex" in paths
      assert "test/modkit_demo/overwrite_test_test.exs" in paths

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

      assert {:ok, paths} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.OverwriteBoth, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: true
               })

      assert "lib/modkit_demo/overwrite_both.ex" in paths
      assert "test/modkit_demo/overwrite_both_test.exs" in paths

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
      assert {:ok, [target("test/modkit_demo/only_test_test.exs")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.OnlyTest, %{
                 overwrite: false,
                 generate_mod: false,
                 generate_test: true
               })

      refute Subapp.exists?("lib/modkit_demo/only_test.ex")
      assert Subapp.exists?("test/modkit_demo/only_test_test.exs")

      test_content = Subapp.read!("test/modkit_demo/only_test_test.exs")
      assert test_content =~ "defmodule ModkitDemo.OnlyTestTest do"
      assert test_content =~ "use ExUnit.Case"
    end

    @tag :skip
    test "fails when test exists and -U is used" do
      Subapp.create_file("test/modkit_demo/existing_only_test.exs", valid_existing_module("foo"))

      assert {:error, {:exists, target("test/modkit_demo/existing_only_test.exs")}} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.ExistingOnly, %{
                 overwrite: false,
                 generate_mod: false,
                 generate_test: true
               })
    end

    @tag :skip
    test "overwrites existing test with -U and -o flags" do
      Subapp.create_file(
        "test/modkit_demo/overwrite_only_test.exs",
        valid_existing_module("old test")
      )

      assert {:ok, [target("test/modkit_demo/overwrite_only_test.exs")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.OverwriteOnly, %{
                 overwrite: true,
                 generate_mod: false,
                 generate_test: true
               })

      refute Subapp.exists?("lib/modkit_demo/overwrite_only.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_only_test.exs")

      assert test_content =~ "defmodule ModkitDemo.OverwriteOnlyTest do"
      refute test_content =~ "old test"
    end
  end

  describe "custom path" do
    @tag :skip
    test "creates module at custom path" do
      assert {:ok, [target("lib/custom/location/my_module.ex")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.CustomPath, %{
                 path: "lib/custom/location/my_module.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      assert Subapp.exists?("lib/custom/location/my_module.ex")
      content = Subapp.read!("lib/custom/location/my_module.ex")
      assert content =~ "defmodule ModkitDemo.CustomPath do"
    end

    @tag :skip
    test "fails when custom path already exists" do
      Subapp.create_file("lib/custom/existing/path.ex", valid_existing_module("existing"))

      assert {:error, {:exists, "lib/custom/existing/path.ex"}} =
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.CustomPathExists, %{
                 path: "lib/custom/existing/path.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    @tag :skip
    test "overwrites existing file at custom path with overwrite flag" do
      Subapp.create_file("lib/custom/overwrite/path.ex", valid_existing_module("old"))

      assert {:ok, [target("lib/custom/overwrite/path.ex")]} ==
               Mix.Tasks.Mod.New.generate(project(), ModkitDemo.CustomPathOverwrite, %{
                 path: "lib/custom/overwrite/path.ex",
                 overwrite: true,
                 generate_mod: true,
                 generate_test: false
               })

      content = Subapp.read!("lib/custom/overwrite/path.ex")
      assert content =~ "defmodule ModkitDemo.CustomPathOverwrite do"
      refute content =~ "old"
    end
  end
end
