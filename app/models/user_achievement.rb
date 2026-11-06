class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement
  belongs_to :awarded_by, class_name: "User", optional: true

  belongs_to :revoked_by, class_name: "User", optional: true

  scope :current, -> { where(revoked_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil) }

  def revoked?
    revoked_at.present?
  end

  validates :revoked_by, presence: true, if: :revoked?
  validates :awarded_at, presence: true
  validates :achievement_id, uniqueness: { scope: :user_id }
end
