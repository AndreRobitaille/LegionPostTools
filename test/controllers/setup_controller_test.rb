require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "shows setup when app has no organization or user" do
    get new_setup_path

    assert_response :success
    assert_select "h1", "Set up LegionPostTools"
  end

  test "creates organization first person user permissions and preset data" do
    assert_difference -> { Organization.count }, 1 do
      assert_difference -> { User.count }, 1 do
        post setup_path, params: {
          organization: {
            name: "Robert E. Burns Post 165",
            unit_number: "165",
            timezone: "America/Chicago",
            default_location_name: "Manitowoc Rifle & Pistol Club",
            default_location_address: "7227 Sandy Hill Lane\nTwo Rivers, WI"
          },
          person: {
            first_name: "Andre",
            last_name: "Robitaille",
            email_address: "andre@example.com"
          },
          preset: "american_legion_post"
        }
      end
    end

    organization = Organization.first
    user = User.first

    assert_equal "american_legion_post", organization.unit_type
    assert user.can?("manage_settings")
    assert_equal 11, organization.position_titles.count
    assert_equal 2, organization.meeting_bodies.count
    assert_redirected_to root_path
  end

  test "setup cannot be reopened after setup exists" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get new_setup_path

    assert_redirected_to root_path
  end
end
