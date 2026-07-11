require "test_helper"

class MailDeliveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: @person, email_address: "jane@example.com", email_verified_at: Time.current)
  end

  test "delegates to the configured backend" do
    captured = nil
    fake_backend = Object.new
    fake_backend.define_singleton_method(:deliver_magic_link) do |user:, login_url:|
      captured = { user: user, login_url: login_url }
    end

    original = MailDelivery.backend
    MailDelivery.backend = fake_backend
    begin
      MailDelivery.deliver_magic_link(user: @user, login_url: "https://x.test/l?token=abc")
    ensure
      MailDelivery.backend = original
    end

    assert_equal({ user: @user, login_url: "https://x.test/l?token=abc" }, captured)
  end

  test "action mailer backend enqueues the magic-link email" do
    assert_emails 1 do
      MailDelivery::ActionMailerBackend.new.deliver_magic_link(
        user: @user, login_url: "https://x.test/l?token=abc"
      )
    end
  end
end
