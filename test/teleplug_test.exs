defmodule TeleplugTest do
  use ExUnit.Case
  doctest Teleplug

  test "greets the world" do
    assert Teleplug.hello() == :world
  end
end
