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
        assert_difference -> { Session.count }, 1 do
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
    end

    organization = Organization.first
    user = User.first

    assert_equal "american_legion_post", organization.unit_type
    assert user.can?("manage_settings")
    assert_equal 11, organization.position_titles.count
    assert_equal 2, organization.meeting_bodies.count
    assert_redirected_to root_path
  end

  test "rejects invalid setup params" do
    assert_no_difference -> { Organization.count } do
      assert_no_difference -> { User.count } do
        assert_no_difference -> { Session.count } do
          post setup_path, params: {
            organization: {
              name: "",
              unit_number: "165",
              timezone: "America/Chicago",
              default_location_name: "Manitowoc Rifle & Pistol Club",
              default_location_address: "7227 Sandy Hill Lane\nTwo Rivers, WI"
            },
            person: {
              first_name: "",
              last_name: "",
              email_address: ""
            },
            preset: "american_legion_post"
          }
        end
      end
    end

    assert_response :unprocessable_entity
    assert_select "h1", "Set up LegionPostTools"
  end

  test "setup cannot be reopened after setup exists" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get new_setup_path

    assert_redirected_to root_path
  end

  test "organization only still shows setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get new_setup_path

    assert_response :success
    assert_select "h1", "Set up LegionPostTools"
  end

  test "user without organization still shows setup" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")

    get new_setup_path

    assert_response :success
    assert_select "h1", "Set up LegionPostTools"
  end

  test "repeated setup post after completion does not create duplicates" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_no_difference -> { Organization.count } do
      assert_no_difference -> { User.count } do
        post setup_path, params: {
          organization: {
            name: "Another Post",
            unit_number: "166",
            timezone: "America/Chicago",
            default_location_name: "Club",
            default_location_address: "123 Main St"
          },
          person: {
            first_name: "Andre",
            last_name: "Robitaille",
            email_address: "andre@example.com"
          }
        }
      end
    end

    assert_redirected_to root_path
  end
end
