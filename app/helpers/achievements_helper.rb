module AchievementsHelper
  ARTWORK_BY_RULE = {
    "top_leader" => "king",
    "derby_exact" => "romanist",
    "top_debut" => "debut",
    "challenger_leader" => "rags-to-prince",
    "top_exit" => "outsider",
    "optimist" => "optimist",
    "season_champion" => "legend",
    "europe_exact" => "cup-master",
    "three_promotions" => "head-hunter",
    "five_wins" => "five-wins",
    "player_limit" => "superfan"
  }.freeze

  def achievement_artwork_path(achievement, reveal_secret: false)
    key = if achievement.secret? && !achievement.revealed? && !reveal_secret
      "mystery"
    elsif achievement.name.to_s.strip.downcase == "тестировщик"
      "tester"
    else
      ARTWORK_BY_RULE.fetch(achievement.rule_key, "general")
    end
    "achievements/#{key}.webp"
  end
end
