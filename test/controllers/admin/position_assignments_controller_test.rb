require "test_helper"

class Admin::PositionAssignmentsControllerTest < ActionDispatch::IntegrationTest
  test "creates position assignment for person" do
    prepare_setup_complete_state
    user = sign_in_manage_settings_admin
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)

    assert_difference -> { person.position_assignments.count }, 1 do
      post admin_person_position_assignments_path(person), params: {
        position_assignment: {
          position_title_id: commander.id,
          starts_on: "2026-07-01",
          ends_on: "2026-12-31"
        }
      }
    end

    assert_redirected_to admin_person_path(person)
    assert_equal "Post role assigned.", flash[:notice]
    assert_equal commander, person.position_assignments.first.position_title
  end

  test "ends position assignment" do
    prepare_setup_complete_state
    sign_in_manage_settings_admin
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)
    assignment = person.position_assignments.create!(position_title: commander, starts_on: Date.new(2026, 7, 1))

    patch admin_person_position_assignment_path(person, assignment), params: {
      position_assignment: { ends_on: "2026-12-31" }
    }

    assert_redirected_to admin_person_path(person)
    assert_equal "Post role updated.", flash[:notice]
    assert_equal Date.new(2026, 12, 31), assignment.reload.ends_on
  end

  test "update cannot modify someone else's assignment via nested person route" do
    prepare_setup_complete_state
    sign_in_manage_settings_admin
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637")
    other_person = Person.create!(first_name: "Jane", last_name: "Roe", member_number: "000204540638")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)
    assignment = other_person.position_assignments.create!(position_title: commander, starts_on: Date.new(2026, 7, 1))

    patch admin_person_position_assignment_path(person, assignment), params: {
      position_assignment: { ends_on: "2026-12-31" }
    }

    assert_response :not_found
    assert_nil assignment.reload.ends_on
  end

  test "invalid date order redirects with alert and does not create invalid assignment" do
    prepare_setup_complete_state
    sign_in_manage_settings_admin
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)

    assert_no_difference -> { person.position_assignments.count } do
      post admin_person_position_assignments_path(person), params: {
        position_assignment: {
          position_title_id: commander.id,
          starts_on: "2026-12-31",
          ends_on: "2026-07-01"
        }
      }
    end

    assert_redirected_to admin_person_path(person)
    assert_equal "Ends on must be on or after starts on", flash[:alert]
  end

  test "invalid date order redirects with alert and does not update invalid assignment" do
    prepare_setup_complete_state
    sign_in_manage_settings_admin
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637")
    commander = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)
    assignment = person.position_assignments.create!(position_title: commander, starts_on: Date.new(2026, 7, 1))

    patch admin_person_position_assignment_path(person, assignment), params: {
      position_assignment: { ends_on: "2026-06-01" }
    }

    assert_redirected_to admin_person_path(person)
    assert_equal "Ends on must be on or after starts on", flash[:alert]
    assert_nil assignment.reload.ends_on
  end

  test "inactive position title redirects with alert and does not create assignment" do
    prepare_setup_complete_state
    sign_in_manage_settings_admin
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637")
    inactive_title = PositionTitle.create!(organization: Organization.first, name: "Inactive Role", display_order: 1, active: false)

    assert_no_difference -> { person.position_assignments.count } do
      post admin_person_position_assignments_path(person), params: {
        position_assignment: {
          position_title_id: inactive_title.id,
          starts_on: "2026-07-01",
          ends_on: "2026-12-31"
        }
      }
    end

    assert_redirected_to admin_person_path(person)
    assert_equal "Selected post role is not available.", flash[:alert]
  end

  private

  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_manage_settings_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    user
  end
end
