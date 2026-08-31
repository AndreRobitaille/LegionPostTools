require "test_helper"

class Admin::MinutesEditorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Legion Hall",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago)
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @first_section = @minutes.sections.first
    @second_section = @minutes.sections.create!(title: "New Business", position: 2)
    @first_item = @first_section.items.create!(title: "Adjutant report", behavior_type: "report_slot", position: 1)
    @second_item = @first_section.items.create!(title: "Finance report", behavior_type: "report_slot", position: 2)
    @manager = create_user_with("manage_minutes")
  end

  test "manager edits the independent minutes heading" do
    sign_in_as(@manager)

    get edit_admin_meeting_minutes_path(@meeting)
    assert_response :success
    assert_select "input[name='meeting_minutes[title]'][value='#{@minutes.title}']"

    patch admin_meeting_minutes_path(@meeting), params: {
      meeting_minutes: {
        title: "Corrected historical heading",
        location_name: "Community Room",
        location_address: "123 Main Street",
        lock_version: @minutes.lock_version
      }
    }

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal "Corrected historical heading", @minutes.reload.title
    assert_equal "Community Room", @minutes.location_name
    assert_not_equal @minutes.title, @meeting.reload.title
  end

  test "workspace renders the complete manual editing controls" do
    @first_item.outcomes.create!(
      kind: "motion",
      text: "Fund the memorial project.",
      disposition: "not_recorded",
      position: 1
    )
    @minutes.attendance_entries.create!(office_name: "Commander", status: "not_recorded", position: 1)
    sign_in_as(@manager)

    get admin_meeting_minutes_path(@meeting)

    assert_response :success
    assert_select "a[href='#{edit_admin_meeting_minutes_path(@meeting)}']", text: "Edit heading"
    assert_select ".minutes-item-card", count: 2
    assert_select ".minutes-outcome-disposition--not_recorded", text: "Needs review"
    assert_select "a[href='#{new_admin_meeting_minutes_item_path(@meeting, minutes_section_id: @first_section.id)}']"
    assert_select "a[href='#{new_admin_meeting_minutes_outcome_path(@meeting, minutes_item_id: @first_item.id)}']"
    assert_select "a[href='#{edit_admin_meeting_minutes_attendance_path(@meeting)}']", text: "Record attendance"
  end

  test "internal record viewer sees the workspace but cannot edit it" do
    viewer = create_user_with("view_internal_records")
    sign_in_as(viewer)

    get admin_meeting_minutes_path(@meeting)
    assert_response :success
    assert_select "a", text: "Edit heading", count: 0
    assert_select "a", text: /Add item/, count: 0

    get edit_admin_meeting_minutes_path(@meeting)
    assert_redirected_to root_path
  end

  test "manager adds renames moves and removes an empty section" do
    sign_in_as(@manager)

    assert_difference -> { MinutesSection.count }, 1 do
      post admin_meeting_minutes_sections_path(@meeting), params: { minutes_section: { title: "Good of the Legion" } }
    end
    added = @minutes.sections.find_by!(title: "Good of the Legion")
    assert_equal 3, added.position

    patch admin_meeting_minutes_section_path(@meeting, added), params: {
      minutes_section: { title: "Announcements", lock_version: added.lock_version }
    }
    assert_equal "Announcements", added.reload.title

    patch move_admin_meeting_minutes_section_path(@meeting, added, direction: "up")
    assert_equal [ @first_section.id, added.id, @second_section.id ], @minutes.sections.reload.pluck(:id)

    assert_difference -> { MinutesSection.count }, -1 do
      delete admin_meeting_minutes_section_path(@meeting, added)
    end

    assert_no_difference -> { MinutesSection.count } do
      delete admin_meeting_minutes_section_path(@meeting, @first_section)
    end
    assert_match(/Move or remove/, flash[:alert])
  end

  test "manager adds edits moves and removes standalone minutes items" do
    sign_in_as(@manager)

    assert_difference -> { MinutesItem.count }, 1 do
      post admin_meeting_minutes_items_path(@meeting, minutes_section_id: @second_section.id), params: {
        minutes_item: {
          minutes_section_id: @second_section.id,
          title: "Project update",
          behavior_type: "business_item",
          body: "The committee reported progress."
        }
      }
    end
    item = @second_section.items.find_by!(title: "Project update")
    assert_nil item.source_dated_agenda_item
    assert_match(/reported progress/, item.body.to_plain_text)

    patch admin_meeting_minutes_item_path(@meeting, item), params: {
      minutes_item: {
        minutes_section_id: @first_section.id,
        title: "Project report",
        behavior_type: "report_slot",
        body: "A factual correction.",
        endeavor_id: "",
        lock_version: item.lock_version
      }
    }
    assert_equal @first_section, item.reload.minutes_section
    assert_equal 3, item.position
    assert_equal "Project report", item.title

    patch move_admin_meeting_minutes_item_path(@meeting, item, direction: "up")
    assert_equal [ @first_item.id, item.id, @second_item.id ], @first_section.items.reload.pluck(:id)

    assert_difference -> { MinutesItem.count }, -1 do
      delete admin_meeting_minutes_item_path(@meeting, item)
    end
  end

  test "manager records motion results and roster-backed participants" do
    mover = Person.create!(first_name: "Alice", last_name: "Member", roster_member_status: "Active")
    seconder = Person.create!(first_name: "Robert", last_name: "Legionnaire", roster_member_status: "Active")
    sign_in_as(@manager)

    assert_difference -> { MinutesOutcome.count }, 1 do
      post admin_meeting_minutes_outcomes_path(@meeting, minutes_item_id: @first_item.id), params: {
        minutes_outcome: {
          kind: "motion",
          text: "Fund the memorial project.",
          mover_person_id: mover.id,
          seconder_person_id: seconder.id,
          disposition: "adopted",
          vote_summary: ""
        }
      }
    end
    first = @first_item.outcomes.first
    assert_equal "adopted", first.disposition
    assert_equal mover, first.mover_person
    assert_equal seconder, first.seconder_person
    assert_equal "Alice Member", first.mover_name
    assert_equal "Robert Legionnaire", first.seconder_name

    second = @first_item.outcomes.create!(kind: "decision", text: "Meet next Tuesday.", disposition: "no_vote", position: 2)
    patch move_admin_meeting_minutes_outcome_path(@meeting, second, direction: "up")
    assert_equal [ second.id, first.id ], @first_item.outcomes.reload.pluck(:id)

    patch admin_meeting_minutes_outcome_path(@meeting, first), params: {
      minutes_outcome: {
        kind: "motion",
        text: first.text,
        mover_person_id: mover.id,
        seconder_unidentified: "1",
        disposition: "lost",
        vote_summary: "unanimous",
        lock_version: first.reload.lock_version
      }
    }
    assert_equal "Alice Member", first.reload.mover_name
    assert_nil first.seconder_person
    assert_nil first.seconder_name
    assert_equal "lost", first.disposition

    assert_difference -> { MinutesOutcome.count }, -1 do
      delete admin_meeting_minutes_outcome_path(@meeting, second)
    end
  end

  test "motion form uses plain result choices and roster search" do
    Person.create!(first_name: "Dean", last_name: "Legionnaire", roster_member_status: "Active")
    sign_in_as(@manager)

    get new_admin_meeting_minutes_outcome_path(@meeting, minutes_item_id: @first_item.id)

    assert_response :success
    assert_select "legend", text: "Outcome"
    assert_select "input[type='radio'][name='minutes_outcome[disposition]'][value='adopted']"
    assert_select "input[type='radio'][name='minutes_outcome[disposition]'][value='lost']"
    assert_select "input[type='radio'][name='minutes_outcome[disposition]'][value='other']"
    assert_select "input[type='radio'][value='not_recorded']", count: 0
    assert_select "input[type='search'][name='minutes_outcome[mover_search]']"
    assert_select "script#minutes_roster_people", text: /Dean/
  end

  test "other motion result stores the specific recorded outcome" do
    sign_in_as(@manager)

    assert_difference -> { MinutesOutcome.count }, 1 do
      post admin_meeting_minutes_outcomes_path(@meeting, minutes_item_id: @first_item.id), params: {
        minutes_outcome: {
          kind: "motion",
          text: "Send the proposal to the executive committee.",
          disposition: "other",
          other_disposition: "referred",
          vote_summary: ""
        }
      }
    end

    assert_equal "referred", @first_item.outcomes.last.disposition
  end

  test "manager records officer attendance while preserving explicit unknowns" do
    first = @minutes.attendance_entries.create!(office_name: "Commander", person_name: "C. Officer", status: "not_recorded", position: 1)
    second = @minutes.attendance_entries.create!(office_name: "Adjutant", person_name: "A. Officer", status: "not_recorded", position: 2)
    sign_in_as(@manager)

    get edit_admin_meeting_minutes_attendance_path(@meeting)
    assert_response :success
    assert_select "select[name='attendance_entries[#{first.id}][status]']"

    patch admin_meeting_minutes_attendance_path(@meeting), params: {
      attendance_entries: {
        first.id.to_s => { status: "present", lock_version: first.lock_version },
        second.id.to_s => { status: "not_recorded", lock_version: second.lock_version }
      }
    }

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal "present", first.reload.status
    assert_equal "not_recorded", second.reload.status
  end

  test "non-draft minutes reject every editor surface" do
    @minutes.update_column(:status, "approved")
    sign_in_as(@manager)

    get new_admin_meeting_minutes_section_path(@meeting)
    assert_redirected_to admin_meeting_minutes_path(@meeting)

    assert_no_difference -> { MinutesItem.count } do
      post admin_meeting_minutes_items_path(@meeting, minutes_section_id: @first_section.id), params: {
        minutes_item: { minutes_section_id: @first_section.id, title: "Should not save", behavior_type: "business_item" }
      }
    end
    assert_redirected_to admin_meeting_minutes_path(@meeting)
  end

  private

  def create_user_with(*capabilities)
    person = Person.create!(first_name: "Minutes", last_name: SecureRandom.hex(3))
    user = User.create!(person: person, email_address: "minutes-editor-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
