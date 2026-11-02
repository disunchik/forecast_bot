class AdminStateToken
  class Error < StandardError; end

  def self.issue(scope:, id:, state:)
    verifier.generate([ scope, id, digest(state) ], expires_in: 2.hours)
  end

  def self.verify!(token, scope:, id:, state:)
    expected = [ scope, id, digest(state) ]
    unless verifier.verified(token.to_s) == expected
      raise Error, "Данные изменились или форма устарела. Обновите страницу и проверьте последствия заново."
    end
  end

  def self.digest(state)
    Digest::SHA256.hexdigest(ActiveSupport::JSON.encode(state))
  end

  def self.verifier
    Rails.application.message_verifier("admin_state")
  end
end
