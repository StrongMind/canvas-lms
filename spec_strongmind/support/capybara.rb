## Use Chrome!
Capybara.register_driver :chrome do |app|

  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--test-type') # https://github.com/GoogleChrome/chrome-launcher/blob/master/docs/chrome-flags-for-tools.md
  options.add_argument('--ignore-certificate-errors')
  options.add_argument('--disable-popup-blocking')
  options.add_argument('--disable-extensions')
  options.add_argument('--enable-automation')
  options.add_argument('--window-size=1600,1000')
  if ENV['CI']
    options.add_argument('--no-sandbox') # To use Chrome in the container-based environment
    options.add_argument('--disable-dev-shm-usage')
  end

  # This enables access to the JS console logs in your feature specs.
  # You can see the logs during the test by calling (for example):
  #
  #   puts page.driver.browser.manage.logs.get(:browser).map(&:inspect).join("\n")
  #
  # This will print out each log entry in the JS log
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    logging_prefs: { 'browser' => 'ALL' }
  )

  driver = Capybara::Selenium::Driver.new app,
                                          browser: :chrome,
                                          options: options,
                                          desired_capabilities: capabilities
end

## Headless!
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  options.add_argument('--test-type')
  options.add_argument('--ignore-certificate-errors')
  options.add_argument('--disable-popup-blocking')
  options.add_argument('--disable-extensions')
  options.add_argument('--enable-automation')
  options.add_argument('--window-size=1600,1000')
  if ENV['CI']
    options.add_argument('--no-sandbox') # To use Chrome in the container-based environment
    options.add_argument('--disable-dev-shm-usage')
  end

  # This enables access to the JS console logs in your feature specs.
  # You can see the logs during the test by calling (for example):
  #
  #   puts page.driver.browser.manage.logs.get(:browser).map(&:inspect).join("\n")
  #
  # This will print out each log entry in the JS log
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    logging_prefs: { 'browser' => 'ALL' }
  )

  driver = Capybara::Selenium::Driver.new app,
                                          browser: :chrome,
                                          options: options,
                                          desired_capabilities: capabilities
end

## Easy Selector
Capybara.add_selector :record do
  xpath { |record| XPath.css('#' + ActionView::RecordIdentifier.dom_id(record)) }
  match { |record| record.is_a?(ActiveRecord::Base) }
end

# Webpack: port and url
WEB_TEST_PORT = '5005'.freeze
WEB_TEST_URL  = "http://localhost:#{WEB_TEST_PORT}".freeze

def capybara_wait_for_webpack_server
  10.times.each do |_|
    begin
      Net::HTTP.get(URI(WEB_TEST_URL))
      return
    rescue Errno::ECONNREFUSED
      sleep 5
    end
  end
end

# Server 'strongmind' will run webpack before the specs run, and wait for it to finish,
# then starts the rails server
Capybara.register_server :strongmind do |app, port, host|
  require 'rack/handler/thin'

  # run webpack server using childprocess gem
  process = ChildProcess.build('yarn', 'run', 'webpack')
  process.io.inherit! # uncomment for debugging
  process.environment['WEB_PORT'] = WEB_TEST_PORT
  process.environment['API_URL'] = "#{host}:#{port}"
  process.cwd = Rails.root #.join('web') # needs to be dir of the SPA, but not in this case
  process.leader = true
  process.detach = true

  begin
    Net::HTTP.get(URI(WEB_TEST_URL))
  rescue
    process.start
    at_exit { process.stop unless process.exited? }
    capybara_wait_for_webpack_server
  end

  Rack::Handler::Thin.run(app, :Port => port, :Host => host)
end

# Server 'thin' does not run webpack and I feel it's faster than puma.  CI
Capybara.register_server :thin do |app, port, host|
  require 'rack/handler/thin'
  Rack::Handler::Thin.run(app, :Port => port, :Host => host)
end

## Capy Configuration Defaults
Capybara.configure do |config|
  config.server                = :thin # :strongmind/:puma/:webrick
  config.javascript_driver     = ENV['HEADLESS'] ? :headless_chrome : :chrome
  config.default_max_wait_time = 15
end

# better looking screenshots (fixes relative paths when desired)
Capybara.asset_host = 'http://localhost:3000'
