require "test_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium/webdriver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["SELENIUM_REMOTE_URL"]
    Capybara.register_driver :remote_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.binary = ENV["BROWSER_BINARY"] if ENV["BROWSER_BINARY"]
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      Capybara::Selenium::Driver.new(app, browser: :remote, url: ENV.fetch("SELENIUM_REMOTE_URL"), capabilities: options)
    end
    Capybara.server_host = "0.0.0.0"
    Capybara.server_port = 3101
    Capybara.app_host = ENV.fetch("CAPYBARA_APP_HOST")
    driven_by :remote_chrome
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]
  end
end
