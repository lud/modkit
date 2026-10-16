defmodule Modkit.ModkitTest do
  alias Modkit.Mount
  use ExUnit.Case, async: false

  test "get the current project" do
    assert %{otp_app: :modkit, mount: mount} = Modkit.load_current_project()
    assert {:ok, Modkit.Mod.current_path(Modkit)} == Mount.preferred_path(mount, Modkit)
  end

  describe "default mount" do
    setup do
      %{mount: mount} = Modkit.load_project(MyApp, app: :my_app, elixirc_paths: ["lib"])
      %{mount: mount}
    end

    test "mounts the root module", %{mount: mount} do
      assert {:ok, "lib/my_app/some/worker.ex"} == Mount.preferred_path(mount, MyApp.Some.Worker)
    end

    test "mounts the web module with the phoenix flavor", %{mount: mount} do
      assert {:ok, "lib/my_app_web.ex"} == Mount.preferred_path(mount, MyAppWeb)

      assert {:ok, "lib/my_app_web/router.ex"} == Mount.preferred_path(mount, MyAppWeb.Router)

      assert {:ok, "lib/my_app_web/controllers/page_controller.ex"} ==
               Mount.preferred_path(mount, MyAppWeb.PageController)

      assert {:ok, "lib/my_app_web/live/user_live.ex"} ==
               Mount.preferred_path(mount, MyAppWeb.UserLive)
    end

    test "mounts mix tasks", %{mount: mount} do
      assert {:ok, "lib/mix/tasks/my_app.setup.ex"} ==
               Mount.preferred_path(mount, Mix.Tasks.MyApp.Setup)
    end

    test "derives the web module from a nested root module" do
      %{mount: mount} = Modkit.load_project(My.App, app: :my_app, elixirc_paths: ["lib"])

      assert {:ok, "lib/my_app_web/controllers/page_controller.ex"} ==
               Mount.preferred_path(mount, My.AppWeb.PageController)
    end
  end
end
