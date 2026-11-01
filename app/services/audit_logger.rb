class AuditLogger
  def self.record!(admin:, action:, auditable: nil, details: {})
    AuditLog.create!(admin: admin, action: action, auditable: auditable, details: details)
  end
end
