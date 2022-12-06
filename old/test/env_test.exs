defmodule Modkit.EnvTest do
  use ExUnit.Case, async: true

  test "the list of local modules is available" do
    assert Modkit in Modkit.Mod.list()
    assert Modkit.Mod in Modkit.Mod.list()
  end

  test "the default mount point is available" do
    # our app example is :fake_app, but modkit takes the main module name from
    # the mix.exs file module instead of using Macro.camelize/1 so we get the
    # actual chosen module name with more certainty.

    project_config = [
      app: :fake_app,
      # lib must be chosen by default
      elixirc_paths: ["some/paths", "lib"]
      # no :modkit option is provided
    ]

    assert %Modkit.Mount{
             points: [
               %Modkit.Mount.Point{
                 flavor: :elixir,
                 path: "lib/fake_app",
                 # here is where we match on the Modkit's mix.exs file in test
                 # env instead of having FakeApp.
                 prefix: Modkit,
                 pre_split: ["Modkit"]
               },
               %Modkit.Mount.Point{
                 flavor: :mix_task,
                 path: "lib/mix/tasks",
                 prefix: Mix.Tasks,
                 pre_split: ["Mix", "Tasks"]
               }
             ]
           } == Modkit.Config.mount(project_config)
  end

  test "a custom mount is available in config" do
    assert %Modkit.Mount{
             points: [
               %Modkit.Mount.Point{flavor: :elixir, path: "b", prefix: B, pre_split: ["B"]},
               %Modkit.Mount.Point{flavor: :elixir, path: "a", prefix: A, pre_split: ["A"]}
             ]
           } ==
             Modkit.Config.mount(
               app: :fake_app,
               elixirc_paths: ["unused"],
               modkit: [mount: [{A, "a"}, {B, "b"}]]
             )
  end
end
