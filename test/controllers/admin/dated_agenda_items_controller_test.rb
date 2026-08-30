require "test_helper"

class Admin::DatedAgendaItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.first || Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership-#{SecureRandom.hex(4)}")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting-#{SecureRandom.hex(4)}", position: 99, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", slug: "opening-ceremony-#{SecureRandom.hex(4)}", category: "ceremony", behavior_type: "scripted_ceremony", position: 99, active: true, body: "Opening words")
    @template_item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 99, title: "Opening", active: true, body: "Template body")
    @agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")
    @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", behavior_type: "scripted_ceremony", active: true, body: "Template body")
  end

  test "signed out users are redirected" do
    get edit_admin_dated_agenda_agenda_item_path(@agenda, @agenda.dated_agenda_items.first)

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas are denied" do
    sign_in_as(user_with_capabilities)

    get edit_admin_dated_agenda_agenda_item_path(@agenda, @agenda.dated_agenda_items.first)

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "edit page offers the shared modal removal warning" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    get edit_admin_dated_agenda_agenda_item_path(@agenda, item)

    assert_response :success
    assert_select ".da-danger-zone[data-controller='confirm-dialog']" do
      assert_select "button[data-action='confirm-dialog#open']", text: "Remove agenda item"
      assert_select "dialog.confirm-dialog" do
        assert_select ".confirm-record-title", text: item.title
        assert_select ".confirm-record-meta", text: /#{Regexp.escape(@agenda.title)}/
        assert_select ".confirm-dialog-note", text: /catalog and meeting template will not be changed/i
        assert_select "form[action=?] input[name='_method'][value='delete']", admin_dated_agenda_agenda_item_path(@agenda, item)
      end
    end
    assert_select "[data-turbo-confirm]", count: 0
  end

  test "update copied item does not change template item or catalog entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    patch admin_dated_agenda_agenda_item_path(@agenda, item), params: {
      dated_agenda_item: {
        title: "Meeting-specific",
        summary: "New summary",
        behavior_type: "report_slot",
        body: "New body",
        commander_notes: "Ask for the report.",
        show_wording_on_agenda: "0",
        show_wording_in_minutes: "0",
        lock_version: item.lock_version
      }
    }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Agenda item updated.", flash[:notice]
    assert_equal "Meeting-specific", item.reload.title
    assert_equal "report_slot", item.behavior_type
    assert_includes item.commander_notes.to_plain_text, "Ask for the report"
    assert_not item.show_wording_on_agenda?
    assert_not item.show_wording_in_minutes?
    assert_equal "Opening", @template_item.reload.title
    assert_equal "Opening Ceremony", @catalog_entry.reload.title
  end

  test "update can move an item to another agenda section" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first
    new_section = @agenda.dated_agenda_sections.create!(title: "Post Business", position: 2)

    patch admin_dated_agenda_agenda_item_path(@agenda, item), params: {
      dated_agenda_item: { title: item.title, summary: item.summary, behavior_type: item.behavior_type, lock_version: item.lock_version, dated_agenda_section_id: new_section.id }
    }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal new_section, item.reload.agenda_section
    assert_equal 1, item.position
  end

  test "stale lock_version redirects with latest-version alert" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    item.update!(title: "Changed elsewhere")
    stale_version = item.lock_version - 1

    patch admin_dated_agenda_agenda_item_path(@agenda, item), params: { dated_agenda_item: { title: "Meeting-specific", lock_version: stale_version } }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "This agenda item was changed by someone else. Review the latest version before saving.", flash[:alert]
    assert_equal "Changed elsewhere", item.reload.title
  end

  test "add catalog item copies it into dated agenda" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report", category: "reports", behavior_type: "report_slot", position: 2, active: true, body: "Report body")

    assert_difference -> { @agenda.dated_agenda_items.count }, 1 do
      post admin_dated_agenda_agenda_items_path(@agenda), params: { agenda_item_catalog_entry_id: second_entry.id }
    end

    item = @agenda.dated_agenda_items.find_by!(agenda_item_catalog_entry: second_entry)
    assert_equal 2, item.position
    assert_includes item.body.to_s, "Report body"
    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Catalog item added.", flash[:notice]
  end

  test "reorder rewrites item positions for a draft agenda" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report-2", category: "reports", behavior_type: "report_slot", position: 2, active: true)
    second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 2, title: "Commander Report", behavior_type: "report_slot", active: true)
    first = @agenda.dated_agenda_items.ordered.first

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ second.id, first.id ] }, as: :json

    assert_response :ok
    assert_equal 1, second.reload.position
    assert_equal 2, first.reload.position
  end

  test "reorder accepts only active agenda item ids when inactive items exist" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report-2", category: "reports", behavior_type: "report_slot", position: 2, active: true)
    third_entry = @organization.agenda_item_catalog_entries.create!(title: "Inactive Report", slug: "inactive-report", category: "reports", behavior_type: "report_slot", position: 3, active: true)
    second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 2, title: "Commander Report", behavior_type: "report_slot", active: true)
    first = @agenda.dated_agenda_items.ordered.first
    @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: third_entry, position: 3, title: "Inactive Report", behavior_type: "report_slot", active: false)

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ second.id, first.id ] }, as: :json

    assert_response :ok
    assert_equal 1, second.reload.position
    assert_equal 2, first.reload.position
  end

  test "reorder succeeds when an inactive agenda item occupies position one" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")
    first = agenda.dated_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 2, title: "Opening", behavior_type: "scripted_ceremony", active: true)
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report-2", category: "reports", behavior_type: "report_slot", position: 2, active: true)
    third_entry = @organization.agenda_item_catalog_entries.create!(title: "Inactive Report", slug: "inactive-report", category: "reports", behavior_type: "report_slot", position: 3, active: true)

    agenda.dated_agenda_items.create!(agenda_item_catalog_entry: third_entry, position: 1, title: "Inactive Report", behavior_type: "report_slot", active: false)
    second = agenda.dated_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 3, title: "Commander Report", behavior_type: "report_slot", active: true)

    post reorder_admin_dated_agenda_agenda_items_path(agenda), params: { ids: [ second.id, first.id ] }, as: :json

    assert_response :ok
    assert_equal 2, second.reload.position
    assert_equal 3, first.reload.position
  end

  test "reorder with a bad id set is rejected" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ item.id, 999_999 ] }, as: :json

    assert_response :unprocessable_entity
  end

  test "reorder with a partial id set is rejected" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report-2", category: "reports", behavior_type: "report_slot", position: 2, active: true)
    second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 2, title: "Commander Report", behavior_type: "report_slot", active: true)

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ second.id ] }, as: :json

    assert_response :unprocessable_entity
  end

  test "reorder is blocked on a locked agenda" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first
    @agenda.approve!(User.last)

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ item.id ] }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing items.", flash[:alert]
  end

  test "reorder returns locked status for a locked agenda json request" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first
    @agenda.approve!(User.last)

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ item.id ] }, as: :json

    assert_response :locked
  end

  test "locked agenda item edit redirects with alert" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @agenda.approve!(User.last)
    item = @agenda.dated_agenda_items.first

    patch admin_dated_agenda_agenda_item_path(@agenda, item), params: { dated_agenda_item: { title: "Blocked", lock_version: item.lock_version } }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing items.", flash[:alert]
    assert_equal "Opening", item.reload.title
  end

  test "stale parent agenda blocks item update after approval" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    @agenda.approve!(User.last)

    patch admin_dated_agenda_agenda_item_path(@agenda, item), params: { dated_agenda_item: { title: "Blocked", lock_version: item.lock_version } }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing items.", flash[:alert]
    assert_equal "Opening", item.reload.title
  end

  test "authorized officer can remove a draft dated agenda item" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    assert_difference -> { @agenda.dated_agenda_items.count }, -1 do
      delete admin_dated_agenda_agenda_item_path(@agenda, item)
    end

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Agenda item removed.", flash[:notice]
  end

  test "authorized officer can refresh a draft officer roll call" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    commander = Person.create!(first_name: "Pat", last_name: "Commander")
    commander_title.position_assignments.create!(person: commander, starts_on: Date.new(2026, 7, 1))
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    commander.update!(first_name: "Updated")

    patch refresh_roll_call_admin_dated_agenda_agenda_item_path(@agenda, item)

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Officer roll call refreshed for the meeting date.", flash[:notice]
    assert_equal "Updated Commander", item.roll_call_entries.reload.first.person_name
  end

  test "locked officer roll call cannot be refreshed" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    @agenda.approve!(user)

    patch refresh_roll_call_admin_dated_agenda_agenda_item_path(@agenda, item)

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing items.", flash[:alert]
  end

  test "signed out users cannot edit an agenda-local officer list" do
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")

    get edit_admin_dated_agenda_agenda_item_roll_call_path(@agenda, item)

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas cannot edit an agenda-local officer list" do
    sign_in_as(user_with_capabilities)
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")

    get edit_admin_dated_agenda_agenda_item_roll_call_path(@agenda, item)

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "non-roll-call items do not expose an officer-list editor" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    get edit_admin_dated_agenda_agenda_item_roll_call_path(@agenda, item)

    assert_response :not_found
  end

  test "authorized officer can edit the agenda-local officer list without changing Post roles" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    current_commander = Person.create!(first_name: "Current", last_name: "Commander")
    historical_commander = Person.create!(first_name: "July", last_name: "Commander")
    assignment = commander_title.position_assignments.create!(person: current_commander, starts_on: Date.new(2026, 7, 1))
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    entry = item.roll_call_entries.find_by!(position_title: commander_title)

    get edit_admin_dated_agenda_agenda_item_roll_call_path(@agenda, item)

    assert_response :success
    assert_select "h1", text: "Officer list for this meeting"
    assert_select ".roll-call-editor-note", text: /only to this dated agenda/i
    assert_select "select[name=?]", "roll_call[entries][#{entry.id}][person_id]"
    assert_select "label[for='roll_call_new_entry_position_title_id']", text: "Post office"
    assert_select "label[for='roll_call_new_entry_person_id']", text: "Officer or vacancy"

    patch admin_dated_agenda_agenda_item_roll_call_path(@agenda, item), params: {
      roll_call: {
        entries: { entry.id.to_s => { person_id: historical_commander.id } },
        new_entry: { position_title_id: "", person_id: "" }
      }
    }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Officer list saved for this meeting.", flash[:notice]
    saved_entry = item.roll_call_entries.reload.find_by!(position_title: commander_title)
    assert_equal historical_commander, saved_entry.person
    assert_equal "July Commander", saved_entry.person_name
    assert_equal current_commander, assignment.reload.person
    assert_empty historical_commander.position_assignments
  end

  test "agenda-local officer list can preserve a vacancy and add an optional office" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    historian_title = @organization.position_titles.create!(name: "Historian", display_order: 2, required_by_default: false, active: true)
    commander = Person.create!(first_name: "Pat", last_name: "Commander")
    commander_title.position_assignments.create!(person: commander, starts_on: Date.new(2026, 7, 1))
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    commander_entry = item.roll_call_entries.find_by!(position_title: commander_title)

    patch admin_dated_agenda_agenda_item_roll_call_path(@agenda, item), params: {
      roll_call: {
        entries: { commander_entry.id.to_s => { person_id: "" } },
        new_entry: { position_title_id: historian_title.id, person_id: "" }
      }
    }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    rows = item.roll_call_entries.reload
    assert_equal [ "Commander", "Historian" ], rows.map(&:office_name)
    assert rows.all?(&:vacant?)
  end

  test "agenda-local officer list can remove a meeting-only row" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    adjutant_title = @organization.position_titles.create!(name: "Adjutant", display_order: 2, required_by_default: true, active: true)
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    commander_entry = item.roll_call_entries.find_by!(position_title: commander_title)
    adjutant_entry = item.roll_call_entries.find_by!(position_title: adjutant_title)

    patch admin_dated_agenda_agenda_item_roll_call_path(@agenda, item), params: {
      roll_call: {
        entries: {
          commander_entry.id.to_s => { person_id: "" },
          adjutant_entry.id.to_s => { person_id: "", remove: "1" }
        },
        new_entry: { position_title_id: "", person_id: "" }
      }
    }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal [ "Commander" ], item.roll_call_entries.reload.map(&:office_name)
  end

  test "agenda-local officer list rejects removing every row" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    entry = item.roll_call_entries.find_by!(position_title: commander_title)

    assert_no_difference -> { item.roll_call_entries.count } do
      patch admin_dated_agenda_agenda_item_roll_call_path(@agenda, item), params: {
        roll_call: {
          entries: { entry.id.to_s => { person_id: "", remove: "1" } },
          new_entry: { position_title_id: "", person_id: "" }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".app-flash-alert", text: /must include at least one office/i
  end

  test "locked agenda-local officer list cannot be edited" do
    user = user_with_capabilities("manage_agendas")
    sign_in_as(user)
    commander_title = @organization.position_titles.create!(name: "Commander", display_order: 1, required_by_default: true, active: true)
    item = @agenda.dated_agenda_items.first
    item.update!(behavior_type: "roll_call")
    entry = item.roll_call_entries.find_by!(position_title: commander_title)
    @agenda.approve!(user)

    patch admin_dated_agenda_agenda_item_roll_call_path(@agenda, item), params: {
      roll_call: { entries: { entry.id.to_s => { person_id: "" } } }
    }

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing the officer list.", flash[:alert]
  end

  test "locked agenda rejects removal" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @agenda.approve!(User.last)
    item = @agenda.dated_agenda_items.first

    assert_no_difference -> { @agenda.dated_agenda_items.count } do
      delete admin_dated_agenda_agenda_item_path(@agenda, item)
    end

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing items.", flash[:alert]
  end

  test "another organization's dated agenda routes are not found" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Other Body", slug: "other-body")
    other_type = other.meeting_types.create!(name: "Other Meeting", slug: "other-meeting", position: 1, active: true)
    other_catalog_entry = other.agenda_item_catalog_entries.create!(title: "Other Item", slug: "other-item", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    other_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: other_catalog_entry, position: 1, title: "Other Template", active: true)
    other_agenda = create_dated_agenda_from_template!(organization: other, meeting_body: other_body, meeting_type: other_type, starts_at: Time.zone.local(2026, 8, 5, 19, 0))

    get edit_admin_dated_agenda_agenda_item_path(other_agenda, other_agenda.dated_agenda_items.first)

    assert_response :not_found

    patch admin_dated_agenda_agenda_item_path(other_agenda, other_agenda.dated_agenda_items.first), params: { dated_agenda_item: { title: "Nope", lock_version: other_agenda.dated_agenda_items.first.lock_version } }

    assert_response :not_found
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
