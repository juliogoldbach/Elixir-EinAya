defmodule EinAyaTest do
  use ExUnit.Case
  doctest EinAya

  test "greets the world" do
    assert EinAya.hello() == :world
  end
end
