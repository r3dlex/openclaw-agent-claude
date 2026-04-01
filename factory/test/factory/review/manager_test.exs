defmodule Factory.Review.ManagerTest do
  use ExUnit.Case, async: false

  describe "list/0" do
    test "returns a list (may be empty)" do
      assert is_list(Factory.Review.Manager.list())
    end
  end

  describe "get/1" do
    test "returns {:error, :not_found} for unknown review id" do
      assert {:error, :not_found} = Factory.Review.Manager.get("no_such_review_id")
    end
  end

  describe "launch/1 — success path" do
    test "returns {:ok, id} for valid codebase review params" do
      # Set max_sessions=0 so the Evaluator's internal session launch fails
      # gracefully (no Worker crash flood), but the Manager.launch itself succeeds.
      orig = Application.get_env(:factory, :max_sessions)
      Application.put_env(:factory, :max_sessions, 0)

      assert {:ok, id} =
               Factory.Review.Manager.launch(type: :codebase, target: ".", workdir: "/tmp")

      assert is_binary(id)
      Application.put_env(:factory, :max_sessions, orig)
    end

    test "returns {:ok, id} for valid pr review params" do
      orig = Application.get_env(:factory, :max_sessions)
      Application.put_env(:factory, :max_sessions, 0)

      assert {:ok, id} =
               Factory.Review.Manager.launch(type: :pr, target: "main", workdir: "/tmp")

      assert is_binary(id)
      Application.put_env(:factory, :max_sessions, orig)
    end
  end

  describe "launch/1 — validation errors" do
    test "returns error for missing type (nil)" do
      assert {:error, :missing_type, msg} =
               Factory.Review.Manager.launch(target: "main", workdir: "/tmp")

      assert is_binary(msg)
    end

    test "returns error for invalid type atom" do
      assert {:error, :invalid_type, msg} =
               Factory.Review.Manager.launch(type: :banana, target: "main", workdir: "/tmp")

      assert is_binary(msg)
    end

    test "returns error for invalid type string (converted by router from unknown string)" do
      assert {:error, :invalid_type, _} =
               Factory.Review.Manager.launch(type: "not_valid", target: "main", workdir: "/tmp")
    end

    test "returns error for nil target" do
      assert {:error, :missing_target, _} =
               Factory.Review.Manager.launch(type: :pr, target: nil, workdir: "/tmp")
    end

    test "returns error for empty string target" do
      assert {:error, :missing_target, _} =
               Factory.Review.Manager.launch(type: :pr, target: "", workdir: "/tmp")
    end

    test "returns error for nil workdir" do
      assert {:error, :missing_workdir, _} =
               Factory.Review.Manager.launch(type: :pr, target: "main", workdir: nil)
    end

    test "returns error for empty string workdir" do
      assert {:error, :missing_workdir, _} =
               Factory.Review.Manager.launch(type: :codebase, target: ".", workdir: "")
    end
  end
end
