defmodule Factory.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:factory, :port, 4000)

    # Ensure data directories exist
    data_dir = Factory.data_dir()
    File.mkdir_p!(Path.join(data_dir, "logs"))
    File.mkdir_p!(Path.join(data_dir, "sessions"))
    File.mkdir_p!(Path.join(data_dir, "memory"))

    children = [
      # Event bus (PubSub)
      {Phoenix.PubSub, name: Factory.PubSub},

      # Inter-Agent Message Queue client (register, heartbeat, inbox polling)
      Factory.MqClient,

      # Session name registry
      {Registry, keys: :unique, name: Factory.Session.Registry},

      # Dynamic supervisor for session workers
      {DynamicSupervisor, name: Factory.Session.Supervisor, strategy: :one_for_one},

      # Review registry and supervisor
      {Registry, keys: :unique, name: Factory.Review.Registry},
      {DynamicSupervisor, name: Factory.Review.Supervisor, strategy: :one_for_one},

      # Session manager (lifecycle, limits, GC)
      Factory.Session.Manager,

      # Session logger (writes to disk)
      Factory.Logging.SessionLogger,

      # HTTP API server
      {Bandit, plug: Factory.Api.Router, port: port}
    ]

    opts = [strategy: :one_for_one, name: Factory.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
