class ForecastScorer < ApplicationRecord
  belongs_to :forecast
  belongs_to :player
end
