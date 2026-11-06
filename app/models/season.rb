class Season < ApplicationRecord
  has_many :matches, dependent: :restrict_with_error
  has_many :gold_point_transactions, dependent: :restrict_with_error
  has_many :standing_snapshots, dependent: :destroy

  belongs_to :completed_by, class_name: "User", optional: true

  def completed?
    completed_at.present?
  end

  scope :active, -> { where(active: true) }

  validates :name, presence: true, uniqueness: true
end
