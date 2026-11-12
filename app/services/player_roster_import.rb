require "open3"

class PlayerRosterImport
  class Error < StandardError; end
  class StalePreview < Error; end

  def self.normalize(name)
    name.to_s.unicode_normalize(:nfkc).downcase.squish
  end

  def self.catalog_state(players: nil)
    state = players ? players.sort_by(&:id).map { |player| [ player.id, player.name, player.active, player.roma_profile_key, player.updated_at ] } : Player.order(:id).pluck(:id, :name, :active, :roma_profile_key, :updated_at)
    AdminStateToken.digest(state)
  end

  def self.preview(snapshot:, admin:)
    players = Player.order(:name).to_a
    dictionary = RomaRosterSource.catalog.fetch("players").index_by { |row| row.fetch("key") }
    rows = snapshot.fetch("players").map do |source|
      known = dictionary[source.fetch("key")]
      keyed = players.find { |player| player.roma_profile_key == source.fetch("key") }
      aliases = [ source.fetch("original_name"), known&.fetch("name"), *known&.fetch("aliases", []) ].compact.map { |name| normalize(name) }
      matches = keyed ? [ keyed ] : players.select { |player| aliases.include?(normalize(player.name)) }
      conflicting = matches.any? && matches.none? { |player| player.roma_profile_key.nil? || player.roma_profile_key == source.fetch("key") }
      matches = matches.select { |player| player.roma_profile_key.nil? || player.roma_profile_key == source.fetch("key") }
      status = if conflicting
        "conflict"
      elsif keyed || matches.one?
        matches.first.active? ? "existing" : "inactive"
      elsif matches.many?
        "ambiguous"
      else
        known ? "new" : "unknown"
      end
      source.merge("name" => known&.fetch("name").to_s, "status" => status,
                   "candidates" => matches.map { |player| { "id" => player.id, "name" => player.name, "active" => player.active? } })
    end
    payload = { "admin_id" => admin.id, "catalog_state" => catalog_state(players: players), "snapshot" => snapshot.except("players"), "rows" => rows }
    [ payload, verifier.generate(payload, expires_in: 30.minutes, purpose: "roma_roster") ]
  end

  def self.read(token:, admin:)
    payload = verifier.verified(token.to_s, purpose: "roma_roster")
    unless payload.is_a?(Hash) && payload["admin_id"] == admin.id
      raise Error, "Предпросмотр устарел или повреждён. Загрузите состав заново."
    end
    payload
  end

  def self.default_action(row)
    if row.fetch("status").in?(%w[existing inactive])
      "match:#{row.fetch('candidates').first.fetch('id')}"
    elsif row.fetch("status") == "new"
      "create"
    else
      "skip"
    end
  end

  def self.apply!(token:, choices:, admin:)
    payload = read(token: token, admin: admin)
    raise Error, "Некорректный выбор футболистов." unless choices.is_a?(Hash)

    unless admin.admin? && payload.fetch("catalog_state") == catalog_state
      raise StalePreview, "Состав изменился или права администратора отозваны. Получите новый предпросмотр."
    end
    backup!
    Player.transaction do
      # Lock SQLite before reading the roster; concurrent imports cannot mint duplicates.
      User.where(id: admin.id).update_all("id = id")
      raise Error, "Доступ только для администраторов." unless admin.reload.admin?
      unless payload.fetch("catalog_state") == catalog_state
        raise StalePreview, "Состав уже изменился. Получите новый предпросмотр перед сохранением."
      end
      counts = { created: 0, linked: 0, skipped: 0 }
      used_ids = []
      names = Player.pluck(:name).map { |name| normalize(name) }
      payload.fetch("rows").each do |row|
        choice = choices.fetch(row.fetch("key"), {})
        raise Error, "Некорректная строка состава." unless choice.is_a?(Hash)
        action = choice.fetch("action", "skip")
        if action == "skip"
          counts[:skipped] += 1
          next
        end
        if action == "create"
          unless row.fetch("status").in?(%w[new unknown])
            raise Error, "Этот футболист уже есть. Выберите сопоставление вместо создания."
          end
          name = choice["name"].to_s.squish
          raise Error, "Укажите русское имя для #{row.fetch('original_name')} или пропустите строку." if name.blank?
          raise Error, "Слишком длинное имя футболиста." if name.length > 160
          raise Error, "Имя «#{name}» уже есть в составе. Проверьте сопоставление." if names.include?(normalize(name))
          player = Player.create!(name: name, roma_profile_key: row.fetch("key"))
          names << normalize(name)
          used_ids << player.id
          counts[:created] += 1
          AuditLogger.record!(admin: admin, action: "player.create", auditable: player,
                              details: { source: "roma_roster", after: player.attributes })
        elsif action.to_s.match?(/\Amatch:\d+\z/)
          id = action.delete_prefix("match:").to_i
          unless row.fetch("candidates").any? { |candidate| candidate.fetch("id") == id } && !used_ids.include?(id)
            raise Error, "Проверьте сопоставление: один футболист не может соответствовать двум профилям."
          end
          player = Player.find(id)
          used_ids << id
          if player.roma_profile_key.nil?
            before = player.attributes.dup
            player.update!(roma_profile_key: row.fetch("key"))
            counts[:linked] += 1
            AuditLogger.record!(admin: admin, action: "player.roster_link", auditable: player,
                                details: { source: "roma_roster", before: before, after: player.attributes })
          end
        else
          raise Error, "Неизвестное действие в строке состава."
        end
      end
      AuditLogger.record!(admin: admin, action: "players.roster_import", details: payload.fetch("snapshot").merge(counts))
      counts
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    raise Error, "Состав не сохранён: #{e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : 'обнаружено повторное имя или профиль'}."
  end

  def self.backup!
    return if Rails.env.test?

    destination = File.expand_path(ENV["FORECAST_BACKUP_DIR"].presence || File.join(Dir.home, "forecast-backups"))
    if destination == Rails.root.to_s || destination.start_with?(Rails.root.to_s + File::SEPARATOR)
      raise Error, "Каталог резервных копий должен находиться вне проекта."
    end
    source = Rails.root.join(ActiveRecord::Base.connection_db_config.database).dirname.to_s
    _output, status = Open3.capture2e(RbConfig.ruby, Rails.root.join("bin/backup").to_s,
                                     "--source", source, "--environment", Rails.env, "--destination", destination)
    raise Error, "Не удалось создать резервную копию. Состав не изменён." unless status.success?
  rescue SystemCallError
    raise Error, "Не удалось создать резервную копию. Состав не изменён."
  end
  private_class_method :backup!

  def self.verifier
    Rails.application.message_verifier("player_roster_import")
  end
  private_class_method :verifier
end
