ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    setup do
      Rails.cache.clear
    end

    teardown do
      Rails.cache.clear
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # Forge an authenticated session (auth is passwordless; there is no password login to POST).
  def sign_in_as(user)
    session_record = Session.create!(
      user: user, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current
    )
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session_record.id
    cookies[:session_id] = jar["session_id"]
    session_record
  end
end
