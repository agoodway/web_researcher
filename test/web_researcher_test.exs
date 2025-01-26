defmodule WebResearcherTest do
  use ExUnit.Case
  doctest WebResearcher

  test "greets the world" do
    assert WebResearcher.hello() == :world
  end
end
