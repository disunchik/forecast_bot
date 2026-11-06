module AchievementRules
  Context = Struct.new(:season, :match, keyword_init: true) do
    def matches
      @matches ||= season.matches.joins(:match_result).where(match_results: { state: :confirmed }).order(:forecast_number)
    end

    def forecasts
      Forecast.where(match_id: matches.select(:id))
    end

    def snapshots
      season.standing_snapshots.joins(:match).where(match_id: matches.select(:id)).order("matches.forecast_number").includes(:entries)
    end
  end

  class DerbyExact
    def self.recipients(context, achievement)
      return [] unless context.match.opponent.downcase.gsub(/[^\p{L}]/, "").in?(%w[лацио lazio sslazio])
      result = context.match.match_result
      context.match.forecasts.where(fulltime_roma: result.fulltime_roma, fulltime_opponent: result.fulltime_opponent).pluck(:user_id)
    end
  end

  class EuropeExact
    def self.recipients(context, achievement)
      return [] unless achievement.competition_ids.include?(context.match.competition_id)
      result = context.match.match_result
      context.match.forecasts.where(fulltime_roma: result.fulltime_roma, fulltime_opponent: result.fulltime_opponent).pluck(:user_id)
    end
  end

  class FiveWins
    def self.recipients(context, achievement)
      ForecastScore.where(forecast_id: context.forecasts.select(:id), placement: 1).joins(:forecast)
                   .group("forecasts.user_id").having("COUNT(*) >= 5").pluck("forecasts.user_id")
    end
  end

  class TableRule
    def self.recipients(context, achievement)
      entries = context.match.standing_snapshot&.entries
      return [] unless entries
      case achievement.rule_key
      when "top_leader" then entries.top_ten.where(rank: 1).pluck(:user_id)
      when "top_debut" then entries.top_ten.pluck(:user_id)
      when "challenger_leader" then entries.challenger.where(rank: 1).pluck(:user_id)
      when "top_exit"
        previous = context.season.standing_snapshots.joins(:match)
                          .where("matches.forecast_number < ?", context.match.forecast_number).order("matches.forecast_number DESC").first
        previous_ids = previous ? previous.entries.where(group_name: :top_ten).pluck(:user_id) : []
        entries.challenger.where(user_id: previous_ids).pluck(:user_id)
      end
    end
  end

  class ThreePromotions
    def self.recipients(context, achievement)
      counts = Hash.new(0)
      context.snapshots.each_cons(2) do |previous, current|
        previous_top = previous.entries.select(&:top_ten?).map(&:user_id)
        next if previous_top.empty?
        current_top = current.entries.select(&:top_ten?).map(&:user_id)
        next if (previous_top - current_top).empty?
        challengers = previous.entries.select(&:challenger?).map(&:user_id)
        (current_top & challengers).each { |id| counts[id] += 1 }
      end
      counts.select { |_, count| count >= 3 }.keys
    end
  end

  class DarkHorse
    def self.recipients(context, achievement)
      tenth = []
      winners = []
      context.snapshots.each do |snapshot|
        top = snapshot.entries.select(&:top_ten?)
        winners |= top.select { |entry| entry.rank <= 3 && tenth.include?(entry.user_id) }.map(&:user_id)
        tenth |= top.select { |entry| entry.rank == 10 }.map(&:user_id)
      end
      winners
    end
  end

  class PlayerLimit
    def self.recipients(context, achievement)
      # Scorers, assists and the two season periods consume independent quotas.
      [ ForecastScorer, ForecastAssist ].flat_map do |model|
        [ (0..19), (20..) ].flat_map do |period|
          ids = context.forecasts.joins(:match).where(matches: { forecast_number: period }).select(:id)
          model.where(forecast_id: ids).where.not(player_id: nil).joins(:forecast)
               .group("forecasts.user_id", :player_id).having("COUNT(DISTINCT forecast_id) >= ?", PlayerLimitsService::LIMIT)
               .pluck("forecasts.user_id")
        end
      end.uniq
    end
  end

  class Optimist
    def self.recipients(context, achievement)
      context.forecasts.group(:user_id).having("COUNT(*) >= 5")
             .having("SUM(CASE WHEN fulltime_roma < fulltime_opponent THEN 1 ELSE 0 END) = 0").pluck(:user_id)
    end
  end

  class SeasonChampion
    def self.recipients(context, achievement)
      context.snapshots.last&.entries&.top_ten&.where(rank: 1)&.pluck(:user_id) || []
    end
  end

  RULES = {
    "derby_exact" => [ "Романист · точный счёт с Лацио", :match, DerbyExact ],
    "europe_exact" => [ "Главный по чашечкам · точный счёт в выбранных турнирах", :match, EuropeExact ],
    "five_wins" => [ "Тыж Прогнозист · 5 побед в матчах сезона", :match, FiveWins ],
    "top_leader" => [ "Царь горы · лидер Топ-10", :match, TableRule ],
    "top_debut" => [ "Дебютант · первое попадание в Топ-10", :match, TableRule ],
    "challenger_leader" => [ "Из грязи в князи · лидер Претендентов", :match, TableRule ],
    "top_exit" => [ "Чужой среди своих · вылет из Топ-10", :match, TableRule ],
    "three_promotions" => [ "Охотник за головами · 3 перехода из Претендентов в Топ-10", :match, ThreePromotions ],
    "dark_horse" => [ "Тёмная лошадка · с 10-го места Топ-10 до топ-3", :match, DarkHorse ],
    "player_limit" => [ "Персофан · 13 упоминаний игрока в одном лимите", :match, PlayerLimit ],
    "optimist" => [ "Оптимист · сезон без прогноза на поражение, минимум 5 матчей", :season, Optimist ],
    "season_champion" => [ "Легенда · победитель Топ-10 по итогам сезона", :season, SeasonChampion ]
  }.freeze

  def self.keys = RULES.keys
  def self.label(key) = RULES[key]&.first
  def self.options = RULES.map { |key, values| [ values.first, key ] }
end
