require "test_helper"
require "stringio"

class SearchEngineIndexingTest < ActionDispatch::IntegrationTest
  test "signed-out sign-in page tells crawlers not to index" do
    Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    get new_session_path

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "meta[name='robots'][content='noindex, nofollow']", count: 1
  end

  test "signed-in page tells crawlers not to index" do
    Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    user = User.create!(
      person: Person.create!(first_name: "Signed", last_name: "Member"),
      email_address: "signed-in-indexing@example.test",
      email_verified_at: Time.current
    )
    user.permission_grants.create!(capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_select "meta[name='robots'][content='noindex, nofollow']", count: 1
    assert_select "h1", "Post meetings"
  end

  test "json and static asset responses send the noindex header" do
    Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    get "/api", as: :json

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    get "/icon.svg"

    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    get "/missing-member-page"

    assert_response :not_found
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "active storage file responses send the noindex header" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("synthetic attachment"),
      filename: "note.txt",
      content_type: "text/plain"
    )

    get rails_storage_proxy_path(blob, disposition: "attachment")

    assert_response :success
    assert_equal "synthetic attachment", response.body
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    get rails_storage_redirect_path(blob, disposition: "attachment")
    assert_response :redirect
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    follow_redirect!
    assert_response :success
    assert_equal "synthetic attachment", response.body
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  ensure
    blob&.purge
  end

  test "redirects static errors and rendered errors retain noindex" do
    Installation.singleton.update!(setup_completed_at: Time.current)
    get meetings_path
    assert_response :redirect
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    %w[/400.html /404.html /406-unsupported-browser.html /422.html /500.html].each do |path|
      get path
      assert_response :success
      assert_select "meta[name='robots'][content='noindex, nofollow']", count: 1
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
      assert_no_match(/token=|untrusted/, Nokogiri::HTML(response.body).at_css("head").to_s)
    end
    get "/missing-member-page?token=private-token"
    assert_response :not_found
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "robots.txt is served, allows crawling, and does not advertise a sitemap" do
    get "/robots.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]

    rules = response.body.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    assert_includes rules, "User-agent: *"
    assert_includes rules, "Allow: /"
    disallows = rules.grep(/\Adisallow:/i).map { |line| line.split(":", 2).last.strip }
    assert disallows.none? { |path| path == "/" }, "robots.txt must not disallow /"
    assert rules.none? { |line| line.match?(/\Asitemap:/i) }
    assert_no_match(/sitemap/i, response.body)
  end
end
