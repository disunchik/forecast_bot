class TemporaryQuestionOption < ApplicationRecord
  belongs_to :temporary_question
  has_many :forecasts, dependent: :nullify

  validates :text, presence: true
end
