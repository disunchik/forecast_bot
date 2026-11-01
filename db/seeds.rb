[ "Серия А", "Лига чемпионов", "Лига Европы", "Кубок Италии" ].each do |name|
  Competition.find_or_create_by!(name: name) { |competition| competition.active = true }
end

Season.find_or_create_by!(name: "2026/2027") do |season|
  season.active = !Season.active.exists?
end

rules = {
  "halftime_difference" => [ 2, "Первый тайм: угадана разница" ],
  "halftime_exact" => [ 2, "Первый тайм: точный счёт" ],
  "fulltime_difference" => [ 4, "Матч: угадана разница" ],
  "fulltime_exact" => [ 4, "Матч: точный счёт" ],
  "outcome" => [ 2, "Угадан исход матча" ],
  "roma_no_goal" => [ 1, "Угадано, что Рома не забьёт" ],
  "nil_nil" => [ 2, "Угадан счёт 0:0" ],
  "first_score" => [ 1, "Угадано, кто откроет счёт" ],
  "scorer_1_4" => [ 3, "Автор гола при 1–4 выбранных" ],
  "scorer_5_6" => [ 2, "Автор гола при 5–6 выбранных" ],
  "scorer_7_8" => [ 1, "Автор гола при 7–8 выбранных" ],
  "assist_1_4" => [ 2, "Ассист при 1–4 выбранных" ],
  "assist_5_plus" => [ 1, "Ассист при 5+ выбранных" ],
  "gold_percentage" => [ 50, "Максимум применённых ЗБ, % от обычных баллов" ],
  "placement_first" => [ 3, "ЗБ за 1 место" ],
  "placement_second" => [ 2, "ЗБ за 2 место" ],
  "placement_third" => [ 1, "ЗБ за 3 место" ],
  "achievement_secret_first" => [ 5, "ЗБ первому за секретную ачивку" ],
  "achievement_normal_first" => [ 3, "ЗБ первому за обычную ачивку" ],
  "achievement_subsequent" => [ 1, "ЗБ за уже открытую ачивку" ],
  "player_mention_limit" => [ 13, "Лимит упоминаний игрока в одном периоде" ]
}

rules.each do |key, (value, label)|
  ScoringRule.find_or_create_by!(key: key) do |rule|
    rule.assign_attributes(value: value, label: label)
  end
end

puts "Seeds: competitions=#{Competition.count}, seasons=#{Season.count}, rules=#{ScoringRule.count}"
