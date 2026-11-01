module Admin
  class AuditLogsController < BaseController
    def index
      @logs = AuditLog.includes(:admin).order(created_at: :desc).limit(300)
    end
  end
end
