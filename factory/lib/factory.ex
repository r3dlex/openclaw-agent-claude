defmodule Factory do
  @moduledoc """
  Software Factory: an Elixir/OTP backend that manages multiple
  Claude Code CLI sessions as supervised processes.

  The Factory exposes an HTTP API + SSE event stream for the
  OpenClaw agent to launch, monitor, and interact with sessions.
  """

  def data_dir, do: Application.get_env(:factory, :data_dir, "/data")
  def max_sessions, do: Application.get_env(:factory, :max_sessions, 5)
  def claude_cli_path, do: Application.get_env(:factory, :claude_cli_path, "claude")
  def default_model, do: Application.get_env(:factory, :default_model, "claude-opus-4-20250514")

  @valid_models ["claude-opus-4-20250514", "claude-sonnet-4-20250514", "claude-haiku-4-20250514"]
  def valid_models, do: @valid_models

  def valid_model?(model), do: model in @valid_models
  def default_permission_mode, do: Application.get_env(:factory, :default_permission_mode, "dangerously-skip-permissions")
end
