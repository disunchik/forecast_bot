namespace :achievements do
  desc "Create missing season achievements without changing existing settings or granting rewards"
  task install: :environment do
    created = AchievementCatalog.install!
    puts "Ачивок создано: #{created.size}. Уже существующие определения, выданные награды и ЗБ не изменены."
  end
end
