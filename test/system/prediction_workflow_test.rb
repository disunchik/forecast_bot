require "application_system_test_case"
require_relative "../support/domain_test_helper"

class PredictionWorkflowTest < ApplicationSystemTestCase
  include DomainTestHelper
  setup { setup_domain }

  def login(user)
    visit new_session_path
    fill_in "Никнейм", with: user.nickname
    fill_in "Пароль", with: "password"
    click_button "Войти"
    assert_current_path root_path
    assert_selector "nav", text: "Главная"
    wait_for_page_render
  end

  def wait_for_page_render
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      const settled = () => document.fonts.ready.then(() => {
        requestAnimationFrame(() => requestAnimationFrame(() => done()))
      })
      if (document.readyState === "complete") settled()
      else window.addEventListener("load", settled, { once: true })
    JS
  end

  test "mobile user submits edits and views full saved forecast" do
    page.current_window.resize_to(390, 844)
    login(@user)
    click_link "Сделать прогноз"
    assert_current_path new_match_forecast_path(@match)
    wait_for_page_render
    fill_in "forecast_halftime_roma", with: 0
    fill_in "forecast_halftime_opponent", with: 0
    fill_in "forecast_fulltime_roma", with: 0
    fill_in "forecast_fulltime_opponent", with: 0
    choose "Голов не будет"
    click_button "Отправить прогноз"
    assert_text "Прогноз сохранён"
    assert_no_link "Сделать прогноз"
    click_link "Изменить прогноз"
    wait_for_page_render
    fill_in "forecast_fulltime_roma", with: 1
    choose "Рома", exact: true
    click_button "Сохранить изменения"
    assert_text "Прогноз обновлён"
    click_link "Профиль", exact: true
    click_link "Посмотреть прогноз"
    assert_text "Итог"
    assert_text "1:0"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  end

  test "admin enters goal events previews confirms and participant views result" do
    @match.update!(kickoff_at: 1.day.ago)
    make_forecast(fulltime_roma: 1, first_score: :roma)
    player = Player.create!(name: "Дибала")
    login(@admin)
    visit edit_admin_match_result_path(@match)
    fill_in "match_result_fulltime_roma", with: 1
    choose "Рома", exact: true
    click_button "+ Добавить гол Ромы"
    within ".goal-row" do
      select player.name, from: "goals[0][scorer_value]"
      select "Без голевой передачи", from: "goals[0][assist_value]"
    end
    click_button "Сохранить черновик"
    assert_text "Черновик результата сохранён"
    click_button "Предварительно рассчитать"
    assert_text "Пока ничего не начислено"
    accept_confirm { click_button "Подтвердить результат" }
    assert_text "Результат подтверждён"
    visit profile_path
    click_button "Выйти"
    assert_current_path new_session_path
    login(@user)
    click_link "Профиль", exact: true
    assert_current_path profile_path
    click_link "Посмотреть прогноз"
    assert_current_path match_forecast_path(@match, @user.forecasts.find_by!(match: @match))
    assert_text "Расчёт"
    assert_text "Место: 1"
    assert_text "ЗБ применено"
  end

  test "forecast and profile links survive repeated mobile and desktop navigation" do
    login(@user)
    [ [ 390, 844 ], [ 1280, 900 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      3.times do
        click_link "Сделать прогноз"
        assert_current_path new_match_forecast_path(@match)
        assert_selector "form.forecast-form"
        click_link "Отмена"
        assert_current_path root_path
        click_link "Профиль", exact: true
        assert_current_path profile_path
        assert_text "У вас пока нет прогнозов"
        click_link "Главная", exact: true
        assert_current_path root_path
      end
    end
  end

  test "admin finishes a season on mobile and participants retain access to their rewards" do
    achievement = Achievement.create!(name: "Оптимист", rule_key: "optimist", description: "Не прогнозировал поражение Ромы, минимум 5 матчей")
    5.times do |index|
      match = index.zero? ? @match : make_match
      match.update!(kickoff_at: 1.day.ago)
      [ @user, @other_user ].each { |user| make_forecast(match: match, user: user) }
      MatchConfirmationService.new(match_result: draft_result(match: match), admin: @admin).confirm!
    end
    login(@admin)
    [ [ 1280, 900 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      assert_equal width, page.evaluate_script("window.innerWidth")
      visit edit_admin_achievement_path(achievement)
      assert_selector "select#achievement_rule_key option:checked", text: "Оптимист · сезон без прогноза на поражение, минимум 5 матчей"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      if ENV["UI_ARTIFACT_DIR"]
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-form-#{width}.png"))
      end
      visit admin_season_path(@season)
      click_link "Завершить сезон", exact: true
      assert_current_path completion_admin_season_path(@season)
      assert_text "минимум 5 прогнозов"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      if ENV["UI_ARTIFACT_DIR"]
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "season-completion-#{width}.png"))
      end
    end
    check "confirmation"
    if ENV["UI_ARTIFACT_DIR"]
      page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "season-confirmation-390.png"))
    end
    click_button "Подтвердить завершение сезона"
    assert_current_path admin_season_path(@season)
    assert_text "Сезон завершён. Выдано сезонных ачивок: 2."
    assert_no_link "Завершить сезон", exact: true
    assert @season.reload.completed?
    assert_equal [ 3, 3 ], GoldPointTransaction.where(achievement: achievement).order(:amount).pluck(:amount)
    visit profile_path
    click_button "Выйти"
    login(@user)
    assert_text "завершён"
    visit achievements_profile_path
    assert_text "Оптимист"
    assert_text "Получена"
    visit standings_path
    assert_selector "h1", text: "Текущая таблица"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "wolf achievement lists distinguish earned states and keep secret illustrations private" do
    Competition.find_or_create_by!(name: "Лига чемпионов")
    AchievementCatalog.install!
    @match.update!(kickoff_at: 4.days.from_now)
    romanist = Achievement.find_by!(name: "Романист")
    GoldPointsService.award_achievement!(user: @user, achievement: romanist, admin: @admin)
    secret = Achievement.create!(name: "Тайна волка", secret: true, rule_key: "three_promotions", description: "PRIVATE SECRET CONDITION")
    GoldPointsService.award_achievement!(user: @user, achievement: secret, admin: @admin)
    login(@user)
    [ [ 1280, 900 ], [ 768, 1024 ], [ 320, 844 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      visit achievements_profile_path
      assert_current_path achievements_profile_path
      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_selector ".achievement-list > li", count: 13
      assert_selector ".achievement--earned", count: 2
      assert_equal [ "achievement_#{secret.id}", "achievement_#{romanist.id}" ], all(".achievement-list > li").first(2).map { |row| row[:id] }
      assert_no_selector "table"
      within "#achievement_#{romanist.id}" do
        assert_text "Получена"
        assert_selector "img[src*='romanist']"
      end
      within "#achievement_#{secret.id}" do
        assert_selector "img[src*='mystery']"
        assert_no_text "PRIVATE SECRET CONDITION"
      end
      image_status = page.evaluate_async_script(<<~JS)
        const done = arguments[0];
        Promise.all(Array.from(document.querySelectorAll('.achievement-artwork img'), image =>
          fetch(image.src).then(response => response.ok))).then(done)
      JS
      assert image_status.all?, "Every miniature must load from the local asset pipeline"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      assert page.evaluate_script("Array.from(document.querySelectorAll('.achievement')).every(row => { const box = row.getBoundingClientRect(); return box.left >= 0 && box.right <= window.innerWidth; })")
      if ENV["UI_ARTIFACT_DIR"]
        page.execute_script("document.querySelectorAll('.achievement-artwork img').forEach(image => image.loading = 'eager')")
        page.evaluate_async_script("const done=arguments[0]; Promise.all(Array.from(document.querySelectorAll('.achievement-artwork img'), image => image.decode())).then(done)")
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-list-#{width}.png"))
        page.execute_script("document.getElementById(arguments[0]).scrollIntoView({block:'center', behavior:'instant'})", "achievement_#{romanist.id}")
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-earned-#{width}.png"))
      end
    end
    visit profile_path
    click_button "Выйти"
    login(@admin)
    visit admin_achievements_path
    assert_selector ".achievement-list > li", count: 13
    assert_no_selector "table"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    if ENV["UI_ARTIFACT_DIR"]
      page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-admin-390.png"))
    end
    within "#achievement_#{romanist.id}" do
      assert_text "Получили: 1"
      click_link "Изменить"
    end
    assert_current_path edit_admin_achievement_path(romanist)
    tester = Achievement.find_by!(name: "Тестировщик")
    debut = Achievement.find_by!(name: "Дебютант")
    [ [ 1280, 900 ], [ 768, 1024 ], [ 320, 844 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      visit admin_user_path(@other_user)
      assert_selector "section[aria-labelledby='automatic-achievements-heading'] .achievement", count: 12
      assert_selector "section[aria-labelledby='manual-achievements-heading'] .achievement", count: 1
      within "#achievement_#{debut.id}" do
        assert_text debut.description
        assert_selector "button[aria-label]", text: "Выдать"
      end
      within "#achievement_#{tester.id}" do
        assert_text tester.description
      end
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      assert page.evaluate_script("Array.from(document.querySelectorAll('.achievement-actions button')).every(button => {const box=button.getBoundingClientRect();return box.width>=44 && box.height>=44 && box.right<=innerWidth})")
      if ENV["UI_ARTIFACT_DIR"]
        page.execute_script("document.getElementById('automatic-achievements-heading').scrollIntoView({block:'start',behavior:'instant'})")
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-awards-#{width}.png"))
      end
    end
    [ debut, tester ].each do |achievement|
      within "#achievement_#{achievement.id}" do
        click_button "Выдать"
      end
      assert_current_path admin_user_path(@other_user)
      assert_text "Ачивка выдана."
      assert_no_selector "#achievement_#{achievement.id}"
      assert @other_user.user_achievements.exists?(achievement: achievement)
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "admin can inspect recipients revoke with confirmation and restore without new gold" do
    achievement = Achievement.create!(name: "Тестировщик", description: "За участие в тестовых прогнозах.")
    award = GoldPointsService.award_achievement!(user: @user, achievement: achievement, admin: @admin)
    login(@admin)
    [ [ 1280, 900 ], [ 768, 1024 ], [ 320, 844 ], [ 390, 844 ] ].each do |width, height|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      visit admin_achievements_path
      within "#achievement_#{achievement.id}" do
        assert_text "Получили: 1"
        click_link achievement.name
      end
      assert_current_path admin_achievement_path(achievement), ignore_query: true
      within "#user_achievement_#{award.id}" do
        assert_text @user.nickname
        assert_selector "a", text: "Отозвать"
      end
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      if ENV["UI_ARTIFACT_DIR"]
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-recipients-#{width}.png"))
      end
      within "#user_achievement_#{award.id}" do
        click_link "Отозвать"
      end
      assert_selector "nav[aria-label='Разделы админки'] a[aria-current='page']", text: "Ачивки"
      assert_text "Автоматические проверки не выдадут её снова"
      assert_no_selector "textarea[name=reason], input[name=reason]"
      assert_selector "input[type='checkbox'][required]"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      if ENV["UI_ARTIFACT_DIR"]
        page.execute_script("document.querySelector('.form-panel .actions').scrollIntoView({block:'end',behavior:'instant'})")
        page.save_screenshot(File.join(ENV.fetch("UI_ARTIFACT_DIR"), "achievement-revoke-#{width}.png"))
      end
    end
    check "Подтверждаю отзыв", allow_label_click: true
    click_button "Отозвать ачивку"
    assert_current_path admin_achievement_path(achievement)
    assert_text "Ачивка отозвана. ЗБ сохранены."
    assert_selector "#recipients-heading", text: "Получатели 0"
    find("summary", text: "Отозванные выдачи").click
    within "#user_achievement_#{award.id}" do
      click_link "Восстановить"
    end
    check "Подтверждаю восстановление", allow_label_click: true
    click_button "Восстановить ачивку"
    assert_current_path admin_achievement_path(achievement)
    assert_text "Ачивка восстановлена без повторного начисления ЗБ."
    assert_selector "#recipients-heading", text: "Получатели 1"
    assert_equal 3, @user.gold_points_balance(@season)
    assert_equal 1, GoldPointTransaction.where(achievement: achievement).count
    visit admin_user_path(@user)
    within "section[aria-labelledby='user-achievements-heading']" do
      assert_text "Тестировщик"
      assert_link "Отозвать"
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "PWA manifest and service worker register without offline predictions" do
    login(@user)
    assert_selector "link[rel=manifest]", visible: :all
    registration = page.evaluate_async_script("navigator.serviceWorker.ready.then(r => arguments[0](r.active.scriptURL))")
    assert_match "/service-worker", registration
  end

  test "away prediction shows opponent first and automatic goal follows the named team" do
    @match.update!(venue: :away)
    login(@user)
    click_link "Сделать прогноз"
    assert_current_path new_match_forecast_path(@match)
    wait_for_page_render
    fill_in "forecast_halftime_roma", with: 0
    fill_in "forecast_halftime_opponent", with: 0
    fill_in "forecast_fulltime_opponent", with: 0
    fill_in "forecast_fulltime_roma", with: 1
    assert_checked_field "forecast_first_score_roma"
    assert_field "forecast_first_score_opponent", disabled: true
    fill_in "forecast_fulltime_opponent", with: 1
    assert_unchecked_field "forecast_first_score_roma"
    choose "forecast_first_score_opponent"
    fill_in "forecast_fulltime_opponent", with: 0
    assert_checked_field "forecast_first_score_roma"
    click_button "Отправить прогноз"
    assert_text "Прогноз сохранён"
    click_link "Профиль", exact: true
    assert_current_path profile_path
    click_link "Посмотреть прогноз"
    assert_text "Inter — Рома"
    assert_text "0:1"
    assert_equal "roma", @user.forecasts.find_by!(match: @match).first_score
  end

  test "admin deletes a closed match only through the consequences form" do
    forecast = make_forecast
    @match.update!(kickoff_at: 1.day.ago)
    login(@admin)
    visit admin_match_path(@match)
    assert_no_link "Редактировать", exact: true
    assert_text "условия матча и вопрос заблокированы"
    click_link "Удаление матча: посмотреть последствия"
    assert_text "1 прогнозов"
    fill_in "Причина удаления", with: "Test deletion"
    fill_in "confirmation", with: @match.forecast_number
    accept_confirm { click_button "Удалить матч и его прогнозы" }
    assert_text "Матч удалён"
    assert_not Match.exists?(@match.id)
    assert_not Forecast.exists?(forecast.id)
  end
end
