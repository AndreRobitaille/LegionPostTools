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
    def create_meeting!(organization:, meeting_body:, starts_at:, meeting_type: nil, title: nil, location_name: nil, location_address: nil, **attributes)
      organization.meetings.create!(
        {
          meeting_body: meeting_body,
          meeting_type: meeting_type,
          starts_at: starts_at,
          title: title,
          location_name: location_name.presence || meeting_body.effective_location_name.presence || "Location not recorded",
          location_address: location_address.nil? ? meeting_body.effective_location_address : location_address
        }.merge(attributes)
      )
    end

    def create_dated_agenda_from_template!(organization:, meeting_body:, meeting_type:, starts_at:, title: nil, location_name: nil, location_address: nil)
      meeting = create_meeting!(
        organization: organization,
        meeting_body: meeting_body,
        meeting_type: meeting_type,
        starts_at: starts_at,
        title: title,
        location_name: location_name,
        location_address: location_address
      )
      DatedAgenda.create_from_template!(meeting: meeting)
    end

    def create_dated_agenda!(organization:, meeting_body:, meeting_type:, starts_at:, title:, status: "draft", location_name: nil, location_address: nil, **attributes)
      meeting = create_meeting!(
        organization: organization,
        meeting_body: meeting_body,
        meeting_type: meeting_type,
        starts_at: starts_at,
        title: title,
        location_name: location_name,
        location_address: location_address
      )
      DatedAgenda.create!(
        {
          organization: organization,
          meeting: meeting,
          meeting_body: meeting_body,
          meeting_type: meeting_type,
          starts_at: starts_at,
          title: title,
          status: status,
          location_name: meeting.location_name,
          location_address: meeting.location_address
        }.merge(attributes)
      )
    end
  end
end

class ActionDispatch::IntegrationTest
  # Forge an authenticated session (auth is passwordless; there is no password login to POST).
  def sign_in_as(user, authenticated_at: Time.current)
    session_record = Session.create!(
      user: user, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current,
      authenticated_at: authenticated_at
    )
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session_record.id
    cookies[:session_id] = jar["session_id"]
    session_record
  end

  def with_stubbed_class_method(klass, method_name, replacement)
    original = klass.method(method_name)
    klass.define_singleton_method(method_name, replacement)
    yield
  ensure
    klass.define_singleton_method(method_name, original)
  end
end
