defmodule Modkit.MountTest do
  use ExUnit.Case, async: true
  alias Modkit.Mount
  alias Modkit.Mount.Point

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

  test "mount point config error" do
    assert_raise ArgumentError, fn ->
      Point.new(MyApp)
    end
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

  test "mount points are ordered" do
    # Mount points are resolved in definition order, because there can be an
    # overlap betweed them. The library automatically sort them by common prefix
    mount =
      Mount.new()
      |> Mount.add({A.B.C, "test/support/sub-1"})
      |> Mount.add({A, "test/support"})
      |> Mount.add({A.B, "test/support/sub-1/sub-2"})
      |> Mount.add({X, "lib/stuff/xxx-1"})
      |> Mount.add({X.Y, "lib/stuff/xxx-1/xxx-2"})

    prefixs = Enum.map(mount.points, & &1.prefix)

    assert [X.Y, X, A.B.C, A.B, A] == prefixs
  end

  test "add mount points with duplicate prefix" do
    mount =
      Mount.new()
      |> Mount.add({A, "test/support/sub-1"})
      |> Mount.add({A, "test/support/sub-1"})

    assert 1 == length(mount.points)

    assert_raise ArgumentError, ~r/already/, fn ->
      Mount.new()
      |> Mount.add({A, "test/support/sub-1"})
      |> Mount.add({A, "other-path"})
    end
  end

  test "add mount points with duplicate path" do
    # This is actually OK
    mount =
      Mount.new()
      |> Mount.add({AAAA, "test/support/sub-1"})
      |> Mount.add({BBBB, "test/support/sub-1"})

    assert 2 == length(mount.points)
  end

  test "a point can tell if it is a prefix of a splitlist" do
    assert %Point{
             path: "lib/a/b/c",
             prefix: A.B.C,
             splitfix: ["A", "B", "C"],
             flavor: :elixir
           } = point = Point.new({A.B.C, "lib/a/b/c"})

    assert Point.prefix_of?(point, ["A", "B", "C"])
    assert Point.prefix_of?(point, ["A", "B", "C", "D"])

    refute Point.prefix_of?(point, ["A", "B", "D"])
    refute Point.prefix_of?(point, ["X", "A", "B"])
    refute Point.prefix_of?(point, ["X", "A", "B", "C"])
  end
end
