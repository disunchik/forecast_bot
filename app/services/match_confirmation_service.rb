class MatchConfirmationService
  class Error < StandardError; end

  attr_reader :match_result

  def initialize(match_result:, admin:)
    @match_result = match_result
    @match = match_result.match
    @admin = admin
  end

  def preview
    ranked_rows.map do |row|
      row.merge(placement: row[:placement])
    end
  end

  def confirm!
    raise Error, "Результат уже подтверждён" if match_result.confirmed?
    raise Error, "Отменённый матч нельзя рассчитывать" if @match.cancelled?
    raise Error, "Количество голов Ромы не совпадает с итоговым счётом" if match_result.goals.size != match_result.fulltime_roma
    if @match.season.matches.where("forecast_number < ?", @match.forecast_number).where.not(status: [:finished, :cancelled]).exists?
      raise Error, "Сначала подтвердите или отмените более ранние матчи сезона"
    end

    ActiveRecord::Base.transaction do
      rows = ranked_rows
      rows.each do |row|
        forecast = row[:forecast]
        if forecast.gold_points_stake > forecast.user.gold_points_balance(@match.season)
          raise Error, "У #{forecast.user.nickname} недостаточно ЗБ для зарезервированной ставки. Исправьте баланс перед подтверждением."
        end
      end
      persist_scores!(rows)
      spend_stakes!(rows)
      award_placement_gold!(rows)

      match_result.update!(state: :confirmed, confirmed_by: @admin, confirmed_at: Time.current)
      @match.update!(status: :finished)
      StandingsCalculator.new(match: @match).rebuild_snapshot!

      AuditLogger.record!(
        admin: @admin,
        action: "match_result.confirm",
        auditable: match_result,
        details: { match_id: @match.id, forecast_number: @match.forecast_number }
      )
    end
  end

  private
    def ranked_rows
      rows = @match.forecasts.includes(:user, :scorers, :forecast_assists).map do |forecast|
        { forecast: forecast, values: ForecastCalculator.new(forecast: forecast, match_result: match_result).calculate }
      end

      rows.sort_by! do |row|
        f = row[:forecast]
        v = row[:values]
        [
          -v[:total_points],
          -(v[:fulltime_difference_points] + v[:fulltime_exact_points] + v[:roma_no_goal_points] + v[:nil_nil_points]),
          -(v[:halftime_difference_points] + v[:halftime_exact_points]),
          -v[:first_score_points],
          -v[:outcome_points],
          -v[:scorer_points],
          -v[:assist_points],
          -v[:temporary_question_points],
          f.updated_at.to_f
        ]
      end

      rows.each_with_index { |row, index| row[:placement] = index + 1 }
      rows
    end

    def persist_scores!(rows)
      match_result.forecast_scores.destroy_all
      rows.each do |row|
        ForecastScore.create!(
          row[:values].merge(
            forecast: row[:forecast],
            match_result: match_result,
            placement: row[:placement]
          )
        )
      end
    end

    def spend_stakes!(rows)
      GoldPointTransaction.where(match: @match, kind: :stake).destroy_all

      rows.each do |row|
        forecast = row[:forecast]
        next if forecast.gold_points_stake.zero?

        GoldPointTransaction.create!(
          user: forecast.user,
          season: @match.season,
          match: @match,
          kind: :stake,
          amount: -forecast.gold_points_stake,
          note: "Ставка ЗБ на матч №#{@match.forecast_number}"
        )
      end
    end

    def award_placement_gold!(rows)
      GoldPointTransaction.where(match: @match, kind: :placement).destroy_all

      rewards = {
        1 => ScoringRule.value_for("placement_first", 3),
        2 => ScoringRule.value_for("placement_second", 2),
        3 => ScoringRule.value_for("placement_third", 1)
      }

      rows.first(3).each do |row|
        next unless row[:values][:total_points].positive?

        amount = rewards[row[:placement]].to_i
        next if amount.zero?

        GoldPointTransaction.create!(
          user: row[:forecast].user,
          season: @match.season,
          match: @match,
          kind: :placement,
          amount: amount,
          note: "#{row[:placement]} место в матче №#{@match.forecast_number}"
        )
      end
    end
end
