defmodule Factory.Logging.SessionLogger do
  @moduledoc """
  Subscribes to Factory events and writes structured logs
  to AGENT_DATA_DIR/logs/factory.log.
  """
  use GenServer
  require Logger

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    Factory.Events.Bus.subscribe()
    log_path = Path.join([Factory.data_dir(), "logs", "factory.log"])
    File.write!(log_path, "# Factory log started: #{DateTime.utc_now()}\n", [:append])
    {:ok, %{log_path: log_path}}
  end

  @impl true
  def handle_info({:factory_event, event}, state) do
    line = "[#{event.timestamp}] #{event.type}: #{Jason.encode!(event.payload)}\n"
    File.write!(state.log_path, line, [:append])
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
