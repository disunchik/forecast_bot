module ApplicationHelper
  def moscow_time(time)
    return "—" unless time

    time.in_time_zone("Moscow").strftime("%d.%m.%Y %H:%M")
  end

  def match_title(match)
    match.home? ? "Рома — #{match.opponent}" : "#{match.opponent} — Рома"
  end

  def match_score(match, roma, opponent)
    match.home? ? "#{roma}:#{opponent}" : "#{opponent}:#{roma}"
  end

  def score_teams(match)
    match.home? ? [ [ :roma, "Рома" ], [ :opponent, match.opponent ] ] : [ [ :opponent, match.opponent ], [ :roma, "Рома" ] ]
  end

  def first_score_label(value)
    { "roma" => "Рома", "opponent" => "Соперник", "nobody" => "Никто" }[value.to_s] || value.to_s
  end

  def match_status_label(match)
    {
      "scheduled" => "Запланирован",
      "postponed" => "Перенесён",
      "cancelled" => "Отменён",
      "finished" => "Завершён"
    }[match.status] || match.status
  end

  def result_state_label(result)
    return "Не введён" unless result

    result.confirmed? ? "Подтверждён" : "Черновик"
  end

  def user_role_label(user)
    user.admin? ? "Администратор" : "Пользователь"
  end

  def score_breakdown(score)
    return [] unless score

    [
      [ "Счёт матча", score.fulltime_points ],
      [ "Счёт первого тайма", score.halftime_points ],
      [ "Исход", score.outcome_points ],
      [ "Рома без голов", score.roma_no_goal_points ],
      [ "0:0", score.nil_nil_points ],
      [ "Первый гол", score.first_score_points ],
      [ "Авторы голов", score.scorer_points ],
      [ "Ассисты", score.assist_points ],
      [ "Временный вопрос", score.temporary_question_points ],
      [ "ЗБ применено", score.gold_points_applied ]
    ]
  end
end
