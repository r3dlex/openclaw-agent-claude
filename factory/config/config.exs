import Config

config :factory,
  data_dir: System.get_env("AGENT_DATA_DIR", "./data"),
  max_sessions: 5,
  idle_timeout_minutes: 30,
  session_gc_minutes: 60

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:session_id]

import_config "#{config_env()}.exs"
