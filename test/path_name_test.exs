defmodule Modkit.PathRenameTest do
  use ExUnit.Case, async: true
  alias Modkit.PathTool

  test "renaming various paths" do
    assert "hello" = PathTool.to_snake("hello")
    assert "hello" = PathTool.to_snake("Hello")
    assert "hello_world" = PathTool.to_snake("HelloWorld")
    assert "hello_world" = PathTool.to_snake("Hello_World")
    assert "hello_world" = PathTool.to_snake("Hello____World")
  end

  test "renaming with number" do
    assert "ab2cd_hello" = PathTool.to_snake("AB2CD_Hello")
  end
end
