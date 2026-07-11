require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      unit_number: "165",
      timezone: "America/Chicago",
      locality: "Two Rivers, WI"
    )
  end

  test "sign-in page renders the entry hero with emblem and post identity" do
    get new_session_path
    assert_response :success
    assert_select ".entry-hero", count: 1
    assert_select "img.entry-emb[src*=?]", "al-emblem"
    assert_select "h1.entry-title", text: /Robert E\. Burns Post 165/
    assert_select ".entry-loc", text: /Two Rivers, WI/
  end

  test "sign-in page has the magic-link form and passkey placeholder" do
    get new_session_path
    assert_response :success
    assert_select "form[action=?][method=post]", session_path do
      assert_select "input[type=email][name=email_address]"
      assert_select "button", text: /Send my sign-in link/
    end
    assert_select "button.entry-passkey", text: /passkey/i
  end

  test "flash notice renders inside the sign-in card" do
    post session_path, params: { email_address: "nobody@example.com" }
    follow_redirect!
    assert_select ".entry-flash-notice", text: /Check your email/
  end

  test "magic-link confirmation renders in the entry hero" do
    get magic_link_session_path(token: "sometoken")
    assert_response :success
    assert_select ".entry-hero", count: 1
    assert_select "form[action=?][method=post]", magic_link_session_path do
      assert_select "input[type=hidden][name=token]"
      assert_select "button", text: /Finish signing in/
    end
  end

  test "sign-in page degrades gracefully when no organization is configured" do
    Organization.delete_all
    get new_session_path
    assert_response :success
    assert_select "h1.entry-title", text: "LegionPostTools"
    assert_select ".entry-kick", count: 0
    assert_select ".entry-loc", count: 0
  end
end
