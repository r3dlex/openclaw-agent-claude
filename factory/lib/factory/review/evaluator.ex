defmodule Factory.Review.Evaluator do
  @moduledoc """
  Launches and manages code review sessions.

  Supports two modes:
  - **Codebase review**: Evaluate an entire repository
  - **PR review**: Evaluate a specific pull request (git diff)

  Each review is backed by a Claude CLI session with a specialized prompt
  that produces structured scoring output.
  """
  use GenServer
  require Logger

  defstruct [
    :id,
    :type,
    :target,
    :workdir,
    :session_name,
    :model,
    :started_at,
    :completed_at,
    status: :pending,
    score: nil,
    raw_output: nil,
    error: nil
  ]

  # ── Public API ──

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: via(opts[:id]))

  def get(id), do: GenServer.call(via(id), :get)
  def status(id), do: GenServer.call(via(id), :status)

  defp via(id), do: {:via, Registry, {Factory.Review.Registry, id}}

  # ── GenServer Callbacks ──

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    type = Keyword.fetch!(opts, :type)
    target = Keyword.fetch!(opts, :target)
    workdir = Keyword.get(opts, :workdir, ".")
    model = Keyword.get(opts, :model, Factory.default_model())

    state = %__MODULE__{
      id: id,
      type: type,
      target: target,
      workdir: workdir,
      model: model,
      session_name: "review-#{id}",
      started_at: DateTime.utc_now()
    }

    {:ok, state, {:continue, :launch}}
  end

  @impl true
  def handle_continue(:launch, state) do
    prompt = build_review_prompt(state.type, state.target)

    session_opts = [
      name: state.session_name,
      prompt: prompt,
      workdir: state.workdir,
      model: state.model,
      budget: review_budget(state.type),
      multi_turn: false
    ]

    case Factory.Session.Manager.launch(session_opts) do
      {:ok, _name} ->
        # Subscribe to session events to know when it finishes
        Factory.Events.Bus.subscribe(state.session_name)

        Factory.Events.Bus.publish(:review_started, %{
          id: state.id,
          type: state.type,
          target: state.target,
          session: state.session_name
        })

        {:noreply, %{state | status: :running}}

      {:error, code, msg} ->
        Logger.error("Failed to launch review session #{state.id}: #{code} - #{msg}")
        {:noreply, %{state | status: :failed, error: "#{code}: #{msg}"}}
    end
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, to_result(state), state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_info({:factory_event, %{type: :session_ended, payload: %{name: name}}}, state)
      when name == state.session_name do
    # Session completed; read output and parse scores
    case Factory.Session.Worker.output(state.session_name, full: true) do
      {:ok, lines} ->
        raw = Enum.join(lines, "\n")
        process_review_output(state, raw)

      _ ->
        {:noreply, %{state | status: :failed, error: "Could not read session output"}}
    end
  end

  def handle_info({:factory_event, _}, state), do: {:noreply, state}

  # ── Private ──

  defp process_review_output(state, raw) do
    case Factory.Review.Scoring.parse_review_output(raw) do
      {:ok, score} ->
        now = DateTime.utc_now()

        Factory.Events.Bus.publish(:review_completed, %{
          id: state.id,
          type: state.type,
          composite_score: score.composite,
          verdict: score.verdict
        })

        {:noreply, %{state | status: :completed, score: score, raw_output: raw, completed_at: now}}

      {:error, reason} ->
        Logger.warning("Review #{state.id}: could not parse scores (#{reason}), storing raw output")

        Factory.Events.Bus.publish(:review_completed, %{
          id: state.id,
          type: state.type,
          composite_score: nil,
          verdict: :parse_error,
          error: reason
        })

        {:noreply, %{state | status: :completed, raw_output: raw, completed_at: DateTime.utc_now(), error: "Score parsing failed: #{reason}"}}
    end
  end

  defp build_review_prompt(:codebase, target) do
    categories = format_categories()

    """
    You are a Senior Code Reviewer performing a comprehensive codebase evaluation.

    TARGET: #{target}

    Evaluate the codebase across these categories, scoring each 0-100:

    #{categories}

    INSTRUCTIONS:
    1. Explore the codebase structure, key files, and architecture.
    2. For each category, identify specific findings (issues, strengths, risks).
    3. Assign a score (0-100) for each category based on your findings.
    4. Write a brief summary (2-3 sentences) of the overall quality.

    OUTPUT FORMAT: Respond with ONLY a JSON object (no markdown fences):
    {
      "security": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "design": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "style": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "practices": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "documentation": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "summary": "Overall assessment..."
    }
    """
  end

  defp build_review_prompt(:pr, target) do
    categories = format_categories()

    """
    You are a Senior Code Reviewer evaluating a Pull Request.

    PR TARGET: #{target}

    First, run: git diff #{target}
    If that fails, try: git log --oneline -20 and identify the relevant changes.

    Evaluate the PR changes across these categories, scoring each 0-100:

    #{categories}

    FOCUS ON:
    - Changes introduced in this PR only (not pre-existing issues)
    - Whether the PR improves or degrades each category
    - Breaking changes, regressions, or new vulnerabilities

    INSTRUCTIONS:
    1. Read the diff carefully.
    2. Check test coverage for changed code.
    3. Verify no secrets, credentials, or sensitive data in the diff.
    4. Check for design pattern compliance and coding standards.
    5. Assign a score (0-100) for each category.
    6. Write a brief summary with accept/reject recommendation.

    OUTPUT FORMAT: Respond with ONLY a JSON object (no markdown fences):
    {
      "security": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "design": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "style": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "practices": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "documentation": {"score": N, "findings": [{"severity": "high|medium|low", "description": "..."}]},
      "summary": "Overall assessment..."
    }
    """
  end

  defp format_categories do
    Factory.Review.Scoring.categories()
    |> Enum.map(fn {cat, %{weight: w, description: desc}} ->
      "- **#{cat}** (weight: #{round(w * 100)}%): #{desc}"
    end)
    |> Enum.join("\n")
  end

  defp review_budget(:pr), do: 3.0
  defp review_budget(:codebase), do: 8.0

  defp to_result(state) do
    base = %{
      id: state.id,
      type: state.type,
      target: state.target,
      workdir: state.workdir,
      model: state.model,
      status: state.status,
      session: state.session_name,
      started_at: state.started_at,
      completed_at: state.completed_at,
      error: state.error
    }

    if state.score do
      Map.put(base, :score, Factory.Review.Scoring.to_map(state.score))
    else
      base
    end
  end
end
