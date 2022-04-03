defmodule Modkit.PathResolveTest do
  use ExUnit.Case

  test "module path can be found from mounting point and module name" do
    mount_points = [
      {App.Test, "test/support"},
      {AppWeb.Test, "test/support"},
      {App, "lib/app"},
      {AppWeb, {:phoenix, "lib/app_web"}}
    ]

    cwd = "."

    assert {:ok, "./test/support.ex"} ==
             Modkit.Mod.get_preferred_path(App.Test, mount_points, cwd)

    assert {:ok, "./test/support/one.ex"} ==
             Modkit.Mod.get_preferred_path(App.Test.One, mount_points, cwd)

    assert {:ok, "./test/support/two.ex"} ==
             Modkit.Mod.get_preferred_path(App.Test.Two, mount_points, cwd)
  end
end
