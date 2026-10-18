require "test_helper"

class MembersSiteTest < ActiveSupport::TestCase
  test "unconfigured installations have a generic identity and artwork" do
    identity = MembersSite.new({})
    assert_equal "Post Members", identity.name
    assert_equal "https://example.invalid/", identity.entry_url
    assert_equal "https://example.invalid/members/members-og.jpg", identity.image_url
    assert_no_match(/165|Two Rivers/, [ identity.name, identity.description, identity.image_alt ].join)
  end

  test "Post 165 deployment profile selects the approved installation identity" do
    config = YAML.safe_load_file(Rails.root.join("config/deploy.yml"))
    identity = MembersSite.new(config.fetch("env").fetch("clear"))
    assert_equal "Post 165 Members", identity.name
    assert_equal "Meeting agendas, minutes, and member resources for Post 165 in Two Rivers. Member sign-in required.", identity.description
    assert_equal "Post 165 Members — Two Rivers.", identity.image_alt
    assert_equal "https://members.wipost165.org/", identity.entry_url
    assert_equal "https://members.wipost165.org/members/post165/members-og.jpg", identity.image_url
  end

  test "configured origins and image paths reject request-like and token-bearing URLs" do
    [ "http://members.example", "//members.example", "https://user:secret@members.example", "https://members.example/private",
      "https://members.example/?token=secret", "https://members.example/#secret", "https://members.example/\n" ].each do |origin|
      assert_raises(ArgumentError) { MembersSite.new("MEMBERS_SITE_ORIGIN" => origin) }
    end
    [ "//evil.example/a.jpg", "https://evil.example/a.jpg", "/members/a.jpg?token=secret", "/members/../a.jpg" ].each do |path|
      assert_raises(ArgumentError) { MembersSite.new("MEMBERS_SITE_IMAGE_PATH" => path) }
    end
    identity = MembersSite.new("APP_HOST" => "members.example")
    assert_equal "https://members.example/", identity.entry_url
  end
end
