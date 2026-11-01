class Season < ApplicationRecord
  has_many :matches, dependent: :restrict_with_error
  has_many :gold_point_transactions, dependent: :restrict_with_error
  has_many :standing_snapshots, dependent: :destroy

  scope :active, -> { where(active: true) }

  validates :name, presence: true, uniqueness: true
end
