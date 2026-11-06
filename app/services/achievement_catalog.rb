class AchievementCatalog
  EUROPEAN_COMPETITIONS = [ "Лига чемпионов", "Лига Европы", "Лига конференций" ].freeze
  DEFINITIONS = [
    { name: "Царь горы", rule_key: "top_leader", description: "Возглавить таблицу Топ-10 после разделения участников на Топ-10 и Претендентов." },
    { name: "Романист", rule_key: "derby_exact", description: "Угадать точный итоговый счёт в дерби Ромы с Лацио." },
    { name: "Дебютант", rule_key: "top_debut", description: "Впервые попасть в Топ-10 после разделения таблиц." },
    { name: "Из грязи в князи", rule_key: "challenger_leader", description: "Занять первое место в таблице Претендентов." },
    { name: "Чужой среди своих", rule_key: "top_exit", description: "Впервые вылететь из Топ-10 в таблицу Претендентов." },
    { name: "Оптимист", rule_key: "optimist", description: "За сезон сделать минимум 5 прогнозов на подтверждённые матчи и ни разу не прогнозировать поражение Ромы. Выдаётся при завершении сезона." },
    { name: "Легенда", rule_key: "season_champion", description: "Занять первое место в итоговой таблице Топ-10. Выдаётся при завершении сезона." },
    { name: "Главный по чашечкам", rule_key: "europe_exact", description: "Угадать точный итоговый счёт матча Ромы в еврокубках." },
    { name: "Тестировщик", rule_key: nil, description: "За участие в тестовых прогнозах. Выдаётся администратором вручную." },
    { name: "Охотник за головами", rule_key: "three_promotions", description: "Трижды за один сезон выйти из Претендентов в Топ-10, каждый раз вытеснив хотя бы одного участника прежнего Топ-10." },
    { name: "Тыж Прогнозист", rule_key: "five_wins", description: "Пять раз занять первое место в результатах подтверждённых матчей одного сезона." },
    { name: "Персофан", rule_key: "player_limit", description: "Упомянуть одного футболиста 13 раз в подтверждённых прогнозах в одном лимите. Авторы голов и ассистов, периоды матчей 0–19 и 20+ считаются отдельно." }
  ].map(&:freeze).freeze

  def self.install!(admin: nil, european_competition_ids: nil)
    Achievement.transaction do
      DEFINITIONS.filter_map do |definition|
        achievement = Achievement.find_or_initialize_by(name: definition.fetch(:name))
        next if achievement.persisted?

        achievement.assign_attributes(definition.merge(active: true, secret: false))
        if achievement.rule_key == "europe_exact"
          achievement.competition_ids = european_competition_ids || Competition.where(name: EUROPEAN_COMPETITIONS).order(:id).pluck(:id)
        end
        achievement.save!
        AuditLogger.record!(admin: admin, action: "achievement.create", auditable: achievement,
                            details: { source: "catalog", after: achievement.attributes })
        achievement
      end
    end
  end
end
