defmodule Modkit.PathResolveTest do
  use ExUnit.Case, async: true
  alias Modkit.Mount

  test "module path can be found from mounting point and module name" do
    mount_points =
      Mount.from_points([
        {App.Test, "test/support"},
        {AppWeb.Test, "test/support"},
        {App, "lib/app"},
        {AppWeb, {:phoenix, "lib/app_web"}}
      ])

    assert {:ok, "test/support.ex"} ==
             Modkit.Mod.get_preferred_path(App.Test, mount_points)

    assert {:ok, "test/support/one.ex"} ==
             Modkit.Mod.get_preferred_path(App.Test.One, mount_points)

    assert {:ok, "test/support/two.ex"} ==
             Modkit.Mod.get_preferred_path(App.Test.Two, mount_points)

    assert {:error, :no_mount_point} = Modkit.Mod.get_preferred_path(XXX, mount_points)
  end
end
