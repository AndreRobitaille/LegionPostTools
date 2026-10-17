require "test_helper"

class SignInReturnPathTest < ActiveSupport::TestCase
  test "only canonical supported navigation paths can be restored" do
    [ "/", "/profile", "/meetings/12", "/meetings/12/minutes", "/dated_agendas/3", "/people/4", "/calendar",
      "/admin/meetings/4/minutes", "/admin/dated_agendas/4/commander" ].each do |path|
      assert SignInReturnPath.allowed?(path), path
    end
    [ nil, {}, "https://evil.example/meetings/1", "//evil.example", "/\\evil.example", "/%2f%2fevil.example", "/meetings/1?token=secret",
      "/meetings/1#fragment", "/meetings/01", "/meetings/1/../2", "/meetings/1\n", "/session/new", "/session/magic_link", "/session/code",
      "/oauth/authorize", "/passkeys/authentication", "/setup/new", "/api/meetings/1", "/dated_agendas/1/print", "/internal/dated-agenda-pdf-source",
      "/official_action_reauthentication/new", "/agent_access_tokens/new", "/rails/active_storage/blobs/redirect/token/file" ].each do |path|
      assert_not SignInReturnPath.allowed?(path), path.inspect
      assert_nil SignInReturnPath.destination("path" => path, "expires_at" => 1.minute.from_now.to_i)
    end
  end

  test "saved destinations must be unexpired structured session state" do
    [ nil, "/meetings/1", {}, { "path" => "/meetings/1", "expires_at" => "tomorrow" },
      { "path" => "/meetings/1", "expires_at" => 1.second.ago.to_i } ].each do |saved|
      assert_nil SignInReturnPath.destination(saved)
    end
    assert_equal "/meetings/1", SignInReturnPath.destination("path" => "/meetings/1", "expires_at" => 1.minute.from_now.to_i)
  end
end
