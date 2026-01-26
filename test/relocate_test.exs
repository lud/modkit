defmodule Modkit.RelocateTest do
  alias Modkit.Support.Subapp
  use ExUnit.Case, async: false

  setup_all do
    Subapp.hard_reset()
  end

  setup do
    Subapp.soft_reset()
  end

  test "listing modules to relocate" do
    Subapp.create_module("lib/foo/bar/baz.ex", ModkitDemo.AAA.BBB)
    Subapp.create_module("lib/some/sub/path.ex", ModkitDemo.CCC.DDD)
    output = Subapp.relocate!()

    assert output =~ "move lib/foo/bar/baz.ex"
    assert output =~ "to   lib/modkit_demo/aaa/bbb.ex"
    assert output =~ "move lib/some/sub/path.ex"
    assert output =~ "to   lib/modkit_demo/ccc/ddd.ex"
  end

  test "relocating a single module" do
    Subapp.create_module("lib/foo/bar/baz.ex", ModkitDemo.AAA.BBB)
    Subapp.create_module("lib/some/sub/path.ex", ModkitDemo.CCC.DDD)
    output = Subapp.relocate!(~w(ModkitDemo.AAA.BBB))

    assert output =~ "move lib/foo/bar/baz.ex"
    assert output =~ "to   lib/modkit_demo/aaa/bbb.ex"

    # should not concern the other module
    refute output =~ "move lib/some/sub/path.ex"
    refute output =~ "to   lib/modkit_demo/ccc/ddd.ex"
  end

  test "relocating a single module that does not exist" do
    assert {output, 1} = Subapp.relocate(~w(ModkitDemo.Some.Unexisting.Module))
    assert output =~ "could not find module ModkitDemo.Some.Unexisting.Module"
  end
end
