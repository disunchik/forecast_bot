class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement
  belongs_to :awarded_by, class_name: "User", optional: true

  validates :awarded_at, presence: true
  validates :achievement_id, uniqueness: { scope: :user_id }
end
