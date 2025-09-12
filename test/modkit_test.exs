defmodule Modkit.ModkitTest do
  alias Modkit.Mount
  use ExUnit.Case, async: true

  test "get the current project" do
    assert %{otp_app: :modkit, mount: mount} = Modkit.load_current_project()
    assert {:ok, Modkit.Mod.current_path(Modkit)} == Mount.preferred_path(mount, Modkit)
  end
end
