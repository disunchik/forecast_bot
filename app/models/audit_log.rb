class AuditLog < ApplicationRecord
  belongs_to :admin, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  serialize :details, coder: JSON, type: Hash

  validates :action, presence: true
end