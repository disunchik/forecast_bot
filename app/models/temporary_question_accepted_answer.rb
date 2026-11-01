class TemporaryQuestionAcceptedAnswer < ApplicationRecord
  belongs_to :temporary_question

  before_validation :normalize_answer

  validates :answer_text, presence: true
  validates :normalized_answer, presence: true, uniqueness: { scope: :temporary_question_id }

  def self.normalize(value)
    value.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  private
    def normalize_answer
      self.normalized_answer = self.class.normalize(answer_text)
    end
end
