require "test_helper"

class CleanupAgentApiExecutionsJobTest < ActiveJob::TestCase
  test "deletes executions older than thirty days and retains newer records" do
    user = User.create!(
      person: Person.create!(first_name: "Jane", last_name: "Doe"),
      email_address: "jane@example.com"
    )
    token, = AgentAccessToken.issue!(user: user, name: "Grok", expires_in: 90.days)
    old_execution = create_execution(token, user, "old", created_at: 31.days.ago)
    recent_execution = create_execution(token, user, "recent", created_at: 29.days.ago)

    CleanupAgentApiExecutionsJob.perform_now

    assert_not AgentApiExecution.exists?(old_execution.id)
    assert AgentApiExecution.exists?(recent_execution.id)
  end

  private

  def create_execution(token, user, key, created_at:)
    AgentApiExecution.create!(
      agent_access_token: token,
      user: user,
      idempotency_key: key,
      request_method: "POST",
      request_path: "/api/tracked_items",
      request_fingerprint: Digest::SHA256.hexdigest(key),
      state: "completed",
      response_status: 201,
      response_body: "{}",
      created_at: created_at,
      updated_at: created_at
    )
  end
end
