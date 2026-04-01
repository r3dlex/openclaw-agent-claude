defmodule FactoryTest do
  use ExUnit.Case

  test "data_dir is configurable" do
    assert is_binary(Factory.data_dir())
  end

  test "max_sessions has a default" do
    assert Factory.max_sessions() > 0
  end

  test "claude_cli_path returns a string" do
    assert is_binary(Factory.claude_cli_path())
  end

  test "default_model returns a valid model string" do
    model = Factory.default_model()
    assert is_binary(model)
    assert model in Factory.valid_models()
  end

  test "valid_models returns a non-empty list of strings" do
    models = Factory.valid_models()
    assert is_list(models)
    assert length(models) > 0
    Enum.each(models, &assert(is_binary(&1)))
  end

  test "valid_model? returns true for a known model" do
    [first | _] = Factory.valid_models()
    assert Factory.valid_model?(first)
  end

  test "valid_model? returns false for an unknown model" do
    refute Factory.valid_model?("gpt-4o")
  end

  test "default_permission_mode returns a string" do
    assert is_binary(Factory.default_permission_mode())
  end
end
