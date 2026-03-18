import Config

if config_env() != :test do
  config :factory,
    data_dir: System.get_env("AGENT_DATA_DIR", "/data"),
    port: String.to_integer(System.get_env("FACTORY_PORT", "4000")),
    api_token: System.get_env("FACTORY_API_TOKEN"),
    claude_cli_path: System.get_env("CLAUDE_CLI_PATH", "claude"),
    max_sessions: String.to_integer(System.get_env("MAX_SESSIONS", "5")),
    idle_timeout_minutes: String.to_integer(System.get_env("IDLE_TIMEOUT_MINUTES", "30")),
    session_gc_minutes: String.to_integer(System.get_env("SESSION_GC_MINUTES", "60")),
    default_model: System.get_env("DEFAULT_MODEL", "claude-opus-4-20250514"),
    default_permission_mode: System.get_env("DEFAULT_PERMISSION_MODE", "dangerously-skip-permissions")
end
