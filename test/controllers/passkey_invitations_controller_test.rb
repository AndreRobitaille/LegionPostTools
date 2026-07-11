require "test_helper"

class PasskeyInvitationsControllerTest < ActionDispatch::IntegrationTest
  test "dismiss requires authentication" do
    Installation.singleton.update!(setup_completed_at: Time.current)

    delete passkey_invitation_path

    assert_redirected_to new_session_path
  end
end
