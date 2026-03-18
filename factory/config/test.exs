import Config

config :factory,
  data_dir: System.tmp_dir!(),
  port: 4002,
  max_sessions: 2,
  idle_timeout_minutes: 5,
  session_gc_minutes: 5
