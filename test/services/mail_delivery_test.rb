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

  test "loops backend posts email, template id, and data variables" do
    ENV["LOOPS_API_KEY"] = "test-key"
    ENV["LOOPS_MAGIC_LINK_TEMPLATE_ID"] = "tmpl_123"

    backend = MailDelivery::LoopsBackend.new
    captured = nil
    backend.define_singleton_method(:post) { |payload| captured = payload }

    backend.deliver_magic_link(user: @user, login_url: "https://x.test/l?token=abc")

    assert_equal "tmpl_123", captured[:transactionalId]
    assert_equal "jane@example.com", captured[:email]
    assert_equal "https://x.test/l?token=abc", captured[:dataVariables][:login_url]
    assert_equal "Jane Doe", captured[:dataVariables][:name]
  ensure
    ENV.delete("LOOPS_API_KEY")
    ENV.delete("LOOPS_MAGIC_LINK_TEMPLATE_ID")
  end
end
