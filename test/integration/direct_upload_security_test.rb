require "test_helper"
require "digest"

class DirectUploadSecurityTest < ActionDispatch::IntegrationTest
  test "anonymous clients cannot create blobs even with their own valid CSRF token" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get new_session_path
    assert_response :success
    csrf_token = Nokogiri::HTML(response.body).at_css("meta[name='csrf-token']")["content"]

    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: {
        blob: { filename: "upload.txt", byte_size: 4, checksum: Digest::MD5.base64digest("test"), content_type: "text/plain" }
      }, headers: { "X-CSRF-Token" => csrf_token }, as: :json
      assert_response :not_found
      assert_empty response.body
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "signed-in users cannot issue upload capabilities with alternate content types" do
    user = User.create!(person: Person.create!(first_name: "Storage", last_name: "Member"), email_address: "storage@example.test")
    sign_in_as(user)

    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: {
        blob: { filename: "upload.html", byte_size: 4, checksum: Digest::MD5.base64digest("test"), content_type: "text/html", metadata: { identified: true } }
      }, as: :json
      assert_response :not_found
    end
  end
end
