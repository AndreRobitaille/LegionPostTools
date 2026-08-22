require "test_helper"

class MagicLinkConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @person = Person.create!(first_name: "Concurrent", last_name: SecureRandom.hex(6))
    @user = User.create!(person: @person, email_address: "concurrent-#{SecureRandom.hex(8)}@example.com")
    @challenge = MagicLink.create_for!(@user)
  end

  teardown do
    @person&.destroy!
  end

  test "two simultaneous consumers can use a code only once" do
    ready = Queue.new
    start = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          MagicLink.consume_code!(
            browser_challenge: @challenge.browser_challenge,
            code: @challenge.login_code
          )&.id
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    results = threads.map(&:value)

    assert_equal [ nil, @user.id ], results.sort_by { |value| value || 0 }
    assert @challenge.reload.used_at
  end
end
