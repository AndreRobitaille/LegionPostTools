require "test_helper"

class ApiIdempotencyConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @organization = Organization.create!(
      name: "Concurrency Post #{SecureRandom.hex(5)}",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    @person = Person.create!(first_name: "Concurrent", last_name: SecureRandom.hex(6))
    @user = User.create!(person: @person, email_address: "api-concurrent-#{SecureRandom.hex(8)}@example.com")
    @user.permission_grants.create!(capability: "manage_settings")
    @token, @plaintext = AgentAccessToken.issue!(user: @user, name: "Concurrent test", expires_in: 30.days)
  end

  teardown do
    Endeavor.where(organization_id: @organization.id).delete_all
    @organization.destroy!
    @person.destroy!
  end

  test "concurrent first uses serialize and perform one mutation" do
    warm_client = ActionDispatch::Integration::Session.new(Rails.application)
    warm_client.get(
      "/api/endeavors",
      headers: { "Authorization" => "Bearer #{@plaintext}" },
      as: :json
    )
    assert_equal 200, warm_client.response.status

    ready = Queue.new
    start = Queue.new
    threads = 2.times.map do
      Thread.new do
        client = ActionDispatch::Integration::Session.new(Rails.application)
        ready << true
        start.pop
        client.post(
          "/api/endeavors",
          params: { title: "Concurrent Buddy Checks" },
          headers: {
            "Authorization" => "Bearer #{@plaintext}",
            "Idempotency-Key" => "concurrent-buddy-checks"
          },
          as: :json
        )
        [ client.response.status, client.response.body ]
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    results = threads.map(&:value)

    assert_equal [ 201, 201 ], results.map(&:first)
    assert_equal 1, results.map(&:last).uniq.size
    assert_equal 1, @organization.endeavors.where(title: "Concurrent Buddy Checks").count
    assert_equal 1, @token.agent_api_executions.where(idempotency_key: "concurrent-buddy-checks").count
  end
end
