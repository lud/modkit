defmodule Modkit.SnakeCaseTest do
  alias Modkit.SnakeCase
  use ExUnit.Case, async: true

  test "basic snake casing" do
    assert "a" = SnakeCase.to_snake("A")
    assert "a" = SnakeCase.to_snake(A)
    assert "ab" = SnakeCase.to_snake(AB)
    assert "ab_c" = SnakeCase.to_snake(AbC)
    assert "ab2_cd" = SnakeCase.to_snake(AB2CD)
  end
end
