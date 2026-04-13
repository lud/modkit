defmodule Modkit.ModNewTest do
  alias Modkit.Support.Subapp
  use ExUnit.Case, async: false

  setup_all do
    Subapp.hard_reset()
  end

  # No need to rest the app in between tests if each test uses unique module
  # names.
  #
  #     setup do
  #       Subapp.soft_reset()
  #     end

  defmacrop target(path) do
    path
    |> Macro.expand_literals(__CALLER__)
    |> Subapp.target_path()
    |> Path.relative_to_cwd()
  end

  defp project do
    # Demo app uses empty configuration for now
    project =
      ModkitDemo
      |> Modkit.load_project(app: :modkit_demo, elixirc_paths: ["lib"])
      |> Map.put(:app_dir, target(""))

    update_in(project.mount.points, fn points ->
      Enum.map(points, fn %{path: p} = point ->
        %{point | path: p}
      end)
    end)
  end

  defp project(mount) do
    ModkitDemo
    |> Modkit.load_project(
      app: :modkit_demo,
      elixirc_paths: ["lib"],
      modkit: [mount: mount]
    )
    |> Map.put(:app_dir, target(""))
  end

  defp valid_existing_module(comment) do
    """
    defmodule Existing_#{System.system_time(:millisecond)} do
    # #{comment}
    end
    """
  end

  defp generate(project, module, options) do
    Mix.Tasks.Mod.New.generate(project, module, options)
  end

  describe "basic module creation" do
    test "creating a new module" do
      assert {:ok, paths} =
               generate(project(), ModkitDemo.Some.Mod, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      assert [target("lib/modkit_demo/some/mod.ex")] == paths
      content = Subapp.read!("lib/modkit_demo/some/mod.ex")

      assert """
             defmodule ModkitDemo.Some.Mod do
             end
             """ = content
    end
  end

  describe "custom templates" do
    test "creating a module with a custom template file" do
      template_path = target("priv/custom_template.eex")

      assert {:ok, paths} =
               generate(project(), ModkitDemo.Custom.Mod, %{
                 template: template_path,
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      assert [target("lib/modkit_demo/custom/mod.ex")] == paths
      content = Subapp.read!("lib/modkit_demo/custom/mod.ex")

      assert """
             defmodule ModkitDemo.Custom.Mod do
               # This is a custom template
             end
             """ = content
    end

    test "fails when template path doesn't exist" do
      assert {:error, {:template_not_found, target("priv/nonexistent.ex")}} ==
               generate(project(), ModkitDemo.Missing.Mod, %{
                 template: target("priv/nonexistent.ex"),
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    test "fails when module file already exists" do
      Subapp.create_file("lib/modkit_demo/existing/mod.ex", valid_existing_module("foo"))

      assert {:error, {:exists, [target("lib/modkit_demo/existing/mod.ex")]}} ==
               generate(project(), ModkitDemo.Existing.Mod, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    test "overwrites existing module with overwrite flag" do
      Subapp.create_file("lib/modkit_demo/overwrite/mod.ex", valid_existing_module("old content"))

      assert {:ok, paths} =
               generate(project(), ModkitDemo.Overwrite.Mod, %{
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
               generate(project(), ModkitDemo.MyGenServer, %{
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
               generate(project(), ModkitDemo.MySupervisor, %{
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
               generate(project(), ModkitDemo.MyDynamicSupervisor, %{
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
               generate(project(), ModkitDemo.MyTask, %{
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
               generate(project(), ModkitDemo.Testable, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("lib/modkit_demo/testable.ex") in paths
      assert target("test/modkit_demo/testable_test.exs") in paths
      assert Subapp.exists?("lib/modkit_demo/testable.ex")
      assert Subapp.exists?("test/modkit_demo/testable_test.exs")

      module_content = Subapp.read!("lib/modkit_demo/testable.ex")
      test_content = Subapp.read!("test/modkit_demo/testable_test.exs")

      assert module_content =~ "defmodule ModkitDemo.Testable do"
      assert test_content =~ "defmodule ModkitDemo.TestableTest do"
      assert test_content =~ "use ExUnit.Case"
    end

    test "fails when module exists and -u is used" do
      Subapp.create_file("lib/modkit_demo/existing_mod.ex", valid_existing_module("foo"))

      assert {:error, {:exists, [target("lib/modkit_demo/existing_mod.ex")]}} =
               generate(project(), ModkitDemo.ExistingMod, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      refute Subapp.exists?("test/modkit_demo/existing_mod_test.exs")
    end

    test "fails when test exists and -u is used" do
      Subapp.create_file("test/modkit_demo/existing_test_test.exs", valid_existing_module("foo"))

      assert {:error, {:exists, [target("test/modkit_demo/existing_test_test.exs")]}} =
               generate(project(), ModkitDemo.ExistingTest, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      refute Subapp.exists?("lib/modkit_demo/existing_test.ex")
    end

    test "overwrites existing module and creates test with -u and -o flags" do
      Subapp.create_file("lib/modkit_demo/overwrite_mod.ex", valid_existing_module("old module"))

      assert {:ok, paths} =
               generate(project(), ModkitDemo.OverwriteMod, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("lib/modkit_demo/overwrite_mod.ex") in paths
      assert target("test/modkit_demo/overwrite_mod_test.exs") in paths

      module_content = Subapp.read!("lib/modkit_demo/overwrite_mod.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_mod_test.exs")

      assert module_content =~ "defmodule ModkitDemo.OverwriteMod do"
      refute module_content =~ "old module"
      assert test_content =~ "defmodule ModkitDemo.OverwriteModTest do"
    end

    test "overwrites existing test and creates module with -u and -o flags" do
      Subapp.create_file(
        "test/modkit_demo/overwrite_test_test.exs",
        valid_existing_module("old test")
      )

      assert {:ok, paths} =
               generate(project(), ModkitDemo.OverwriteTest, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("lib/modkit_demo/overwrite_test.ex") in paths
      assert target("test/modkit_demo/overwrite_test_test.exs") in paths

      module_content = Subapp.read!("lib/modkit_demo/overwrite_test.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_test_test.exs")

      assert module_content =~ "defmodule ModkitDemo.OverwriteTest do"
      assert test_content =~ "defmodule ModkitDemo.OverwriteTestTest do"
      refute test_content =~ "old test"
    end

    test "overwrites both existing module and test with -u and -o flags" do
      Subapp.create_file("lib/modkit_demo/overwrite_both.ex", valid_existing_module("old module"))

      Subapp.create_file(
        "test/modkit_demo/overwrite_both_test.exs",
        valid_existing_module("old test")
      )

      assert {:ok, paths} =
               generate(project(), ModkitDemo.OverwriteBoth, %{
                 overwrite: true,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("lib/modkit_demo/overwrite_both.ex") in paths
      assert target("test/modkit_demo/overwrite_both_test.exs") in paths

      module_content = Subapp.read!("lib/modkit_demo/overwrite_both.ex")
      test_content = Subapp.read!("test/modkit_demo/overwrite_both_test.exs")

      assert module_content =~ "defmodule ModkitDemo.OverwriteBoth do"
      refute module_content =~ "old module"
      assert test_content =~ "defmodule ModkitDemo.OverwriteBothTest do"
      refute test_content =~ "old test"
    end
  end

  describe "test-only generation with -U flag" do
    test "creates only the test file, not the module" do
      assert {:ok, [target("test/modkit_demo/only_test_test.exs")]} ==
               generate(project(), ModkitDemo.OnlyTest, %{
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

    test "fails when test exists and -U is used" do
      Subapp.create_file("test/modkit_demo/existing_only_test.exs", valid_existing_module("foo"))

      assert {:error, {:exists, [target("test/modkit_demo/existing_only_test.exs")]}} ==
               generate(project(), ModkitDemo.ExistingOnly, %{
                 overwrite: false,
                 generate_mod: false,
                 generate_test: true
               })
    end

    test "overwrites existing test with -U and -o flags" do
      Subapp.create_file(
        "test/modkit_demo/overwrite_only_test.exs",
        valid_existing_module("old test")
      )

      assert {:ok, [target("test/modkit_demo/overwrite_only_test.exs")]} ==
               generate(project(), ModkitDemo.OverwriteOnly, %{
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

  describe "ignored mount points" do
    test "a module resolving to an :ignore mount point returns an ignored_mount error" do
      mount = [
        {ModkitDemo.Ignored, :ignore},
        {ModkitDemo, "lib/modkit_demo"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:error, {:ignored_mount, ModkitDemo.Ignored.Thing}} ==
               generate(project(mount), ModkitDemo.Ignored.Thing, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    test "an ignored module can still be generated with --path" do
      mount = [
        {ModkitDemo.Ignored, :ignore},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:ok, [target("lib/ignored_with_path/foo.ex")]} ==
               generate(project(mount), ModkitDemo.Ignored.Foo, %{
                 path: "lib/ignored_with_path/foo.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      content = Subapp.read!("lib/ignored_with_path/foo.ex")
      assert content =~ "defmodule ModkitDemo.Ignored.Foo do"
    end

    test "--path with -u derives the test file path from --path (lib prefix)" do
      mount = [
        {ModkitDemo.Ignored, :ignore},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:ok, paths} =
               generate(project(mount), ModkitDemo.Ignored.Bar, %{
                 path: "lib/ignored_lib/bar.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("lib/ignored_lib/bar.ex") in paths
      assert target("test/ignored_lib/bar_test.exs") in paths

      assert Subapp.read!("lib/ignored_lib/bar.ex") =~ "defmodule ModkitDemo.Ignored.Bar do"

      assert Subapp.read!("test/ignored_lib/bar_test.exs") =~
               "defmodule ModkitDemo.Ignored.BarTest do"
    end

    test "--path with -u derives the test file path from --path (non-lib prefix)" do
      mount = [
        {ModkitDemo.Ignored, :ignore},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:ok, paths} =
               generate(project(mount), ModkitDemo.Ignored.Baz, %{
                 path: "dev/ignored_dev/baz.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("dev/ignored_dev/baz.ex") in paths
      assert target("test/dev/ignored_dev/baz_test.exs") in paths
    end

    test "--path with -u derives the test file path from --path (test/support)" do
      mount = [
        {ModkitDemo.Ignored, :ignore},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:ok, paths} =
               generate(project(mount), ModkitDemo.Ignored.Helper, %{
                 path: "test/support/ignored_support/helper.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("test/support/ignored_support/helper.ex") in paths
      assert target("test/support/ignored_support/helper_test.exs") in paths
    end

    test "--path with -u errors when the extension is not .ex" do
      mount = [
        {ModkitDemo, "lib/modkit_demo"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:error, {:invalid_path_extension, "lib/wrong_ext/foo.txt"}} ==
               generate(project(mount), ModkitDemo.WrongExt, %{
                 path: "lib/wrong_ext/foo.txt",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })
    end

    test "--path with -u errors when the absolute path is outside app_dir" do
      mount = [
        {ModkitDemo, "lib/modkit_demo"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      outside = "/tmp/definitely_not_under_app_dir/foo.ex"

      assert {:error, {:path_outside_app_dir, ^outside}} =
               generate(project(mount), ModkitDemo.Outside, %{
                 path: outside,
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })
    end
  end

  describe "non-lib mount paths" do
    test "a dev/ mount generates the module under dev/ and the test under test/" do
      mount = [
        {ModkitDemo.Dev, "dev/modkit_demo"},
        {ModkitDemo, "lib/modkit_demo"},
        {Mix.Tasks, "lib/mix/tasks", flavor: :mix_task}
      ]

      assert {:ok, paths} =
               generate(project(mount), ModkitDemo.Dev.Thing, %{
                 overwrite: false,
                 generate_mod: true,
                 generate_test: true
               })

      assert target("dev/modkit_demo/thing.ex") in paths
      assert target("test/dev/modkit_demo/thing_test.exs") in paths

      module_content = Subapp.read!("dev/modkit_demo/thing.ex")
      test_content = Subapp.read!("test/dev/modkit_demo/thing_test.exs")

      assert module_content =~ "defmodule ModkitDemo.Dev.Thing do"
      assert test_content =~ "defmodule ModkitDemo.Dev.ThingTest do"
    end
  end

  describe "custom path" do
    test "creates module at custom path" do
      assert {:ok, [target("lib/custom/location/my_module.ex")]} ==
               generate(project(), ModkitDemo.CustomPath, %{
                 path: "lib/custom/location/my_module.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })

      assert Subapp.exists?("lib/custom/location/my_module.ex")
      content = Subapp.read!("lib/custom/location/my_module.ex")
      assert content =~ "defmodule ModkitDemo.CustomPath do"
    end

    test "fails when custom path already exists" do
      Subapp.create_file("lib/custom/existing/path.ex", valid_existing_module("existing"))

      assert {:error, {:exists, [target("lib/custom/existing/path.ex")]}} =
               generate(project(), ModkitDemo.CustomPathExists, %{
                 path: "lib/custom/existing/path.ex",
                 overwrite: false,
                 generate_mod: true,
                 generate_test: false
               })
    end

    test "overwrites existing file at custom path with overwrite flag" do
      Subapp.create_file("lib/custom/overwrite/path.ex", valid_existing_module("old"))

      assert {:ok, [target("lib/custom/overwrite/path.ex")]} ==
               generate(project(), ModkitDemo.CustomPathOverwrite, %{
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
