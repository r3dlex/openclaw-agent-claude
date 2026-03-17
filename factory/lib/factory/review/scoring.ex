defmodule Factory.Review.Scoring do
  @moduledoc """
  Scoring engine for code reviews and PR evaluations.

  Produces a weighted composite score (0-100%) across five categories:
  security, design compliance, coding style, good practices, documentation.
  """

  @categories %{
    security: %{weight: 0.25, description: "Vulnerabilities, secrets, auth, input validation, OWASP compliance"},
    design: %{weight: 0.25, description: "Architecture compliance, DDD boundaries, SOLID, abstractions, dependencies"},
    style: %{weight: 0.15, description: "Naming, formatting, consistency, language idioms, Clean Code"},
    practices: %{weight: 0.20, description: "Testing, error handling, logging, DRY, performance, edge cases"},
    documentation: %{weight: 0.15, description: "Inline comments, API docs, README, migration notes, changelog"}
  }

  defstruct [
    :security,
    :design,
    :style,
    :practices,
    :documentation,
    :composite,
    :verdict,
    findings: [],
    summary: ""
  ]

  @doc """
  Returns the category definitions with weights and descriptions.
  """
  def categories, do: @categories

  @doc """
  Computes a composite score from individual category scores.

  Each category score must be 0-100. The composite is a weighted average
  rounded to the nearest integer.
  """
  def compute(%{} = scores) do
    weighted =
      Enum.reduce(@categories, 0.0, fn {cat, %{weight: w}}, acc ->
        acc + Map.get(scores, cat, 0) * w
      end)

    composite = round(weighted)

    %__MODULE__{
      security: Map.get(scores, :security, 0),
      design: Map.get(scores, :design, 0),
      style: Map.get(scores, :style, 0),
      practices: Map.get(scores, :practices, 0),
      documentation: Map.get(scores, :documentation, 0),
      composite: composite,
      verdict: verdict(composite),
      findings: Map.get(scores, :findings, []),
      summary: Map.get(scores, :summary, "")
    }
  end

  @doc """
  Parses structured review output from a Claude session into category scores.

  Expects JSON output with keys matching category names, each containing a
  `score` (0-100) field and optionally a `findings` list.
  """
  def parse_review_output(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> parse_review_data(data)
      {:error, _} -> extract_scores_from_text(json_string)
    end
  end

  def parse_review_output(_), do: {:error, :invalid_input}

  defp parse_review_data(data) when is_map(data) do
    scores =
      Enum.reduce(@categories, %{}, fn {cat, _}, acc ->
        cat_str = Atom.to_string(cat)

        score =
          case data[cat_str] do
            %{"score" => s} when is_number(s) -> clamp(s)
            s when is_number(s) -> clamp(s)
            _ -> 0
          end

        Map.put(acc, cat, score)
      end)

    findings =
      Enum.flat_map(Map.keys(@categories), fn cat ->
        case data[Atom.to_string(cat)] do
          %{"findings" => f} when is_list(f) ->
            Enum.map(f, &Map.put(&1, "category", Atom.to_string(cat)))

          _ ->
            []
        end
      end)

    summary = data["summary"] || ""
    result = compute(Map.merge(scores, %{findings: findings, summary: summary}))
    {:ok, result}
  end

  defp parse_review_data(_), do: {:error, :invalid_format}

  defp extract_scores_from_text(text) do
    # Fallback: try to find a JSON block in the text
    case Regex.run(~r/\{[\s\S]*"security"[\s\S]*\}/m, text) do
      [json] -> parse_review_output(json)
      _ -> {:error, :no_scores_found}
    end
  end

  defp clamp(score) when score < 0, do: 0
  defp clamp(score) when score > 100, do: 100
  defp clamp(score), do: round(score)

  defp verdict(score) when score >= 90, do: :approve
  defp verdict(score) when score >= 70, do: :approve_with_comments
  defp verdict(score) when score >= 50, do: :request_changes
  defp verdict(_score), do: :reject

  @doc """
  Serializes a scoring result to a map suitable for JSON encoding.
  """
  def to_map(%__MODULE__{} = score) do
    %{
      categories: %{
        security: %{score: score.security, weight: @categories.security.weight},
        design: %{score: score.design, weight: @categories.design.weight},
        style: %{score: score.style, weight: @categories.style.weight},
        practices: %{score: score.practices, weight: @categories.practices.weight},
        documentation: %{score: score.documentation, weight: @categories.documentation.weight}
      },
      composite_score: score.composite,
      verdict: score.verdict,
      findings: score.findings,
      summary: score.summary
    }
  end
end
