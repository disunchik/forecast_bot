class MatchConfirmationService
  class Error < StandardError; end

  attr_reader :match_result

  def initialize(match_result:, admin:)
    @match_result = match_result
    @match = match_result.match
    @admin = admin
  end

  def preview
    validate_result!
    ranked_rows
  end

  def confirm!
    SeasonTransaction.call(@match.season) do
      match_result.reload
      @match.reload
      validate_result!
      raise Error, "Результат уже подтверждён" if match_result.confirmed?
      match_result.scoring_snapshot = ScoringRule.snapshot if match_result.scoring_snapshot.blank?
      rows = ranked_rows
      ensure_balances!
      persist_scores!(rows)
      spend_stakes!(rows)
      award_placement_gold!(rows)

      match_result.update!(state: :confirmed, confirmed_by: @admin, confirmed_at: Time.current)
      @match.update!(status: :finished)
      ensure_balances!
      balances = User.joins(:forecasts).where(forecasts: { match_id: @match.season.matches.select(:id) }).distinct.to_h do |user|
        [ user.id.to_s, user.gold_points_balance(@match.season) ]
      end
      match_result.update!(gold_balances_snapshot: balances)
      StandingsCalculator.new(match: @match).rebuild_snapshot!

      AuditLogger.record!(admin: @admin, action: "match_result.confirm", auditable: match_result,
                          details: { match_id: @match.id, forecast_number: @match.forecast_number, rules: match_result.scoring_snapshot })
    end
  end

  private
    def validate_result!
      raise Error, "Дождитесь закрытия приёма прогнозов" if Time.current < @match.forecast_closes_at
      raise Error, "Перенесённый матч нельзя рассчитывать" if @match.postponed?
      raise Error, "Отменённый матч нельзя рассчитывать" if @match.cancelled?
      raise ActiveRecord::RecordInvalid, match_result unless match_result.valid?
      if match_result.goals.size != match_result.fulltime_roma
        raise Error, "Количество голов Ромы не совпадает с итоговым счётом"
      end
      if @match.season.matches.where("forecast_number < ?", @match.forecast_number).where.not(status: [ :finished, :cancelled ]).exists?
        raise Error, "Сначала подтвердите или отмените более ранние матчи сезона"
      end
    end

    def ensure_balances!
      @match.forecasts.includes(:user).each do |forecast|
        user = forecast.user
        if user.gold_points_balance(@match.season) < user.reserved_gold_points(@match.season)
          raise Error, "У #{user.nickname} недостаточно ЗБ для ставок. Изменения отменены."
        end
      end
    end

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
          f.submitted_at.to_f,
          f.id
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
        1 => match_result.scoring_snapshot.fetch("placement_first", 3),
        2 => match_result.scoring_snapshot.fetch("placement_second", 2),
        3 => match_result.scoring_snapshot.fetch("placement_third", 1)
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
