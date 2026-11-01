class StandingEntry < ApplicationRecord
  belongs_to :standing_snapshot
  belongs_to :user

  enum :group_name, { overall: 0, top_ten: 1, challenger: 2 }
end
