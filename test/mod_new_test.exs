defmodule Modkit.ModNewTest do
  alias Modkit.Support.Subapp
  use ExUnit.Case, async: false

  setup_all do
    Subapp.hard_reset()
  end

  setup do
    Subapp.soft_reset()
  end

  test "creating a new module" do
    Subapp.mod_new!(~w(ModkitDemo.Some.Mod))
    content = Subapp.read!("lib/modkit_demo/some/mod.ex")

    assert """
           defmodule ModkitDemo.Some.Mod do
           end\
           """ = content
  end

  # test "creating a new module with built-in templates"
end
