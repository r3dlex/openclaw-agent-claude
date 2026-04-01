defmodule Factory.Api.RouterTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias Factory.Api.Router

  @opts Router.init([])

  setup do
    dir =
      System.tmp_dir!()
      |> Path.join("router_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    Application.put_env(:factory, :data_dir, dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    :ok
  end

  defp call(method, path) do
    conn(method, path)
    |> put_req_header("content-type", "application/json")
    |> Router.call(@opts)
  end

  defp call_json(method, path, body) do
    conn(method, path, Jason.encode!(body))
    |> put_req_header("content-type", "application/json")
    |> Router.call(@opts)
  end

  defp json_body(conn), do: Jason.decode!(conn.resp_body)

  describe "GET /health" do
    test "returns 200 with status and sessions" do
      conn = call(:get, "/health")
      assert conn.status == 200
      body = json_body(conn)
      assert body["status"] == "ok"
      assert is_map(body["sessions"])
    end
  end

  describe "GET /api/v1/sessions" do
    test "returns 200 with sessions list" do
      conn = call(:get, "/api/v1/sessions")
      assert conn.status == 200
      assert is_list(json_body(conn)["sessions"])
    end
  end

  describe "GET /api/v1/sessions/:name" do
    test "returns 404 for unknown session name" do
      conn = call(:get, "/api/v1/sessions/no_such_session_xyz")
      assert conn.status == 404
      assert json_body(conn)["error"] == "session_not_found"
    end
  end

  describe "GET /api/v1/sessions/:name/output" do
    test "returns 404 for unknown session name" do
      conn = call(:get, "/api/v1/sessions/no_such_xyz/output")
      assert conn.status == 404
      assert json_body(conn)["error"] == "session_not_found"
    end
  end

  describe "POST /api/v1/sessions/:name/respond" do
    test "returns 404 for unknown session name" do
      conn = call_json(:post, "/api/v1/sessions/no_such_xyz/respond", %{"message" => "hi"})
      assert conn.status == 404
      assert json_body(conn)["error"] == "session_not_found"
    end
  end

  describe "POST /api/v1/sessions/:name/kill" do
    test "returns 404 for unknown session name" do
      conn = call(:post, "/api/v1/sessions/no_such_xyz/kill")
      assert conn.status == 404
      assert json_body(conn)["error"] == "session_not_found"
    end
  end

  describe "POST /api/v1/sessions" do
    test "returns 422 when at max sessions capacity (capacity=0)" do
      orig = Application.get_env(:factory, :max_sessions)
      Application.put_env(:factory, :max_sessions, 0)
      conn = call_json(:post, "/api/v1/sessions", %{"name" => "test_s", "prompt" => "hello"})
      assert conn.status == 422
      assert json_body(conn)["error"] == "max_sessions_reached"
      Application.put_env(:factory, :max_sessions, orig)
    end
  end

  describe "GET /api/v1/workspace/tasks" do
    test "returns 200 with content field" do
      conn = call(:get, "/api/v1/workspace/tasks")
      assert conn.status == 200
      assert Map.has_key?(json_body(conn), "content")
    end
  end

  describe "PUT /api/v1/workspace/tasks" do
    test "writes tasks content and returns 200" do
      conn = call_json(:put, "/api/v1/workspace/tasks", %{"content" => "- [ ] new task\n"})
      assert conn.status == 200
      assert json_body(conn)["status"] == "updated"
    end
  end

  describe "PATCH /api/v1/workspace/tasks/:index" do
    test "returns 422 when task index is out of range" do
      conn = call_json(:patch, "/api/v1/workspace/tasks/99", %{"checked" => true})
      assert conn.status == 422
    end

    test "returns 200 when toggling a valid task" do
      Factory.Workspace.Tasks.write("- [ ] test task\n")
      conn = call_json(:patch, "/api/v1/workspace/tasks/0", %{"checked" => true})
      assert conn.status == 200
      assert json_body(conn)["status"] == "updated"
    end
  end

  describe "GET /api/v1/workspace/plan" do
    test "returns 200 with content field" do
      conn = call(:get, "/api/v1/workspace/plan")
      assert conn.status == 200
      assert Map.has_key?(json_body(conn), "content")
    end
  end

  describe "PUT /api/v1/workspace/plan" do
    test "writes plan content and returns 200" do
      conn = call_json(:put, "/api/v1/workspace/plan", %{"content" => "# My Plan\n"})
      assert conn.status == 200
      assert json_body(conn)["status"] == "updated"
    end
  end

  describe "POST /api/v1/reviews — validation errors" do
    test "returns 422 when type is missing" do
      conn = call_json(:post, "/api/v1/reviews", %{"target" => "main", "workdir" => "/tmp"})
      assert conn.status == 422
      assert json_body(conn)["error"] == "missing_type"
    end

    test "returns 422 when type is invalid" do
      conn =
        call_json(:post, "/api/v1/reviews", %{
          "type" => "banana",
          "target" => "main",
          "workdir" => "/tmp"
        })

      assert conn.status == 422
    end

    test "returns 422 when target is missing" do
      conn = call_json(:post, "/api/v1/reviews", %{"type" => "pr", "workdir" => "/tmp"})
      assert conn.status == 422
      assert json_body(conn)["error"] == "missing_target"
    end

    test "returns 201 when all params are valid (codebase type)" do
      # Router defaults workdir to "." — validation passes, review launches
      conn = call_json(:post, "/api/v1/reviews", %{"type" => "codebase", "target" => "."})
      # Review starts successfully (worker crash is a background event)
      assert conn.status == 201
      body = json_body(conn)
      assert body["status"] == "launched"
      assert is_binary(body["id"])
    end
  end

  describe "GET /api/v1/reviews" do
    test "returns 200 with reviews list" do
      conn = call(:get, "/api/v1/reviews")
      assert conn.status == 200
      assert is_list(json_body(conn)["reviews"])
    end
  end

  describe "GET /api/v1/reviews/:id" do
    test "returns 404 for unknown review id" do
      conn = call(:get, "/api/v1/reviews/no_such_review_xyz")
      assert conn.status == 404
      assert json_body(conn)["error"] == "review_not_found"
    end
  end

  describe "GET /api/v1/stats" do
    test "returns 200 with stats map" do
      conn = call(:get, "/api/v1/stats")
      assert conn.status == 200
      body = json_body(conn)
      assert Map.has_key?(body, "total")
      assert Map.has_key?(body, "running")
    end
  end

  describe "catch-all" do
    test "returns 404 for completely unknown routes" do
      conn = call(:get, "/no/such/route")
      assert conn.status == 404
      assert json_body(conn)["error"] == "not_found"
    end

    test "returns 404 for unknown DELETE route" do
      conn = call(:delete, "/api/v1/unknown")
      assert conn.status == 404
    end
  end
end
