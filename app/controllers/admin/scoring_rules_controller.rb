module Admin
  class ScoringRulesController < BaseController
    def index
      @rules = ScoringRule.order(:id)
    end

    def update
      rule = ScoringRule.find(params[:id])
      old_value = rule.value
      rule.update!(value: params.require(:scoring_rule).permit(:value)[:value])
      AuditLogger.record!(admin: current_user, action: "scoring_rule.update", auditable: rule, details: { before: old_value, after: rule.value })
      redirect_to admin_scoring_rules_path, notice: "Правило обновлено."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_scoring_rules_path, alert: e.record.errors.full_messages.to_sentence
    end
  end
end
