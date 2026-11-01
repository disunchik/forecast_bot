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
end
