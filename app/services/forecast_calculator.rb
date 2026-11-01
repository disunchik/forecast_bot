class ForecastCalculator
  def initialize(forecast:, match_result:, rules: nil)
    @forecast = forecast
    @result = match_result
    @rules = rules || (match_result.scoring_snapshot.presence if match_result.respond_to?(:scoring_snapshot)) || ScoringRule.snapshot
  end

  def calculate
    values = {
      halftime_difference_points: halftime_difference_points,
      halftime_exact_points: halftime_exact_points,
      fulltime_difference_points: fulltime_difference_points,
      fulltime_exact_points: fulltime_exact_points,
      outcome_points: outcome_points,
      roma_no_goal_points: roma_no_goal_points,
      nil_nil_points: nil_nil_points,
      first_score_points: first_score_points,
      scorer_points: scorer_points,
      assist_points: assist_points,
      temporary_question_points: temporary_question_points
    }

    base = values.values.sum
    gold = [ @forecast.gold_points_stake, (base * rule("gold_percentage", 50) / 100.0).floor ].min

    values.merge(base_points: base, gold_points_applied: gold, total_points: base + gold)
  end

  private
    def rule(key, fallback)
      @rules.fetch(key, fallback)
    end

    def halftime_difference_points
      predicted = @forecast.halftime_roma - @forecast.halftime_opponent
      actual = @result.halftime_roma - @result.halftime_opponent
      predicted == actual ? rule("halftime_difference", 2) : 0
    end

    def halftime_exact_points
      exact?(@forecast.halftime_roma, @forecast.halftime_opponent, @result.halftime_roma, @result.halftime_opponent) ? rule("halftime_exact", 2) : 0
    end

    def fulltime_difference_points
      predicted = @forecast.fulltime_roma - @forecast.fulltime_opponent
      actual = @result.fulltime_roma - @result.fulltime_opponent
      predicted == actual ? rule("fulltime_difference", 4) : 0
    end

    def fulltime_exact_points
      exact?(@forecast.fulltime_roma, @forecast.fulltime_opponent, @result.fulltime_roma, @result.fulltime_opponent) ? rule("fulltime_exact", 4) : 0
    end

    def outcome_points
      outcome(@forecast.fulltime_roma, @forecast.fulltime_opponent) == outcome(@result.fulltime_roma, @result.fulltime_opponent) ? rule("outcome", 2) : 0
    end

    def roma_no_goal_points
      @forecast.fulltime_roma.zero? && @result.fulltime_roma.zero? ? rule("roma_no_goal", 1) : 0
    end

    def nil_nil_points
      exact?(@forecast.fulltime_roma, @forecast.fulltime_opponent, 0, 0) && exact?(@result.fulltime_roma, @result.fulltime_opponent, 0, 0) ? rule("nil_nil", 2) : 0
    end

    def first_score_points
      @forecast.first_score == @result.first_score ? rule("first_score", 1) : 0
    end

    def scorer_points
      selected_ids = @forecast.scorers.pluck(:id)
      return 0 if selected_ids.empty?

      unit = case selected_ids.size
      when 1..4 then rule("scorer_1_4", 3)
      when 5..6 then rule("scorer_5_6", 2)
      when 7..8 then rule("scorer_7_8", 1)
      else 0
      end
      return 0 if unit.zero?

      actual_counts = @result.goals.where(own_goal: false).where.not(scorer_id: nil).group(:scorer_id).count
      hits = selected_ids.sum { |id| actual_counts[id].to_i }
      hits * unit
    end

    def assist_points
      selected_ids = @forecast.assist_player_ids
      selection_count = selected_ids.size + (@forecast.predicts_no_assist? ? 1 : 0)
      return 0 if selection_count.zero?

      unit = selection_count <= 4 ? rule("assist_1_4", 2) : rule("assist_5_plus", 1)
      actual_counts = @result.goals.where(own_goal: false).where.not(assist_id: nil).group(:assist_id).count
      hits = selected_ids.sum { |id| actual_counts[id].to_i }
      hits += @result.goals.where(own_goal: false, no_assist: true).count if @forecast.predicts_no_assist?
      hits * unit
    end

    def temporary_question_points
      question = @forecast.match.temporary_question
      return 0 unless question
      return 0 if question.voided?

      correct = if question.choice?
                  @forecast.temporary_question_option&.correct?
      else
                  normalized = TemporaryQuestionAcceptedAnswer.normalize(@forecast.temporary_answer_text)
                  question.accepted_answers.exists?(normalized_answer: normalized)
      end

      correct ? question.points : 0
    end

    def exact?(a, b, x, y)
      a == x && b == y
    end

    def outcome(roma, opponent)
      return :win if roma > opponent
      return :loss if roma < opponent

      :draw
    end
end
