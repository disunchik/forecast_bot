require "test_helper"
require "capybara/rails"
require "capybara/minitest"
require "selenium/webdriver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  Capybara.default_max_wait_time = 5

  setup { page.current_window.resize_to(1280, 900) }

  def click_navigation_link(label, destination, **options)
    link = find_link(label, **options)
    prepare_element_for_interaction(link)
    link.click(x: 0, y: 0)
    assert_current_path destination
  end

  def fill_score(locator, value)
    field = find_field(locator)
    prepare_element_for_interaction(field)
    browser = page.driver.browser
    modifier = browser.capabilities.platform_name.to_s.downcase.include?("mac") ? :command : :control
    browser.action.click(field.native).key_down(modifier).send_keys("a").key_up(modifier)
      .send_keys(:backspace).send_keys(value.to_s).perform
    assert_field locator, with: value.to_s
  end

  def prepare_element_for_interaction(element)
    page.scroll_to(element, align: :center)
    ready = page.evaluate_async_script(<<~JS, element, Capybara.default_max_wait_time * 1000 - 100)
      const element = arguments[0], timeout = arguments[1], done = arguments[arguments.length - 1]
      let previous, stable = 0, finished = false
      const finish = ready => {
        if (finished) return
        finished = true
        clearTimeout(timer)
        done(ready)
      }
      const timer = setTimeout(() => finish(false), timeout)
      const check = () => {
        if (finished) return
        if (!element.isConnected) return finish(false)
        const rect = element.getBoundingClientRect()
        const hit = document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2)
        const receivesPointer = hit === element || element.contains(hit)
        const position = [rect.x, rect.y, rect.width, rect.height].join(",")
        stable = position === previous && receivesPointer ? stable + 1 : 0
        previous = position
        if (stable >= 2) finish(true)
        else requestAnimationFrame(check)
      }
      requestAnimationFrame(check)
    JS
    assert ready, "Element did not become stable and unobstructed before interaction"
  end

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
