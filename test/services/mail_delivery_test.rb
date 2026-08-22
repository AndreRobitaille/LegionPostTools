require "test_helper"

class MailDeliveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: @person, email_address: "jane@example.com", email_verified_at: Time.current)
  end

  test "delegates to the configured backend" do
    captured = []
    fake_backend = Object.new
    fake_backend.define_singleton_method(:deliver_magic_link) do |user:, login_url:, login_code:|
      captured << { kind: :magic_link, user: user, login_url: login_url, login_code: login_code }
    end

    original = MailDelivery.backend
    MailDelivery.backend = fake_backend
    begin
      MailDelivery.deliver_magic_link(user: @user, login_url: "https://x.test/l?token=abc", login_code: "1234 5678")
    ensure
      MailDelivery.backend = original
    end

    assert_equal [
      { kind: :magic_link, user: @user, login_url: "https://x.test/l?token=abc", login_code: "1234 5678" }
    ], captured
  end

  test "action mailer backend enqueues the magic-link email" do
    assert_emails 1 do
      MailDelivery::ActionMailerBackend.new.deliver_magic_link(
        user: @user, login_url: "https://x.test/l?token=abc", login_code: "1234 5678"
      )
    end
  end

  test "loops backend posts email, template id, and data variables" do
    ENV["LOOPS_API_KEY"] = "test-key"
    ENV["LOOPS_MAGIC_LINK_TEMPLATE_ID"] = "tmpl_123"

    backend = MailDelivery::LoopsBackend.new
    captured = nil
    backend.define_singleton_method(:post) { |payload| captured = payload }

    backend.deliver_magic_link(user: @user, login_url: "https://x.test/l?token=abc", login_code: "1234 5678")

    assert_equal "tmpl_123", captured[:transactionalId]
    assert_equal "jane@example.com", captured[:email]
    assert_equal "https://x.test/l?token=abc", captured[:dataVariables][:login_url]
    assert_equal "1234 5678", captured[:dataVariables][:login_code]
    assert_equal "Jane Doe", captured[:dataVariables][:name]
  ensure
    ENV.delete("LOOPS_API_KEY")
    ENV.delete("LOOPS_MAGIC_LINK_TEMPLATE_ID")
  end

  test "loops backend raises a diagnosable error when the provider rejects delivery" do
    response = Struct.new(:body, :code).new(
      JSON.generate(success: false, message: "Missing data variable"),
      "400"
    )

    error = assert_raises MailDelivery::DeliveryError do
      MailDelivery::LoopsBackend.new.send(:validate_response!, response)
    end

    assert_equal 400, error.status
    assert_equal "Missing data variable", error.message
  end
end
