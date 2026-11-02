class MatchAdminPolicy
  class Error < StandardError; end
  class ResetRequired < Error; end

  def self.ensure_editable!(match)
    raise Error, "После дедлайна условия матча и вопрос заблокированы. Доступны фактический результат, откат или отдельное удаление матча." if match.conditions_locked?
  end

  def self.ensure_identity!(match, attrs)
    return unless match.identity_locked?

    changed = attrs.to_h.any? do |key, value|
      key.to_s.in?(%w[season_id forecast_number]) && value.to_s != match.public_send(key).to_s
    end
    if changed
      raise Error, "У матча уже есть история прогнозов или ЗБ. Сезон и номер менять нельзя, в том числе после отката. Для другого сезона создайте новый матч."
    end
  end

  def self.edit_token(match)
    AdminStateToken.issue(scope: "match_edit", id: match.id, state: MatchAuditSnapshot.match_state(match))
  end
end
