require "test_helper"

class DatedAgendaRollCallEntryTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    catalog_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Roll Call and Quorum",
      category: "administration",
      behavior_type: "roll_call",
      position: 1,
      active: true
    )
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(catalog_entry, position: 1)

    @commander_title = create_title("Commander", position: 1, required: true)
    @adjutant_title = create_title("Adjutant", position: 2, required: true)
    @historian_title = create_title("Historian", position: 3, required: false)
    @service_title = create_title("Service Officer", position: 4, required: false)

    @commander = Person.create!(first_name: "Pat", last_name: "Commander")
    @historian = Person.create!(first_name: "Harper", last_name: "Historian")
    @commander_title.position_assignments.create!(person: @commander, starts_on: Date.new(2026, 7, 1))
    @historian_title.position_assignments.create!(person: @historian, starts_on: Date.new(2026, 8, 1), ends_on: Date.new(2026, 8, 31))
  end

  test "dated roll call snapshots required and assigned offices as of the meeting date" do
    item = create_agenda.dated_agenda_items.find_by!(behavior_type: "roll_call")

    assert_equal(
      [
        [ "Commander", "Pat Commander" ],
        [ "Adjutant", nil ],
        [ "Historian", "Harper Historian" ]
      ],
      item.roll_call_entries.map { |entry| [ entry.office_name, entry.person_name ] }
    )
    assert item.roll_call_entries.second.vacant?
    assert_not_includes item.roll_call_entries.map(&:office_name), "Service Officer"
  end

  test "snapshot uses meeting date rather than agenda creation date" do
    future_adjutant = Person.create!(first_name: "Alex", last_name: "Adjutant")
    @adjutant_title.position_assignments.create!(person: future_adjutant, starts_on: Date.new(2026, 8, 5))

    item = create_agenda.dated_agenda_items.find_by!(behavior_type: "roll_call")

    assert item.roll_call_entries.find { |entry| entry.office_name == "Adjutant" }.vacant?
  end

  test "later officer changes do not rewrite the dated snapshot" do
    item = create_agenda.dated_agenda_items.find_by!(behavior_type: "roll_call")

    @commander.update!(first_name: "Changed")
    @commander_title.update!(name: "Post Commander")

    row = item.roll_call_entries.first.reload
    assert_equal "Commander", row.office_name
    assert_equal "Pat Commander", row.person_name
  end

  test "draft roll call can be deliberately refreshed" do
    item = create_agenda.dated_agenda_items.find_by!(behavior_type: "roll_call")
    adjutant = Person.create!(first_name: "Alex", last_name: "Adjutant")
    @adjutant_title.position_assignments.create!(person: adjutant, starts_on: Date.new(2026, 7, 1))

    assert item.roll_call_entries.find { |entry| entry.office_name == "Adjutant" }.vacant?

    item.refresh_roll_call!

    assert_equal "Alex Adjutant", item.roll_call_entries.reload.find { |entry| entry.office_name == "Adjutant" }.person_name
  end

  test "approved agenda roll call cannot be refreshed" do
    agenda = create_agenda
    item = agenda.dated_agenda_items.find_by!(behavior_type: "roll_call")
    approver = User.create!(person: Person.create!(first_name: "Approval", last_name: "Officer"), email_address: "approval@example.com", email_verified_at: Time.current)
    agenda.approve!(approver)

    assert_raises(ActiveRecord::RecordInvalid) { item.refresh_roll_call! }
    assert_includes item.errors.full_messages.to_sentence, "draft"
  end

  private

  def create_title(name, position:, required:)
    @organization.position_titles.create!(
      name: name,
      display_order: position,
      required_by_default: required,
      active: true
    )
  end

  def create_agenda
    DatedAgenda.create_from_template!(
      organization: @organization,
      meeting_body: @meeting_body,
      meeting_type: @meeting_type,
      starts_at: Time.zone.local(2026, 8, 4, 19, 0)
    )
  end
end
