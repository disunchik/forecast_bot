module DomainTestHelper
  def setup_domain
    @season = Season.create!(name: "Season #{SecureRandom.hex(6)}", active: true)
    Season.where.not(id: @season.id).update_all(active: false)
    @competition = Competition.create!(name: "Cup #{SecureRandom.hex(6)}")
    @user = users(:one)
    @other_user = users(:two)
    @admin = User.create!(nickname: "Admin#{SecureRandom.hex(4)}", email_address: "#{SecureRandom.hex(6)}@example.com", password: "password", password_confirmation: "password", role: :admin)
    @match = make_match
  end

  def make_match(number: nil, kickoff: 1.day.from_now, season: @season, **attributes)
    Match.create!({ season: season, competition: @competition,
      forecast_number: number || ((season.matches.maximum(:forecast_number) || 0) + 1),
      opponent: "Inter", venue: :home, kickoff_at: kickoff }.merge(attributes))
  end

  def make_forecast(user: @user, match: @match, **attributes)
    user.forecasts.create!({ match: match, halftime_roma: 0, halftime_opponent: 0,
      fulltime_roma: 0, fulltime_opponent: 0, first_score: :nobody,
      gold_points_stake: 0, submitted_at: Time.current }.merge(attributes))
  end

  def fund(user: @user, amount: 20, season: @season)
    GoldPointsService.manual!(user: user, season: season, amount: amount, note: "Test funding", admin: @admin)
  end

  def draft_result(match: @match, **attributes)
    match.create_match_result!({ halftime_roma: 0, halftime_opponent: 0, fulltime_roma: 0,
      fulltime_opponent: 0, first_score: :nobody }.merge(attributes))
  end

  def forecast_attributes(**attributes)
    { halftime_roma: 0, halftime_opponent: 0, fulltime_roma: 0,
      fulltime_opponent: 0, first_score: "nobody", gold_points_stake: 0 }.merge(attributes)
  end
end
