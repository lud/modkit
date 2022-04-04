defmodule Modkit.EnvTest do
  use ExUnit.Case, async: true

  test "the list of local modules is available" do
    assert Modkit in Modkit.Mod.list()
    assert Modkit.Mod in Modkit.Mod.list()
  end

  test "a custom mount is available in config" do
    assert %Modkit.Mount{
             points: [
               %Modkit.Mount.Point{
                 flavor: :elixir,
                 path: "lib/modkit",
                 prefix: Modkit,
                 splitfix: ["Modkit"]
               }
             ]
           } ==
             Modkit.Config.mount(Modkit.Config.current_project())

    assert %Modkit.Mount{
             points: [
               %Modkit.Mount.Point{flavor: :elixir, path: "b", prefix: B, splitfix: ["B"]},
               %Modkit.Mount.Point{flavor: :elixir, path: "a", prefix: A, splitfix: ["A"]}
             ]
           } ==
             Modkit.Config.mount(
               elixirc_paths: ["unused"],
               modkit: [mount: [{A, "a"}, {B, "b"}]]
             )
  end
end
