require "net/http"
require "nokogiri"

class RomaRosterSource
  class Error < StandardError; end
  URL = "https://www.asroma.com/en/men/players-and-staff".freeze
  MAX_BYTES = 2 * 1024 * 1024

  def self.catalog
    JSON.parse(Rails.root.join("config/data/roma_roster.json").read)
  end

  def self.saved
    data = catalog
    { "source" => "saved", "source_url" => URL, "retrieved_at" => data.fetch("verified_at"),
      "players" => data.fetch("players").map { |row| row.slice("key", "original_name") } }
  end

  def self.live
    { "source" => "live", "source_url" => URL, "retrieved_at" => Time.current.iso8601,
      "players" => parse(Timeout.timeout(20) { fetch }) }
  rescue Timeout::Error, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError => e
    Rails.logger.warn("Roma roster source unavailable: #{e.class}")
    raise Error, "Сайт Ромы сейчас недоступен. Повторите загрузку или выберите сохранённый состав с указанной датой."
  end

  def self.parse(html)
    raise Error, "Источник вернул слишком большой ответ." if html.bytesize > MAX_BYTES

    cards = Nokogiri::HTML(html, nil, "UTF-8").css(".card").select { |card| card.at_css(".player-number")&.text&.strip.present? }
    rows = cards.map do |card|
      profile = card.at_css('a[href^="/en/teams/men/"]')
      name = card.css(".player-name .first-name, .player-name .last-name").map(&:text).join(" ").squish
      key = profile&.[]("href")&.delete_prefix("/en/teams/men/")
      unless key&.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) && name.present? && name.length <= 160
        raise Error, "Структура страницы состава изменилась. Данные не загружены."
      end
      { "key" => key, "original_name" => name }
    end
    unless rows.size.between?(11, 80) && rows.map { |row| row.fetch("key") }.uniq.size == rows.size
      raise Error, "Не удалось прочитать полный состав. Можно выбрать сохранённую копию с указанной датой."
    end
    rows
  end

  def self.fetch(uri = URI(URL), redirects: 0)
    unless uri.is_a?(URI::HTTPS) && uri.host.in?([ "asroma.com", "www.asroma.com" ]) && uri.port == 443 && redirects <= 2
      raise Error, "Источник перенаправил запрос на неподдерживаемый адрес."
    end
    result = nil
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8, write_timeout: 4, max_retries: 0) do |http|
      http.request(Net::HTTP::Get.new(uri.request_uri, "User-Agent" => "RomaForecast/1.0")) do |response|
        if response.is_a?(Net::HTTPRedirection)
          location = response["location"]
          raise Error, "Источник вернул некорректное перенаправление." if location.blank?
          result = fetch(URI.join(uri, location), redirects: redirects + 1)
        elsif response.is_a?(Net::HTTPSuccess)
          result = +""
          response.read_body do |chunk|
            result << chunk
            raise Error, "Источник вернул слишком большой ответ." if result.bytesize > MAX_BYTES
          end
          result.force_encoding(Encoding::UTF_8)
          raise Error, "Источник вернул повреждённый текст." unless result.valid_encoding?
        else
          raise Error, "Сайт Ромы не отдал состав. Попробуйте позже или выберите сохранённую копию."
        end
      end
    end
    result
  rescue URI::InvalidURIError
    raise Error, "Источник вернул некорректный адрес."
  end
  private_class_method :fetch
end
