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
  end

  test "mobile user submits edits and views full saved forecast" do
    page.current_window.resize_to(390, 844)
    login(@user)
    click_link "Сделать прогноз"
    fill_in "forecast_halftime_roma", with: 0
    fill_in "forecast_halftime_opponent", with: 0
    fill_in "forecast_fulltime_roma", with: 0
    fill_in "forecast_fulltime_opponent", with: 0
    choose "Голов не будет"
    click_button "Отправить прогноз"
    assert_text "Прогноз сохранён"
    assert_no_link "Сделать прогноз"
    click_link "Изменить прогноз"
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

  test "PWA manifest and service worker register without offline predictions" do
    login(@user)
    assert_selector "link[rel=manifest]", visible: :all
    registration = page.evaluate_async_script("navigator.serviceWorker.ready.then(r => arguments[0](r.active.scriptURL))")
    assert_match "/service-worker", registration
  end
end
