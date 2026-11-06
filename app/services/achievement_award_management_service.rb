class AchievementAwardManagementService
  class Error < StandardError; end

  def initialize(award:, admin:)
    @award = award
    @admin = admin
  end

  def token(action:)
    AdminStateToken.issue(scope: "achievement_award_#{action}", id: @award.id, state: @award.reload.attributes)
  end

  def revoke!(token:, confirmation:)
    change!(action: "revoke", token: token, confirmation: confirmation) do
      raise Error, "Ачивка уже отозвана" if @award.revoked?

      @award.update!(revoked_at: Time.current, revoked_by: @admin, revocation_reason: nil)
    end
  end

  def restore!(token:, confirmation:)
    change!(action: "restore", token: token, confirmation: confirmation) do
      raise Error, "Ачивка не отозвана" unless @award.revoked?

      @award.update!(revoked_at: nil, revoked_by: nil, revocation_reason: nil)
    end
  end

  private
    def change!(action:, token:, confirmation:)
      raise Error, "Доступ только для администраторов" unless @admin&.admin?
      raise Error, "Подтвердите действие" unless confirmation == "1"

      UserAchievement.transaction do
        # Take SQLite's write lock before checking state, including concurrent restores.
        UserAchievement.where(id: @award.id).update_all("id = id")
        @award.reload
        AdminStateToken.verify!(token, scope: "achievement_award_#{action}", id: @award.id, state: @award.attributes)
        before = @award.attributes.dup
        yield
        AuditLogger.record!(admin: @admin, action: "achievement.#{action}", auditable: @award.achievement,
                            details: { award_id: @award.id, user_id: @award.user_id,
                                       gold_points: "preserved", before: before, after: @award.attributes })
        @award
      end
    end
end
