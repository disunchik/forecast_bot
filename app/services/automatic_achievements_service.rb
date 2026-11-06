class AutomaticAchievementsService
  def self.for_match!(match:, admin:)
    matches = match.season.matches.joins(:match_result).where(match_results: { state: :confirmed })
                   .where("forecast_number >= ?", match.forecast_number).order(:forecast_number)
    new(season: match.season, admin: admin).award!(event: :match, matches: matches)
  end

  def initialize(season:, admin:)
    @season = season
    @admin = admin
  end

  def award!(event:, matches: [])
    SeasonTransaction.call(@season) do
      round = @season.matches.joins(:match_result).where(match_results: { state: :confirmed }).maximum(:forecast_number) || 0
      contexts = if event == :season
        [ AchievementRules::Context.new(season: @season) ]
      else
        matches.map { |match| AchievementRules::Context.new(season: @season, match: match) }
      end
      Achievement.active.where.not(rule_key: nil).order(:id).flat_map do |achievement|
        _, trigger, rule = AchievementRules::RULES.fetch(achievement.rule_key)
        next [] unless trigger == event
        ids = contexts.flat_map { |context| rule.recipients(context, achievement) }.uniq
        GoldPointsService.award_achievements!(users: User.where(id: ids).to_a, achievement: achievement, admin: @admin,
                                             season: @season, round: round, source: "automatic_#{event}")
      end
    end
  end
end
