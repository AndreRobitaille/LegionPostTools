require "test_helper"

class MembersSiteSharingTest < ActionDispatch::IntegrationTest
  setup do
    @original_identity = Rails.application.config.x.members_site
    Rails.application.config.x.members_site = MembersSite.new(
      "MEMBERS_SITE_NAME" => "Example Post Members",
      "MEMBERS_SITE_DESCRIPTION" => "Meeting agendas, minutes, and member resources. Member sign-in required.",
      "MEMBERS_SITE_ORIGIN" => "https://members.example.test",
      "MEMBERS_SITE_IMAGE_PATH" => "/members/post165/members-og.jpg",
      "MEMBERS_SITE_IMAGE_ALT" => "Example Post Members"
    )
    @organization = Organization.create!(name: "Synthetic American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Private", last_name: "SyntheticMember"), email_address: "private@example.test")
  end

  teardown { Rails.application.config.x.members_site = @original_identity }

  test "signed out shared links and token previews expose only configured generic metadata" do
    link = MagicLink.create_for!(@user)
    host! "untrusted.example.test"
    assert_no_difference -> { Session.count } do
      get "/meetings/123?token=private-query&title=secret-agenda"
      assert_redirected_to new_session_path
      follow_redirect!(headers: { "User-Agent" => "facebookexternalhit/1.1" })
      assert_response :success
      assert_select "title", text: "Example Post Members"
      assert_select "h1", text: "Example Post Members"
      assert_safe_metadata
      assert_no_match(/SyntheticMember|secret-agenda/, response.body)
      get code_session_path(token: "private-query")
      assert_safe_metadata
      get magic_link_session_path(token: link.token)
      assert_response :success
      assert_safe_metadata
      assert_select "input[name='token'][value=?]", link.token, count: 1
      head magic_link_session_path(token: link.token)
      assert_response :success
    end
    assert_nil link.reload.used_at
    assert_nil cookies[:session_id]
  end

  test "signed in page keeps useful browser title with generic social fields and all icon links" do
    sign_in_as(@user)
    get profile_path
    assert_response :success
    assert_select "title", text: "Your profile"
    assert_safe_metadata
    assert_select "link[rel='icon'][href='/favicon.svg'][type='image/svg+xml']", count: 1
    assert_select "link[rel='icon'][href='/favicon-96.png'][sizes='96x96']", count: 1
    assert_select "link[rel='icon'][href='/favicon.ico']", count: 1
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png'][sizes='180x180']", count: 1
    get magic_link_agent_access_reauthentication_path(token: "secret-reauth-token")
    assert_response :success
    assert_safe_metadata
  end

  test "branding assets are public self-contained images with expected media types and dimensions" do
    {
      "/members/post165/members-og.jpg" => [ "image/jpeg", 1200, 630 ],
      "/members/members-og.jpg" => [ "image/jpeg", 1200, 630 ],
      "/favicon-96.png" => [ "image/png", 96, 96 ],
      "/apple-touch-icon.png" => [ "image/png", 180, 180 ],
      "/members/app-icon-192.png" => [ "image/png", 192, 192 ],
      "/members/app-icon-512.png" => [ "image/png", 512, 512 ]
    }.each do |path, (type, width, height)|
      get path
      assert_response :success
      assert_equal type, response.media_type
      assert_equal [ width, height ], [ Vips::Image.new_from_buffer(response.body, "").width, Vips::Image.new_from_buffer(response.body, "").height ]
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    end
    get "/favicon.svg"
    assert_equal "image/svg+xml", response.media_type
    svg = Nokogiri::XML(response.body)
    assert_empty svg.xpath("//*[local-name()='text' or local-name()='image' or local-name()='use']")
    assert_includes response.body, "#C6A15B"
    get "/favicon.ico"
    assert_response :success
    assert_includes [ "image/vnd.microsoft.icon", "image/x-icon" ], response.media_type
    assert_equal 3, response.body.byteslice(4, 2).unpack1("v")
    assert_equal [ [ 16, 16 ], [ 32, 32 ], [ 48, 48 ] ], 3.times.map { |i| response.body.byteslice(6 + i * 16, 2).bytes }
    assert_nil cookies[:session_id]
    assert_equal 0, Session.count
  end

  private

  def assert_safe_metadata
    identity = Rails.application.config.x.members_site
    assert_select "meta[property='og:title'][content=?]", identity.name, count: 1
    assert_select "meta[property='og:site_name'][content=?]", identity.name, count: 1
    assert_select "meta[property='og:description'][content=?]", identity.description, count: 1
    assert_select "meta[property='og:type'][content='website']", count: 1
    assert_select "meta[property='og:url'][content='https://members.example.test/']", count: 1
    assert_select "meta[property='og:image'][content='https://members.example.test/members/post165/members-og.jpg']", count: 1
    assert_select "meta[property='og:image:type'][content='image/jpeg']", count: 1
    assert_select "meta[property='og:image:width'][content='1200']", count: 1
    assert_select "meta[property='og:image:height'][content='630']", count: 1
    assert_select "meta[property='og:image:alt'][content=?]", identity.image_alt, count: 1
    assert_select "meta[name='description'][content=?]", identity.description, count: 1
    assert_select "meta[name='application-name'][content=?]", identity.name, count: 1
    assert_select "meta[name='twitter:card'][content='summary_large_image']", count: 1
    assert_select "meta[name='twitter:title'][content=?]", identity.name, count: 1
    assert_select "meta[name='twitter:description'][content=?]", identity.description, count: 1
    assert_select "meta[name='twitter:image'][content=?]", identity.image_url, count: 1
    assert_select "meta[name='twitter:image:alt'][content=?]", identity.image_alt, count: 1
    head_content = Nokogiri::HTML(response.body).at_css("head").to_s
    assert_no_match(/SyntheticMember|secret-agenda|private-query|secret-reauth-token|untrusted\.example|token=/, head_content)
    assert_select "meta[name='robots'][content='noindex, nofollow']", count: 1
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end
end
