class MatchAuditSnapshot
  def self.question(question)
    return nil unless question

    question.attributes.merge(
      "options" => question.options.order(:id).map(&:attributes),
      "accepted_answers" => question.accepted_answers.order(:id).map(&:attributes)
    )
  end

  def self.result(result)
    return nil unless result

    result.attributes.merge(
      "goals" => result.goals.order(:position, :id).map(&:attributes),
      "question" => question(result.match.temporary_question)
    )
  end

  def self.forecasts(match)
    match.forecasts.order(:id).map do |forecast|
      forecast.attributes.merge(
        "scorers" => forecast.forecast_scorers.order(:id).map(&:attributes),
        "assists" => forecast.forecast_assists.order(:id).map(&:attributes)
      )
    end
  end

  def self.match_state(match)
    match.reload
    {
      "match" => match.attributes,
      "question" => question(match.temporary_question),
      "result" => result(match.match_result),
      "forecasts" => match.forecasts.order(:id).pluck(:id, :updated_at, :gold_points_stake),
      "gold" => GoldPointTransaction.where(match: match).order(:id).pluck(:id, :season_id, :user_id, :kind, :amount)
    }
  end

  def self.season_state(season)
    {
      "matches" => season.matches.order(:id).map { |match| match_state(match) },
      "gold" => season.gold_point_transactions.order(:id).pluck(:id, :user_id, :kind, :amount)
    }
  end
end
