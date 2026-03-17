defmodule Factory.Session.Worker do
  @moduledoc """
  GenServer wrapping a single Claude Code CLI process via Erlang Port.

  Each worker manages:
  - A background `claude` CLI process with --dangerously-skip-permissions
  - Output buffering (last N lines + full log on disk)
  - Status tracking (running, waiting, completed, crashed, killed)
  - stdin forwarding for multi-turn interaction
  """
  use GenServer
  require Logger

  @max_buffer_lines 500

  defstruct [
    :name,
    :workdir,
    :port,
    :os_pid,
    :prompt,
    :model,
    :log_path,
    budget: 5.0,
    multi_turn: true,
    status: :starting,
    output: [],
    exit_code: nil,
    created_at: nil,
    last_activity_at: nil
  ]

  # ── Public API ──

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via(name))
  end

  def respond(name, message), do: GenServer.call(via(name), {:respond, message})
  def kill(name), do: GenServer.call(via(name), :kill)
  def output(name, opts \\ []), do: GenServer.call(via(name), {:output, opts})
  def status(name), do: GenServer.call(via(name), :status)
  def info(name), do: GenServer.call(via(name), :info)

  defp via(name), do: {:via, Registry, {Factory.Session.Registry, name}}

  # ── GenServer Callbacks ──

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    now = DateTime.utc_now()

    state = %__MODULE__{
      name: name,
      workdir: Keyword.get(opts, :workdir, "."),
      prompt: Keyword.fetch!(opts, :prompt),
      model: Keyword.get(opts, :model, Factory.default_model()),
      budget: Keyword.get(opts, :budget, 5.0),
      multi_turn: Keyword.get(opts, :multi_turn, true),
      log_path: Path.join([Factory.data_dir(), "logs", "#{name}.log"]),
      created_at: now,
      last_activity_at: now
    }

    {:ok, state, {:continue, :launch}}
  end

  @impl true
  def handle_continue(:launch, state) do
    args = build_cli_args(state)
    cli = Factory.claude_cli_path()

    Logger.info("Launching session #{state.name}: #{cli} #{Enum.join(args, " ")}")

    port =
      Port.open({:spawn_executable, System.find_executable(cli) || cli}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        {:args, args},
        {:cd, state.workdir},
        {:line, 65_536}
      ])

    os_pid =
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> pid
        _ -> nil
      end

    Factory.Events.Bus.publish(:session_started, %{
      name: state.name,
      workdir: state.workdir,
      model: state.model
    })

    # Write initial log entry
    File.write!(state.log_path, "# Session: #{state.name}\n# Started: #{state.created_at}\n# Workdir: #{state.workdir}\n\n")

    {:noreply, %{state | port: port, os_pid: os_pid, status: :running}}
  end

  @impl true
  def handle_call({:respond, message}, _from, %{port: port, status: status} = state)
      when status in [:running, :waiting] do
    Port.command(port, "#{message}\n")
    Logger.info("Session #{state.name}: sent response (#{byte_size(message)} bytes)")

    Factory.Events.Bus.publish(:session_responded, %{
      name: state.name,
      message_length: byte_size(message)
    })

    {:reply, :ok, %{state | status: :running, last_activity_at: DateTime.utc_now()}}
  end

  def handle_call({:respond, _message}, _from, state) do
    {:reply, {:error, :not_accepting_input}, state}
  end

  @impl true
  def handle_call(:kill, _from, %{port: port, os_pid: os_pid} = state) do
    Logger.info("Killing session #{state.name}")

    if os_pid, do: System.cmd("kill", ["-9", "#{os_pid}"], stderr_to_stdout: true)

    try do
      Port.close(port)
    catch
      _, _ -> :ok
    end

    Factory.Events.Bus.publish(:session_killed, %{name: state.name})
    {:reply, :ok, %{state | status: :killed}}
  end

  @impl true
  def handle_call({:output, opts}, _from, state) do
    lines =
      if Keyword.get(opts, :full, false) do
        state.output
      else
        count = Keyword.get(opts, :lines, 50)
        Enum.take(state.output, -count)
      end

    {:reply, {:ok, lines}, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:info, _from, state) do
    info = %{
      name: state.name,
      status: state.status,
      workdir: state.workdir,
      model: state.model,
      budget: state.budget,
      multi_turn: state.multi_turn,
      output_lines: length(state.output),
      created_at: state.created_at,
      last_activity_at: state.last_activity_at,
      exit_code: state.exit_code
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    trimmed = String.trim_trailing(line)

    new_output =
      if length(state.output) >= @max_buffer_lines do
        Enum.drop(state.output, 1) ++ [trimmed]
      else
        state.output ++ [trimmed]
      end

    # Append to log file
    File.write!(state.log_path, trimmed <> "\n", [:append])

    Factory.Events.Bus.publish(:session_output, %{
      name: state.name,
      line: trimmed
    })

    # Detect if the session is waiting for input (heuristic)
    new_status =
      if waiting_for_input?(trimmed) do
        Factory.Events.Bus.publish(:session_waiting, %{
          name: state.name,
          question: trimmed
        })

        :waiting
      else
        state.status
      end

    {:noreply, %{state | output: new_output, status: new_status, last_activity_at: DateTime.utc_now()}}
  end

  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state) do
    # Partial line, buffer it
    new_output = append_to_last_line(state.output, chunk)
    {:noreply, %{state | output: new_output, last_activity_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    status = if code == 0, do: :completed, else: :crashed

    Logger.info("Session #{state.name} exited with code #{code} (#{status})")

    Factory.Events.Bus.publish(:session_ended, %{
      name: state.name,
      status: status,
      exit_code: code
    })

    File.write!(state.log_path, "\n# Ended: #{DateTime.utc_now()} (exit code: #{code})\n", [:append])

    {:noreply, %{state | status: status, exit_code: code}}
  end

  # ── Private ──

  defp build_cli_args(state) do
    base = ["--#{Factory.default_permission_mode()}"]

    base =
      if state.prompt do
        base ++ ["-p", state.prompt]
      else
        base
      end

    base =
      if state.model do
        base ++ ["--model", state.model]
      else
        base
      end

    base ++ ["--output-format", "stream-json"]
  end

  defp waiting_for_input?(line) do
    lower = String.downcase(line)

    String.contains?(lower, "do you want") or
      String.contains?(lower, "should i") or
      String.contains?(lower, "please confirm") or
      String.contains?(lower, "waiting for") or
      String.contains?(lower, "? (y/n)") or
      String.contains?(lower, "enter your")
  end

  defp append_to_last_line([], chunk), do: [chunk]

  defp append_to_last_line(lines, chunk) do
    {init, [last]} = Enum.split(lines, -1)
    init ++ [last <> chunk]
  end
end
