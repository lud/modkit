defmodule Modkit.MountTest do
  use ExUnit.Case
  alias Modkit.Mount
  alias Modkit.Mount.Point

  mount_points = [
    {App.Test, "test/support"},
    {AppWeb.Test, "test/support"},
    {App, "lib/app"},
    {AppWeb, {:phoenix, "lib/app_web"}}
  ]

  test "a point can be defined in the configuration" do
    assert %Point{
             path: "test/support",
             prefix: App.Test,
             splitfix: ["App", "Test"],
             flavor: :elixir
           } == Point.new({App.Test, "test/support"})

    assert %Point{
             path: "lib/app_web",
             prefix: AppWeb,
             splitfix: ["AppWeb"],
             flavor: :phoenix
           } == Point.new({AppWeb, {:phoenix, "lib/app_web"}})
  end

  test "it is possible to append a mount point or a spec" do
    assert %Point{
             path: "lib/app",
             prefix: App,
             splitfix: ["App"],
             flavor: :elixir
           } == Point.new({App, "lib/app"})

    m = Mount.new()

    assert Mount.add(m, {App, "lib/app"}) ==
             Mount.add(m, %Point{
               path: "lib/app",
               prefix: App,
               splitfix: ["App"],
               flavor: :elixir
             })
  end

  # test "mount points are ordered" do
  #   # Mount points are resolved in definition order, because there can be an
  #   # overlap betweed them. The library automatically sort them by common prefix
  #   mount = Mount.new()
  #   |> Mount.add({App.Test, "test/support"})

  # end
end
