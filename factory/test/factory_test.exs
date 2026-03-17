defmodule FactoryTest do
  use ExUnit.Case

  test "data_dir is configurable" do
    assert is_binary(Factory.data_dir())
  end

  test "max_sessions has a default" do
    assert Factory.max_sessions() > 0
  end
end
