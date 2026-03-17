defmodule Factory.Review.Manager do
  @moduledoc """
  Manages the lifecycle of code review evaluations.

  Handles launching reviews, tracking active reviews, and providing
  access to results. Reviews are backed by Factory.Review.Evaluator
  GenServer instances running under a DynamicSupervisor.
  """
  require Logger

  @doc """
  Launch a new code review.

  Options:
  - `type`: `:codebase` or `:pr` (required)
  - `target`: what to review. For `:pr`, a branch/ref/range. For `:codebase`, a path or description (required)
  - `workdir`: working directory for the review session (required)
  - `model`: model override (optional, defaults to Factory.default_model())

  Returns `{:ok, review_id}` or `{:error, code, message}`.
  """
  def launch(opts) do
    type = Keyword.get(opts, :type)
    target = Keyword.get(opts, :target)
    workdir = Keyword.get(opts, :workdir)

    with :ok <- validate_type(type),
         :ok <- validate_target(target),
         :ok <- validate_workdir(workdir) do
      id = generate_id()

      child_opts = [
        id: id,
        type: type,
        target: target,
        workdir: workdir,
        model: Keyword.get(opts, :model)
      ]

      case DynamicSupervisor.start_child(Factory.Review.Supervisor, {Factory.Review.Evaluator, child_opts}) do
        {:ok, _pid} ->
          Logger.info("Review #{id} launched (#{type}: #{target})")
          {:ok, id}

        {:error, reason} ->
          Logger.error("Failed to start review #{id}: #{inspect(reason)}")
          {:error, :launch_failed, "Could not start review: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Get the result of a review by ID.
  """
  def get(id) do
    try do
      Factory.Review.Evaluator.get(id)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc """
  List all active reviews.
  """
  def list do
    Factory.Review.Registry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {id, pid} ->
      try do
        GenServer.call(pid, :get)
      catch
        :exit, _ -> %{id: id, status: :unknown}
      end
    end)
  end

  # ── Private ──

  defp validate_type(:codebase), do: :ok
  defp validate_type(:pr), do: :ok
  defp validate_type(nil), do: {:error, :missing_type, "type is required (codebase or pr)"}
  defp validate_type(t), do: {:error, :invalid_type, "Invalid type: #{t}. Must be 'codebase' or 'pr'"}

  defp validate_target(nil), do: {:error, :missing_target, "target is required"}
  defp validate_target(""), do: {:error, :missing_target, "target cannot be empty"}
  defp validate_target(_), do: :ok

  defp validate_workdir(nil), do: {:error, :missing_workdir, "workdir is required"}
  defp validate_workdir(""), do: {:error, :missing_workdir, "workdir cannot be empty"}
  defp validate_workdir(_), do: :ok

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false) |> String.downcase()
  end
end
