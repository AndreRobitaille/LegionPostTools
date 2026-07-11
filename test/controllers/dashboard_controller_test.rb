require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication after setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get root_path

    assert_redirected_to new_session_path
  end

  test "authenticated user sees dashboard" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Andre", last_name: "Robitaille")
    user = User.create!(person: person, email_address: "andre@example.com", email_verified_at: Time.current)
    Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "test", last_seen_at: Time.current)

    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:session_id] = Session.last.id

    get root_path, headers: { "Cookie" => request.cookie_jar.to_header }

    assert_response :success
    assert_select "h1", "LegionPostTools"
    assert_select "p", organization.name
    assert_select "p", person.full_name
  end
end
