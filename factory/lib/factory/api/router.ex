defmodule Factory.Api.Router do
  @moduledoc """
  HTTP API for the Software Factory.
  The OpenClaw agent calls these endpoints to orchestrate sessions.
  """
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :dispatch

  # ── Health ──

  get "/health" do
    send_json(conn, 200, %{status: "ok", sessions: Factory.Session.Manager.stats()})
  end

  # ── Sessions ──

  post "/api/v1/sessions" do
    params = conn.body_params

    opts = [
      name: params["name"],
      prompt: params["prompt"],
      workdir: params["workdir"] || ".",
      model: params["model"],
      budget: params["max_budget_usd"] || 5.0,
      multi_turn: Map.get(params, "multi_turn", true)
    ]

    case Factory.Session.Manager.launch(opts) do
      {:ok, name} ->
        send_json(conn, 201, %{status: "launched", name: name})

      {:error, code, msg} ->
        send_json(conn, 422, %{error: code, message: msg})
    end
  end

  get "/api/v1/sessions" do
    filter = conn.query_params["status"]
    sessions = Factory.Session.Manager.list_sessions(filter)
    send_json(conn, 200, %{sessions: sessions})
  end

  get "/api/v1/sessions/:name" do
    try do
      info = Factory.Session.Worker.info(name)
      send_json(conn, 200, info)
    catch
      :exit, _ -> send_json(conn, 404, %{error: "session_not_found"})
    end
  end

  get "/api/v1/sessions/:name/output" do
    full = conn.query_params["full"] == "true"
    lines = String.to_integer(conn.query_params["lines"] || "50")

    try do
      {:ok, output} = Factory.Session.Worker.output(name, full: full, lines: lines)
      send_json(conn, 200, %{name: name, lines: output})
    catch
      :exit, _ -> send_json(conn, 404, %{error: "session_not_found"})
    end
  end

  post "/api/v1/sessions/:name/respond" do
    message = conn.body_params["message"]
    interrupt = conn.body_params["interrupt"] || false

    if interrupt do
      # Kill and relaunch with new message as prompt
      try do
        Factory.Session.Worker.kill(name)
      catch
        :exit, _ -> :ok
      end
    end

    try do
      case Factory.Session.Worker.respond(name, message) do
        :ok -> send_json(conn, 200, %{status: "responded"})
        {:error, reason} -> send_json(conn, 422, %{error: reason})
      end
    catch
      :exit, _ -> send_json(conn, 404, %{error: "session_not_found"})
    end
  end

  post "/api/v1/sessions/:name/kill" do
    try do
      Factory.Session.Worker.kill(name)
      send_json(conn, 200, %{status: "killed"})
    catch
      :exit, _ -> send_json(conn, 404, %{error: "session_not_found"})
    end
  end

  # ── Workspace ──

  get "/api/v1/workspace/tasks" do
    {:ok, content} = Factory.Workspace.Tasks.read()
    send_json(conn, 200, %{content: content})
  end

  put "/api/v1/workspace/tasks" do
    content = conn.body_params["content"]
    :ok = Factory.Workspace.Tasks.write(content)
    Factory.Events.Bus.publish(:tasks_updated, %{action: :overwrite})
    send_json(conn, 200, %{status: "updated"})
  end

  patch "/api/v1/workspace/tasks/:index" do
    idx = String.to_integer(index)
    checked = conn.body_params["checked"]

    case Factory.Workspace.Tasks.update_task(idx, checked) do
      {:ok, _} -> send_json(conn, 200, %{status: "updated"})
      {:error, reason} -> send_json(conn, 422, %{error: reason})
    end
  end

  get "/api/v1/workspace/plan" do
    {:ok, content} = Factory.Workspace.Plan.read()
    send_json(conn, 200, %{content: content})
  end

  put "/api/v1/workspace/plan" do
    content = conn.body_params["content"]
    :ok = Factory.Workspace.Plan.write(content)
    send_json(conn, 200, %{status: "updated"})
  end

  # ── Events (SSE) ──

  get "/api/v1/events" do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    Factory.Events.Bus.subscribe()
    sse_loop(conn)
  end

  get "/api/v1/sessions/:name/events" do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    Factory.Events.Bus.subscribe(name)
    sse_loop(conn)
  end

  # ── Reviews ──

  post "/api/v1/reviews" do
    params = conn.body_params

    type =
      case params["type"] do
        "codebase" -> :codebase
        "pr" -> :pr
        other -> other
      end

    opts = [
      type: type,
      target: params["target"],
      workdir: params["workdir"] || ".",
      model: params["model"]
    ]

    case Factory.Review.Manager.launch(opts) do
      {:ok, id} ->
        send_json(conn, 201, %{status: "launched", id: id, type: type})

      {:error, code, msg} ->
        send_json(conn, 422, %{error: code, message: msg})
    end
  end

  get "/api/v1/reviews" do
    reviews = Factory.Review.Manager.list()
    send_json(conn, 200, %{reviews: reviews})
  end

  get "/api/v1/reviews/:id" do
    case Factory.Review.Manager.get(id) do
      {:error, :not_found} ->
        send_json(conn, 404, %{error: "review_not_found"})

      result ->
        send_json(conn, 200, result)
    end
  end

  # ── Stats ──

  get "/api/v1/stats" do
    send_json(conn, 200, Factory.Session.Manager.stats())
  end

  # ── Fallback ──

  match _ do
    send_json(conn, 404, %{error: "not_found"})
  end

  # ── Helpers ──

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  defp sse_loop(conn) do
    receive do
      {:factory_event, event} ->
        data = Jason.encode!(event)
        chunk = "event: #{event.type}\ndata: #{data}\n\n"

        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end
    after
      30_000 ->
        # Keepalive
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end
    end
  end
end
