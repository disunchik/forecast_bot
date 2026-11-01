class MatchGoal < ApplicationRecord
  belongs_to :match_result
  belongs_to :scorer, class_name: "Player", optional: true
  belongs_to :assist, class_name: "Player", optional: true

  validate :scorer_consistency
  validate :assist_consistency

  private
    def scorer_consistency
      errors.add(:base, "Для автогола нельзя выбирать автора Ромы") if own_goal? && scorer_id.present?
      errors.add(:base, "Выберите автора гола или автогол") if !own_goal? && scorer_id.blank?
    end

    def assist_consistency
      return if own_goal?

      if no_assist == assist_id.present?
        errors.add(:base, "Выберите ассистента или вариант «Без голевой передачи»")
      end
      errors.add(:base, "Игрок не может отдать голевую передачу самому себе") if scorer_id.present? && scorer_id == assist_id
    end
end
