require "test_helper"
require_relative "../support/domain_test_helper"

class StandingsCalculatorTest < ActiveSupport::TestCase
  include DomainTestHelper
  setup { setup_domain }

  def record_match(number, scores)
    match = make_match(number: number, kickoff: 1.day.ago)
    result = draft_result(match: match)
    result.update!(state: :confirmed, confirmed_at: Time.current)
    match.update!(status: :finished)
    scores.each_with_index do |(user, points), index|
      forecast = make_forecast(user: user, match: match)
      ForecastScore.create!(forecast: forecast, match_result: result, total_points: points, placement: index + 1)
    end
    StandingsCalculator.new(match: match).rebuild_snapshot!
  end

  test "first ten confirmed matches remain overall for arbitrary numbers with gaps" do
    @match.destroy!
    numbers = [ 5, 7, 11, 13, 17, 19, 20, 25, 31, 40 ]
    numbers.each do |number|
      snapshot = record_match(number, [ [ @user, 1 ] ])
      assert snapshot.entries.overall.exists?, "number #{number}"
    end
    snapshot = record_match(45, [ [ @user, 1 ] ])
    assert snapshot.entries.top_ten.exists?
    assert_equal 10, snapshot.entries.find_by!(user: @user).points
  end

  test "cancelled matches do not count towards transition" do
    @match.destroy!
    make_match(number: 1, status: :cancelled)
    (2..11).each { |number| record_match(number, [ [ @user, 1 ] ]) }
    assert_equal 10, StandingSnapshot.last.entries.find_by!(user: @user).points
    assert StandingSnapshot.last.entries.overall.exists?
  end

  test "top ten uses last seven plus best three older results" do
    @match.destroy!
    [ 100, 80, 60, 40, 1, 2, 3, 4, 5, 6, 7 ].each_with_index do |points, i|
      record_match(i + 1, [ [ @user, points ] ])
    end
    entry = StandingSnapshot.last.entries.find_by!(user: @user)
    assert_equal 268, entry.points
    assert entry.top_ten?
  end

  test "winner and challenger leader enter only once while other top players can leave" do
    @match.destroy!
    participants = [ @user, @other_user, @admin ] + 9.times.map do |i|
      User.create!(nickname: "Competitor#{i}", email_address: "competitor#{i}@example.com", password: "password", password_confirmation: "password")
    end
    10.times { |i| record_match(i + 1, participants.map.with_index { |user, rank| [ user, 20 - rank ] }) }
    newcomer = participants.last
    previous_top = StandingSnapshot.last.entries.overall.order(:rank).limit(10).pluck(:user_id)
    snapshot = record_match(11, [ [ newcomer, 100 ] ] + participants.reject { |u| u == newcomer }.map { |u| [ u, 0 ] })
    assert_equal 10, snapshot.entries.top_ten.count
    assert snapshot.entries.top_ten.exists?(user: newcomer)
    assert_equal 1, snapshot.entries.where(user: newcomer).count
    assert_equal 2, snapshot.entries.challenger.count
    assert_equal 1, previous_top.count { |id| !snapshot.entries.top_ten.exists?(user_id: id) }
    assert_equal 181, snapshot.entries.find_by!(user: newcomer).points
  end

  test "standings rebuild uses saved balance tie breaks rather than later adjustments" do
    @match.destroy!
    snapshot = record_match(1, [ [ @user, 10 ], [ @other_user, 10 ] ])
    result = snapshot.match.match_result
    result.update!(gold_balances_snapshot: { @user.id.to_s => 0, @other_user.id.to_s => 5 })
    original = snapshot.entries.order(:rank).pluck(:user_id)
    fund(user: @other_user, amount: 100)
    rebuilt = StandingsCalculator.new(match: snapshot.match).rebuild_snapshot!
    assert_equal original, rebuilt.entries.order(:rank).pluck(:user_id)
  end
  test "different winner and challenger leader replace two existing top players" do
    @match.destroy!
    participants = [ @user, @other_user, @admin ] + 9.times.map do |i|
      User.create!(nickname: "Moving#{i}", email_address: "moving#{i}@example.com", password: "password", password_confirmation: "password")
    end
    10.times { |i| record_match(i + 1, participants.map.with_index { |user, rank| [ user, 20 - rank ] }) }
    previous_top = StandingSnapshot.last.entries.overall.order(:rank).limit(10).pluck(:user_id)
    winner, leader = participants.last, participants[-2]
    snapshot = record_match(11, [ [ winner, 25 ], [ leader, 24 ] ] + participants.first(10).map { |u| [ u, 0 ] })
    assert_equal 10, snapshot.entries.top_ten.count
    assert snapshot.entries.top_ten.exists?(user: winner)
    assert snapshot.entries.top_ten.exists?(user: leader)
    assert_equal 2, previous_top.count { |id| !snapshot.entries.top_ten.exists?(user_id: id) }
  end
  test "challenger promotion and ranking use saved gold before forecast time" do
    @match.destroy!
    participants = [ @user, @other_user, @admin ] + 10.times.map do |i|
      User.create!(nickname: "GoldTie#{i}", email_address: "goldtie#{i}@example.com", password: "password", password_confirmation: "password")
    end
    top = participants.first(10)
    low, high, empty = participants.last(3)
    10.times do |i|
      record_match(i + 1, top.map { |user| [ user, 20 ] } + [ [ low, 0 ], [ high, 0 ], [ empty, 0 ] ])
    end
    low.forecasts.update_all(submitted_at: 2.hours.ago)
    high.forecasts.update_all(submitted_at: 1.hour.ago)
    empty.forecasts.update_all(submitted_at: 3.hours.ago)
    fund(user: low, amount: 5)
    fund(user: high, amount: 10)
    snapshot = record_match(11, top.map { |user| [ user, 20 ] })
    snapshot.match.match_result.update!(gold_balances_snapshot: { low.id.to_s => 5, high.id.to_s => 10, empty.id.to_s => 0 })
    assert snapshot.entries.top_ten.exists?(user: high)
    assert snapshot.entries.challenger.exists?(user: low)
    assert_operator snapshot.entries.find_by!(user: low).rank, :<, snapshot.entries.find_by!(user: empty).rank
    ranking = snapshot.entries.order(:group_name, :rank).pluck(:user_id)
    fund(user: empty, amount: 100)
    rebuilt = StandingsCalculator.new(match: snapshot.match).rebuild_snapshot!
    assert_equal ranking, rebuilt.entries.order(:group_name, :rank).pluck(:user_id)
  end

  test "late postponed result rebuilds the first split at eleven confirmed matches" do
    @match.update!(forecast_number: 5, status: :postponed)
    ([ 1, 2, 3, 4 ] + (6..11).to_a).each { |number| record_match(number, [ [ @user, 1 ] ]) }
    latest = @season.matches.find_by!(forecast_number: 11)
    assert latest.standing_snapshot.entries.overall.exists?
    @match.update!(status: :scheduled, kickoff_at: 1.day.ago)
    make_forecast
    MatchConfirmationService.new(match_result: draft_result, admin: @admin).confirm!
    assert latest.reload.standing_snapshot.entries.top_ten.exists?
    assert_equal 27, latest.standing_snapshot.entries.find_by!(user: @user).points
    assert_equal 11, @season.standing_snapshots.count
  end
end
