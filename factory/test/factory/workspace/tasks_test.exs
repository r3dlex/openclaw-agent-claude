defmodule Factory.Workspace.TasksTest do
  use ExUnit.Case, async: false

  setup do
    dir =
      System.tmp_dir!()
      |> Path.join("factory_tasks_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    Application.put_env(:factory, :data_dir, dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  describe "read/0" do
    test "returns empty string when file doesn't exist" do
      assert {:ok, ""} = Factory.Workspace.Tasks.read()
    end

    test "returns content when file exists" do
      :ok = Factory.Workspace.Tasks.write("- [ ] do something\n")
      assert {:ok, content} = Factory.Workspace.Tasks.read()
      assert String.contains?(content, "do something")
    end
  end

  describe "write/1" do
    test "writes content and returns :ok" do
      assert :ok = Factory.Workspace.Tasks.write("- [ ] a task\n")
    end
  end

  describe "parse/0" do
    test "returns empty list for empty file" do
      assert {:ok, []} = Factory.Workspace.Tasks.parse()
    end

    test "parses unchecked tasks" do
      Factory.Workspace.Tasks.write("- [ ] first task\n- [ ] second task\n")
      {:ok, tasks} = Factory.Workspace.Tasks.parse()
      assert length(tasks) == 2
      refute Enum.at(tasks, 0).checked
      assert Enum.at(tasks, 0).text == "first task"
      assert Enum.at(tasks, 1).text == "second task"
    end

    test "parses checked tasks [x]" do
      Factory.Workspace.Tasks.write("- [x] done task\n")
      {:ok, tasks} = Factory.Workspace.Tasks.parse()
      assert hd(tasks).checked
      assert hd(tasks).text == "done task"
    end

    test "parses checked tasks [X] (uppercase)" do
      Factory.Workspace.Tasks.write("- [X] done uppercase\n")
      {:ok, tasks} = Factory.Workspace.Tasks.parse()
      assert hd(tasks).checked
    end

    test "ignores non-task lines" do
      Factory.Workspace.Tasks.write("# Header\n- [ ] real task\nsome plain text\n")
      {:ok, tasks} = Factory.Workspace.Tasks.parse()
      assert length(tasks) == 1
      assert hd(tasks).text == "real task"
    end

    test "includes line index in each task" do
      Factory.Workspace.Tasks.write("- [ ] task one\n- [ ] task two\n")
      {:ok, tasks} = Factory.Workspace.Tasks.parse()
      assert is_integer(Enum.at(tasks, 0).index)
      assert is_integer(Enum.at(tasks, 1).index)
    end
  end

  describe "update_task/2" do
    test "marks unchecked task as checked" do
      Factory.Workspace.Tasks.write("- [ ] task one\n")
      assert {:ok, content} = Factory.Workspace.Tasks.update_task(0, true)
      assert String.contains?(content, "[x]")
    end

    test "marks checked task as unchecked" do
      Factory.Workspace.Tasks.write("- [x] done task\n")
      assert {:ok, content} = Factory.Workspace.Tasks.update_task(0, false)
      assert String.contains?(content, "[ ]")
    end

    test "returns error for out-of-range index" do
      Factory.Workspace.Tasks.write("- [ ] only task\n")
      assert {:error, :index_out_of_range} = Factory.Workspace.Tasks.update_task(5, true)
    end

    test "returns error for negative index" do
      Factory.Workspace.Tasks.write("- [ ] task\n")
      assert {:error, :index_out_of_range} = Factory.Workspace.Tasks.update_task(-1, true)
    end

    test "returns error when no tasks exist" do
      assert {:error, :index_out_of_range} = Factory.Workspace.Tasks.update_task(0, true)
    end

    test "handles multiple tasks — updates correct one" do
      Factory.Workspace.Tasks.write("- [ ] first\n- [ ] second\n- [ ] third\n")
      {:ok, content} = Factory.Workspace.Tasks.update_task(1, true)
      lines = String.split(content, "\n")
      assert String.contains?(Enum.at(lines, 1), "[x]")
    end
  end
end
