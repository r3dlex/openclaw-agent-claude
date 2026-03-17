defmodule Factory.Session.Manager do
  @moduledoc """
  Session lifecycle manager.

  Responsibilities:
  - Enforce max concurrent session limit
  - Launch new sessions through the DynamicSupervisor
  - Periodic sweep: kill idle sessions, GC completed ones
  - List and query sessions
  """
  use GenServer
  require Logger

  @sweep_interval :timer.minutes(1)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  # ── Public API ──

  def launch(opts), do: GenServer.call(__MODULE__, {:launch, opts})

  def list_sessions(filter \\ nil) do
    Registry.select(Factory.Session.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {name, _pid} ->
      try do
        Factory.Session.Worker.info(name)
      catch
        :exit, _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> maybe_filter(filter)
  end

  def stats do
    sessions = list_sessions()

    %{
      total: length(sessions),
      running: Enum.count(sessions, &(&1.status == :running)),
      waiting: Enum.count(sessions, &(&1.status == :waiting)),
      completed: Enum.count(sessions, &(&1.status == :completed)),
      crashed: Enum.count(sessions, &(&1.status == :crashed)),
      killed: Enum.count(sessions, &(&1.status == :killed))
    }
  end

  # ── GenServer ──

  @impl true
  def init(_) do
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:launch, opts}, _from, state) do
    max = Factory.max_sessions()
    running = count_active_sessions()

    if running >= max do
      {:reply, {:error, :max_sessions_reached, "#{running}/#{max} sessions active"}, state}
    else
      name = Keyword.fetch!(opts, :name)

      case Registry.lookup(Factory.Session.Registry, name) do
        [{_pid, _}] ->
          {:reply, {:error, :name_taken, "Session '#{name}' already exists"}, state}

        [] ->
          case DynamicSupervisor.start_child(
                 Factory.Session.Supervisor,
                 {Factory.Session.Worker, opts}
               ) do
            {:ok, _pid} ->
              Logger.info("Launched session: #{name}")
              {:reply, {:ok, name}, state}

            {:error, reason} ->
              {:reply, {:error, :launch_failed, inspect(reason)}, state}
          end
      end
    end
  end

  @impl true
  def handle_info(:sweep, state) do
    idle_timeout = Application.get_env(:factory, :idle_timeout_minutes, 30)
    gc_timeout = Application.get_env(:factory, :session_gc_minutes, 60)
    now = DateTime.utc_now()

    sessions = list_sessions()

    # Kill idle running sessions
    Enum.each(sessions, fn session ->
      if session.status in [:running, :waiting] do
        idle_minutes = DateTime.diff(now, session.last_activity_at, :minute)

        if idle_minutes > idle_timeout do
          Logger.warn("Killing idle session #{session.name} (idle #{idle_minutes}m)")

          try do
            Factory.Session.Worker.kill(session.name)
          catch
            :exit, _ -> :ok
          end

          Factory.Events.Bus.publish(:session_timeout, %{
            name: session.name,
            idle_minutes: idle_minutes
          })
        end
      end
    end)

    # GC completed/crashed/killed sessions
    Enum.each(sessions, fn session ->
      if session.status in [:completed, :crashed, :killed] do
        age_minutes = DateTime.diff(now, session.last_activity_at, :minute)

        if age_minutes > gc_timeout do
          Logger.info("GC session #{session.name} (#{session.status}, #{age_minutes}m old)")

          pid =
            case Registry.lookup(Factory.Session.Registry, session.name) do
              [{pid, _}] -> pid
              _ -> nil
            end

          if pid, do: DynamicSupervisor.terminate_child(Factory.Session.Supervisor, pid)
        end
      end
    end)

    schedule_sweep()
    {:noreply, state}
  end

  # ── Private ──

  defp count_active_sessions do
    list_sessions()
    |> Enum.count(&(&1.status in [:running, :waiting, :starting]))
  end

  defp maybe_filter(sessions, nil), do: sessions

  defp maybe_filter(sessions, status) when is_atom(status) do
    Enum.filter(sessions, &(&1.status == status))
  end

  defp maybe_filter(sessions, status) when is_binary(status) do
    maybe_filter(sessions, String.to_existing_atom(status))
  rescue
    ArgumentError -> sessions
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval)
  end
end
