namespace :legacy do
  desc "Импорт старых пользователей из JSON. LEGACY_USERS=/path/users.json"
  task import_users: :environment do
    path = ENV.fetch("LEGACY_USERS")
    data = JSON.parse(File.read(path))

    rows = data.is_a?(Hash) ? data.map { |nickname, codeword| { "nickname" => nickname, "codeword" => codeword } } : data
    rows.each do |row|
      nickname = row.fetch("nickname").to_s.strip
      codeword = row.fetch("codeword").to_s
      next if User.exists?(nickname_key: User.nickname_key_for(nickname))

      User.create!(
        nickname: nickname,
        password: codeword,
        password_confirmation: codeword,
        role: :user,
        legacy_account: true,
        must_change_password: true,
        email_address: nil
      )
      puts "Imported user: #{nickname}"
    end
  end

  desc "Импорт ачивок из JSON-массива. LEGACY_ACHIEVEMENTS=/path/achievements.json"
  task import_achievements: :environment do
    path = ENV.fetch("LEGACY_ACHIEVEMENTS")
    JSON.parse(File.read(path)).each do |row|
      achievement = Achievement.find_or_initialize_by(name: row.fetch("name"))
      achievement.assign_attributes(
        description: row["description"],
        secret: row.fetch("secret", false),
        revealed: row.fetch("revealed", false),
        active: row.fetch("active", true)
      )
      achievement.save!
      puts "Imported achievement: #{achievement.name}"
    end
  end
end

namespace :legacy do
  desc "Импорт уже полученных ачивок без повторного начисления ЗБ. LEGACY_USER_ACHIEVEMENTS=/path/user_achievements.json"
  task import_user_achievements: :environment do
    path = ENV.fetch("LEGACY_USER_ACHIEVEMENTS")
    data = JSON.parse(File.read(path))
    rows = data.is_a?(Hash) ? data.map { |nickname, names| { "nickname" => nickname, "achievements" => Array(names) } } : data

    rows.each do |row|
      user = User.find_by!(nickname_key: User.nickname_key_for(row.fetch("nickname")))
      Array(row.fetch("achievements")).each do |name|
        achievement = Achievement.find_by!(name: name)
        UserAchievement.find_or_create_by!(user: user, achievement: achievement) do |award|
          award.awarded_at = Time.current
        end
        achievement.update!(revealed: true) if achievement.secret?
        puts "Imported award: #{user.nickname} — #{achievement.name}"
      end
    end
  end
end
