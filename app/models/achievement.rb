class Achievement < ApplicationRecord
  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements

  scope :active, -> { where(active: true) }

  validates :name, presence: true, uniqueness: true
end
