defmodule Modkit.ModTest do
  alias Modkit.Mod
  use ExUnit.Case, async: true
  doctest Modkit.Mod, import: true

  test "a module's current path is known" do
    assert __ENV__.file == Mod.current_path(__MODULE__, "")

    root = File.cwd!()
    expected = Path.relative_to(__ENV__.file, root)
    assert expected == Mod.current_path(__MODULE__)
  end

  test "listing all modules in an otp application" do
    mods = Mod.list_all(:modkit)
    assert Modkit in mods
    assert Mod in mods
  end

  test "listing modules by files" do
    mods = Mod.list_by_file(:modkit)
    assert Map.has_key?(mods, "lib/modkit.ex")
    assert [Modkit] == Map.fetch!(mods, "lib/modkit.ex")
    assert [Modkit] == Map.fetch!(mods, "lib/modkit.ex")

    assert Enum.sort([Modkit.Mount, Modkit.Mount.Point]) ==
             Enum.sort(Map.fetch!(mods, "lib/modkit/mount.ex"))
  end

  test "get a local root between modules of several modules" do
    # a local root is a common prefix that is also a member of the candidates.
    # For instance A is the local root for [A, A.B, A.C] But in [A.B, A.C] there
    # is no local root. In that way, the local root is different from a "common
    # prefix". Here we want a module that exists, not just a prefix.
    assert AAA = Mod.local_root(AAA, AAA.BBB)
  end
end
