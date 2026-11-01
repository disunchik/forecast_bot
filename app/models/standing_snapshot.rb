class StandingSnapshot < ApplicationRecord
  belongs_to :season
  belongs_to :match
  has_many :entries, class_name: "StandingEntry", dependent: :destroy
end
