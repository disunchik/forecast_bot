class SeasonTransaction
  def self.call(season)
    raise ArgumentError, "Не указан сезон" unless season

    Season.transaction do
      # Acquire SQLite's write lock before reading balances, limits or state.
      # A SELECT ... FOR UPDATE alone does not lock rows in SQLite.
      Season.where(id: season.id).update_all("id = id")
      yield
    end
  end
end
