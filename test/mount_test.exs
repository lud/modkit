defmodule Modkit.PathResolveTest do
  use ExUnit.Case
  alias Modkit.Mount
  alias Modkit.Mount.Point

  mount_points = [
    {App.Test, "test/support"},
    {AppWeb.Test, "test/support"},
    {App, "lib/App"},
    {AppWeb, {:phoenix, "lib/App_web"}}
  ]

  test "a point can be defined in the configuration" do
    assert %Point{
             path: "test/support",
             prefix: App.Test,
             splitfix: ["App", "Test"],
             flavor: :elixir
           } == Point.new({App.Test, "test/support"})

    assert %Point{
             path: "lib/support",
             prefix: AppWeb,
             splitfix: ["AppWeb"],
             flavor: :phoenix
           } == Point.new({AppWeb, {:phoenix, "lib/app_web"}})
  end
end
