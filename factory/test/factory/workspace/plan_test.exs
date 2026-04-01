defmodule Factory.Workspace.PlanTest do
  use ExUnit.Case, async: false

  setup do
    dir =
      System.tmp_dir!()
      |> Path.join("factory_plan_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    Application.put_env(:factory, :data_dir, dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    :ok
  end

  describe "read/0" do
    test "returns empty string when file doesn't exist" do
      assert {:ok, ""} = Factory.Workspace.Plan.read()
    end

    test "returns content when file exists" do
      Factory.Workspace.Plan.write("# My Plan\n\n- step 1\n")
      assert {:ok, content} = Factory.Workspace.Plan.read()
      assert String.contains?(content, "My Plan")
    end
  end

  describe "write/1" do
    test "writes content and returns :ok" do
      assert :ok = Factory.Workspace.Plan.write("# Plan content")
    end

    test "persists content readable by read/0" do
      :ok = Factory.Workspace.Plan.write("## Phase 1\n\nDo the thing.")
      {:ok, content} = Factory.Workspace.Plan.read()
      assert content == "## Phase 1\n\nDo the thing."
    end

    test "publishes plan_updated event on write" do
      Factory.Events.Bus.subscribe()
      Factory.Workspace.Plan.write("# Updated Plan")
      assert_receive {:factory_event, %{type: :plan_updated}}, 500
    end

    test "does not publish event when write fails (returns error)" do
      # Use a path that can't be written (write to a non-existent nested dir)
      original_dir = Application.get_env(:factory, :data_dir)
      Application.put_env(:factory, :data_dir, "/no/such/path/that/exists")

      Factory.Events.Bus.subscribe()
      # The write will fail silently (returns error) — no event published
      result = Factory.Workspace.Plan.write("content")
      assert result != :ok

      refute_receive {:factory_event, %{type: :plan_updated}}, 100
      Application.put_env(:factory, :data_dir, original_dir)
    end
  end
end
