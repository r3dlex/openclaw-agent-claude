defmodule Factory.Workspace.Tasks do
  @moduledoc """
  Read/write tasks.md from AGENT_DATA_DIR.
  Parses markdown task lists into structured data.
  """

  def path, do: Path.join(Factory.data_dir(), "tasks.md")

  def read do
    case File.read(path()) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:ok, ""}
      {:error, reason} -> {:error, reason}
    end
  end

  def write(content) do
    File.write(path(), content)
  end

  def parse do
    case read() do
      {:ok, content} -> {:ok, parse_tasks(content)}
      error -> error
    end
  end

  def update_task(index, checked) when is_integer(index) and is_boolean(checked) do
    case read() do
      {:ok, content} ->
        lines = String.split(content, "\n")
        task_indices = find_task_lines(lines)

        if index >= 0 and index < length(task_indices) do
          line_idx = Enum.at(task_indices, index)
          line = Enum.at(lines, line_idx)

          new_line =
            if checked do
              String.replace(line, ~r/\[ \]/, "[x]", global: false)
            else
              String.replace(line, ~r/\[x\]/i, "[ ]", global: false)
            end

          new_lines = List.replace_at(lines, line_idx, new_line)
          new_content = Enum.join(new_lines, "\n")
          write(new_content)
          Factory.Events.Bus.publish(:tasks_updated, %{action: :task_toggled, index: index})
          {:ok, new_content}
        else
          {:error, :index_out_of_range}
        end

      error ->
        error
    end
  end

  # ── Private ──

  defp parse_tasks(content) do
    content
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} -> String.match?(line, ~r/^\s*-\s*\[[ xX]\]/) end)
    |> Enum.map(fn {line, idx} ->
      checked = String.match?(line, ~r/\[[xX]\]/)
      text = Regex.replace(~r/^\s*-\s*\[[ xX]\]\s*/, line, "")
      %{index: idx, checked: checked, text: String.trim(text)}
    end)
  end

  defp find_task_lines(lines) do
    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} -> String.match?(line, ~r/^\s*-\s*\[[ xX]\]/) end)
    |> Enum.map(fn {_, idx} -> idx end)
  end
end
