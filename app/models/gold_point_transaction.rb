class GoldPointTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :season
  belongs_to :match, optional: true
  belongs_to :achievement, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  enum :kind, { manual: 0, achievement: 1, stake: 2, placement: 3, migration: 4 }

  validates :amount, numericality: { only_integer: true, other_than: 0 }
  validates :note, presence: true, if: :manual?
end
