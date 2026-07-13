require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "shows setup when app has no organization or user" do
    get new_setup_path

    assert_response :success
    assert_select "h1", "LegionPostTools"
    assert_select "input[type=submit][value=?]", "Create your post"
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
    assert_equal 1, Installation.count
    assert Installation.setup_completed?
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
    assert_select "h1", "LegionPostTools"
    assert_select "input[type=submit][value=?]", "Create your post"
  end

  test "setup cannot be reopened after setup exists" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    get new_setup_path

    assert_redirected_to root_path
  end

  test "organization only still shows setup" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get new_setup_path

    assert_response :success
    assert_select "h1", "LegionPostTools"
    assert_select "input[type=submit][value=?]", "Create your post"
  end

  test "user without organization still shows setup" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")

    get new_setup_path

    assert_response :success
    assert_select "h1", "LegionPostTools"
    assert_select "input[type=submit][value=?]", "Create your post"
  end

  test "both organization and user without setup completion redirects new setup to session sign in" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    get new_setup_path

    assert_redirected_to new_session_path
    assert_equal "Setup recovery requires operator help.", flash[:alert]
  end

  test "both organization and user without setup completion blocks setup post" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_no_difference -> { PermissionGrant.count } do
      assert_no_difference -> { Session.count } do
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

    assert_redirected_to new_session_path
    assert_equal "Setup recovery requires operator help.", flash[:alert]
  end

  test "disabled admin after setup does not reopen setup" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Installation.singleton.update!(setup_completed_at: Time.current)

    user.update!(disabled_at: Time.current)
    PermissionGrant.where(user: user, capability: "manage_settings").delete_all

    get new_setup_path

    assert_redirected_to root_path
  end

  test "repeated setup post after completion does not create duplicates" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

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

  test "partial organization only post reuses organization and creates first user" do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_no_difference -> { Organization.count } do
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

    assert_equal organization.id, Organization.first.id
    user = User.first
    assert_equal "andre@example.com", user.email_address
    assert_equal "Andre", user.person.first_name
    assert user.can?("manage_settings")
    assert_equal 11, organization.reload.position_titles.count
    assert_equal 2, organization.meeting_bodies.count
    assert_redirected_to root_path
  end

  test "partial user only post reuses user and creates organization" do
    person = Person.create!(first_name: "Jane", last_name: "Doe", email_address: "jane@example.com")
    user = User.create!(person: person, email_address: "jane@example.com")

    assert_difference -> { Organization.count }, 1 do
      assert_no_difference -> { User.count } do
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
              first_name: "Jane",
              last_name: "Doe",
              email_address: "jane@example.com"
            },
            preset: "american_legion_post"
          }
        end
      end
    end

    assert_equal user.id, User.first.id
    assert_equal "jane@example.com", user.reload.email_address
    assert_equal "Jane", user.person.first_name
    assert user.can?("manage_settings")
    assert_equal 11, Organization.first.position_titles.count
    assert_equal 2, Organization.first.meeting_bodies.count
    assert_redirected_to root_path
  end

  test "partial organization only state can still be repaired before completion" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")

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

    assert Installation.setup_completed?
  end
end
