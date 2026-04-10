require "capybara/rspec"

# Use rack_test for non-JS tests (fast)
Capybara.default_driver = :rack_test

# Use Selenium with headless Chrome for JS tests
Capybara.javascript_driver = :selenium_headless

Capybara.register_driver :selenium_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }
