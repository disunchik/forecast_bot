class Competition < ApplicationRecord
  has_many :matches, dependent: :restrict_with_error

  scope :active, -> { where(active: true).order(:name) }

  validates :name, presence: true, uniqueness: true
end
