module Admin
  class ScoringRulesController < BaseController
    def index
      @rules = ScoringRule.order(:id)
    end

    def update
      rule = ScoringRule.find(params[:id])
      ScoringRule.transaction do
        ScoringRule.where(id: rule.id).update_all("id = id")
        pending = Match.joins(:forecasts).left_joins(:match_result)
                       .where.not(status: :cancelled).where("kickoff_at <= ?", Time.current + 2.hours)
                       .where("match_results.id IS NULL OR match_results.state = ?", MatchResult.states[:draft])
                       .where("match_results.scoring_snapshot IS NULL OR match_results.scoring_snapshot = ?", "{}")
                       .distinct
        affects_matches = !rule.key.start_with?("achievement_") && rule.key != "player_mention_limit"
        if affects_matches && pending.exists?
          redirect_to admin_scoring_rules_path, alert: "Есть закрытые прогнозы без первого расчёта. Сначала подтвердите результаты или удалите эти матчи: менять их правила после дедлайна нельзя."
          return
        end
        rule.reload
        old_value = rule.value
        rule.update!(value: params.require(:scoring_rule).permit(:value)[:value])
        AuditLogger.record!(admin: current_user, action: "scoring_rule.update", auditable: rule, details: { before: old_value, after: rule.value })
      end
      redirect_to admin_scoring_rules_path, notice: "Правило обновлено."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_scoring_rules_path, alert: e.record.errors.full_messages.to_sentence
    end
  end
end
