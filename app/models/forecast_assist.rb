class ForecastAssist < ApplicationRecord
  belongs_to :forecast
  belongs_to :player, optional: true

  validate :player_or_no_assist

  private
    def player_or_no_assist
      if no_assist == player_id.present?
        errors.add(:base, "Укажите игрока или вариант без голевой передачи")
      end
    end
end
