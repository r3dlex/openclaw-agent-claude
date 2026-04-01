defmodule Factory.Review.ScoringTest do
  use ExUnit.Case, async: true
  alias Factory.Review.Scoring

  describe "categories/0" do
    test "returns all 5 categories with weights and descriptions" do
      cats = Scoring.categories()
      assert Map.has_key?(cats, :security)
      assert Map.has_key?(cats, :design)
      assert Map.has_key?(cats, :style)
      assert Map.has_key?(cats, :practices)
      assert Map.has_key?(cats, :documentation)
    end

    test "weights sum to 1.0" do
      total =
        Scoring.categories()
        |> Map.values()
        |> Enum.reduce(0.0, fn %{weight: w}, acc -> acc + w end)

      assert_in_delta total, 1.0, 0.001
    end
  end

  describe "compute/1" do
    test "computes weighted composite for all 100s" do
      result =
        Scoring.compute(%{
          security: 100,
          design: 100,
          style: 100,
          practices: 100,
          documentation: 100
        })

      assert result.composite == 100
      assert result.verdict == :approve
    end

    test "computes weighted composite for all 80s" do
      result =
        Scoring.compute(%{security: 80, design: 80, style: 80, practices: 80, documentation: 80})

      assert result.composite == 80
      assert result.verdict == :approve_with_comments
    end

    test "computes weighted composite for all 0s" do
      result =
        Scoring.compute(%{security: 0, design: 0, style: 0, practices: 0, documentation: 0})

      assert result.composite == 0
      assert result.verdict == :reject
    end

    test "missing categories default to 0" do
      result = Scoring.compute(%{})
      assert result.composite == 0
    end

    test "carries through findings and summary" do
      result =
        Scoring.compute(%{
          security: 90,
          design: 90,
          style: 90,
          practices: 90,
          documentation: 90,
          findings: ["a finding"],
          summary: "looks great"
        })

      assert result.findings == ["a finding"]
      assert result.summary == "looks great"
    end

    test "all struct fields are populated" do
      result =
        Scoring.compute(%{security: 70, design: 70, style: 70, practices: 70, documentation: 70})

      assert result.security == 70
      assert result.design == 70
      assert result.style == 70
      assert result.practices == 70
      assert result.documentation == 70
    end
  end

  describe "verdict (via compute)" do
    test "approve for composite >= 90" do
      result =
        Scoring.compute(%{security: 95, design: 95, style: 95, practices: 95, documentation: 95})

      assert result.verdict == :approve
    end

    test "approve_with_comments for composite >= 70 and < 90" do
      result =
        Scoring.compute(%{security: 75, design: 75, style: 75, practices: 75, documentation: 75})

      assert result.verdict == :approve_with_comments
    end

    test "request_changes for composite >= 50 and < 70" do
      result =
        Scoring.compute(%{security: 55, design: 55, style: 55, practices: 55, documentation: 55})

      assert result.verdict == :request_changes
    end

    test "reject for composite < 50" do
      result =
        Scoring.compute(%{security: 10, design: 10, style: 10, practices: 10, documentation: 10})

      assert result.verdict == :reject
    end
  end

  describe "parse_review_output/1" do
    test "parses valid JSON with nested score objects" do
      json =
        Jason.encode!(%{
          "security" => %{"score" => 85, "findings" => []},
          "design" => %{"score" => 90},
          "style" => %{"score" => 75},
          "practices" => %{"score" => 80},
          "documentation" => %{"score" => 70},
          "summary" => "looks good"
        })

      assert {:ok, result} = Scoring.parse_review_output(json)
      assert result.security == 85
      assert result.design == 90
      assert result.summary == "looks good"
    end

    test "parses JSON with flat numeric scores" do
      json =
        Jason.encode!(%{
          "security" => 70,
          "design" => 80,
          "style" => 60,
          "practices" => 75,
          "documentation" => 65
        })

      assert {:ok, result} = Scoring.parse_review_output(json)
      assert result.security == 70
      assert result.design == 80
    end

    test "extracts JSON block from surrounding text" do
      text =
        ~s(Some text before {"security": {"score": 80}, "design": {"score": 80}, "style": {"score": 80}, "practices": {"score": 80}, "documentation": {"score": 80}} more text)

      assert {:ok, result} = Scoring.parse_review_output(text)
      assert result.security == 80
    end

    test "clamps scores above 100" do
      json =
        Jason.encode!(%{
          "security" => 150,
          "design" => 90,
          "style" => 90,
          "practices" => 90,
          "documentation" => 90
        })

      assert {:ok, result} = Scoring.parse_review_output(json)
      assert result.security == 100
    end

    test "clamps scores below 0" do
      json =
        Jason.encode!(%{
          "security" => -10,
          "design" => 90,
          "style" => 90,
          "practices" => 90,
          "documentation" => 90
        })

      assert {:ok, result} = Scoring.parse_review_output(json)
      assert result.security == 0
    end

    test "returns error for non-JSON non-extractable text" do
      assert {:error, :no_scores_found} = Scoring.parse_review_output("plain text with no json")
    end

    test "returns error for nil input" do
      assert {:error, :invalid_input} = Scoring.parse_review_output(nil)
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_input} = Scoring.parse_review_output(123)
    end

    test "returns error for non-object JSON (array)" do
      assert {:error, :invalid_format} = Scoring.parse_review_output("[1, 2, 3]")
    end

    test "includes findings from categories, tagged with category name" do
      json =
        Jason.encode!(%{
          "security" => %{"score" => 80, "findings" => [%{"text" => "vuln found"}]},
          "design" => %{"score" => 80},
          "style" => %{"score" => 80},
          "practices" => %{"score" => 80},
          "documentation" => %{"score" => 80}
        })

      assert {:ok, result} = Scoring.parse_review_output(json)
      assert length(result.findings) == 1
      assert hd(result.findings)["category"] == "security"
      assert hd(result.findings)["text"] == "vuln found"
    end
  end

  describe "to_map/1" do
    test "serializes scoring struct to expected map shape" do
      result =
        Scoring.compute(%{security: 80, design: 80, style: 80, practices: 80, documentation: 80})

      map = Scoring.to_map(result)
      assert map.composite_score == 80
      assert map.verdict == :approve_with_comments
      assert map.categories.security.score == 80
      assert map.categories.security.weight == 0.25
      assert map.categories.design.weight == 0.25
      assert map.categories.style.weight == 0.15
      assert map.categories.practices.weight == 0.20
      assert map.categories.documentation.weight == 0.15
      assert is_list(map.findings)
      assert is_binary(map.summary)
    end
  end
end
