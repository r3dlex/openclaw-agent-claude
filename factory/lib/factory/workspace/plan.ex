defmodule Factory.Workspace.Plan do
  @moduledoc """
  Read/write PLAN.md from AGENT_DATA_DIR.
  """

  def path, do: Path.join(Factory.data_dir(), "PLAN.md")

  def read do
    case File.read(path()) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:ok, ""}
      {:error, reason} -> {:error, reason}
    end
  end

  def write(content) do
    result = File.write(path(), content)
    if result == :ok, do: Factory.Events.Bus.publish(:plan_updated, %{})
    result
  end
end
