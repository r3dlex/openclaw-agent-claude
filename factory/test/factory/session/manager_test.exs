defmodule Factory.Session.ManagerTest do
  use ExUnit.Case, async: false

  describe "stats/0" do
    test "returns a map with all expected stat keys" do
      stats = Factory.Session.Manager.stats()
      assert is_map(stats)
      assert Map.has_key?(stats, :total)
      assert Map.has_key?(stats, :running)
      assert Map.has_key?(stats, :waiting)
      assert Map.has_key?(stats, :completed)
      assert Map.has_key?(stats, :crashed)
      assert Map.has_key?(stats, :killed)
    end

    test "all stat values are non-negative integers" do
      stats = Factory.Session.Manager.stats()
      Enum.each(stats, fn {_k, v} -> assert is_integer(v) and v >= 0 end)
    end
  end

  describe "list_sessions/0" do
    test "returns a list" do
      assert is_list(Factory.Session.Manager.list_sessions())
    end

    test "accepts nil filter" do
      assert is_list(Factory.Session.Manager.list_sessions(nil))
    end

    test "accepts atom filter for known status" do
      assert is_list(Factory.Session.Manager.list_sessions(:running))
    end

    test "accepts string filter for known status" do
      assert is_list(Factory.Session.Manager.list_sessions("running"))
    end

    test "accepts string filter for unknown status (returns all without crashing)" do
      assert is_list(Factory.Session.Manager.list_sessions("nonexistent_status_xyz"))
    end
  end

  describe "launch/1 — capacity enforcement" do
    test "returns max_sessions_reached when capacity is 0" do
      orig = Application.get_env(:factory, :max_sessions)
      Application.put_env(:factory, :max_sessions, 0)

      assert {:error, :max_sessions_reached, msg} =
               Factory.Session.Manager.launch(name: "test_launch", prompt: "hello")

      assert is_binary(msg)
      Application.put_env(:factory, :max_sessions, orig)
    end
  end

  describe "manual sweep trigger" do
    test "manager remains alive after receiving :sweep message" do
      pid = Process.whereis(Factory.Session.Manager)
      assert pid != nil
      assert Process.alive?(pid)
      send(pid, :sweep)
      Process.sleep(50)
      assert Process.alive?(pid)
    end
  end
end
