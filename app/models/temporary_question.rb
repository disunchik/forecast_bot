class TemporaryQuestion < ApplicationRecord
  belongs_to :match
  has_many :options, class_name: "TemporaryQuestionOption", dependent: :destroy
  has_many :accepted_answers, class_name: "TemporaryQuestionAcceptedAnswer", dependent: :destroy

  enum :question_type, { choice: 0, text: 1 }

  validates :text, presence: true
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
