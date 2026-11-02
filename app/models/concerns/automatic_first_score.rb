module AutomaticFirstScore
  extend ActiveSupport::Concern

  included do
    before_validation :assign_automatic_first_score
  end

  def automatic_first_score
    scores = [ halftime_roma, halftime_opponent, fulltime_roma, fulltime_opponent ]
    return unless scores.all? { |score| score.is_a?(Integer) && score >= 0 }
    return if halftime_roma > fulltime_roma || halftime_opponent > fulltime_opponent
    return "nobody" if fulltime_roma.zero? && fulltime_opponent.zero?
    return "roma" if fulltime_opponent.zero? || (halftime_roma.positive? && halftime_opponent.zero?)
    return "opponent" if fulltime_roma.zero? || (halftime_opponent.positive? && halftime_roma.zero?)

    nil
  end

  private
    def assign_automatic_first_score
      self.first_score = automatic_first_score if automatic_first_score
    end
end
