# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'
# require 'pry-rails'
# require 'pry-nav'
require 'pry-rails'
require File.expand_path('../dummy/config/environment.rb', __FILE__)

require 'spree_dev_tools/rspec/spec_helper'
# require 'spree/testing_support/capybara_ext'
require 'spree/testing_support/factories'
require 'capybara/rspec'
require 'capybara'
require 'pry'
require 'webdrivers'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].sort.each { |f| require f }
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Infer an example group's spec type from the file location.
  # config.infer_spec_type_from_file_location!

  # == URL Helpers
  #
  # Allows access to Spree's routes in specs:
  #
  # visit spree.admin_path
  # current_path.should eql(spree.products_path)
  # config.include Spree::TestingSupport::UrlHelpers
  # config.include Spree::TestingSupport::AuthorizationHelpers::Controller

  # # == Requests support
  # #
  # # Adds convenient methods to request Spree's controllers
  # # spree_get :index
  # config.include Spree::TestingSupport::ControllerRequests, type: :controller

  # # == Mock Framework
  # #
  # # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  # #
  # # config.mock_with :mocha
  # # config.mock_with :flexmock
  # # config.mock_with :rr
  # config.mock_with :rspec do |mocks|
  #   mocks.syntax = [:expect, :should]
  # end
  # config.color = true

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # Capybara javascript drivers require transactional fixtures set to false, and we use DatabaseCleaner
  # to cleanup after each test instead.  Without transactional fixtures set to false the records created
  # to setup a test will be unavailable to the browser, which runs under a separate server instance.
  config.use_transactional_fixtures = false

  # # Ensure Suite is set to use transactions for speed.
  # config.before :suite do
  #   DatabaseCleaner.strategy = :transaction
  #   DatabaseCleaner.clean_with :truncation
  # end

  # # Before each spec check if it is a Javascript test and switch between using database transactions or not where necessary.
  # config.before :each do
  #   DatabaseCleaner.strategy = RSpec.current_example.metadata[:js] ? :truncation : :transaction
  #   DatabaseCleaner.start
  # end

  # # After each spec clean the database.
  # config.after :each do
  #   DatabaseCleaner.clean
  # end

  # config.fail_fast = ENV['FAIL_FAST'] || false
  # config.order = 'random'
end

options = Selenium::WebDriver::Chrome::Options.new(binary: proc { ::Webdrivers::Chromedriver.update('/usr/bin/google-chrome') })

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome, options: options)
end

Capybara.current_driver = :chrome