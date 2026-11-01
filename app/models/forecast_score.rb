class ForecastScore < ApplicationRecord
  belongs_to :forecast
  belongs_to :match_result

  delegate :user, :match, to: :forecast

  def halftime_points
    halftime_difference_points + halftime_exact_points
  end

  def fulltime_points
    fulltime_difference_points + fulltime_exact_points
  end
end
