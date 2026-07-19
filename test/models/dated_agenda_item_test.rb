require "test_helper"

class DatedAgendaItemTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Reports", category: "reports", behavior_type: "report_slot", position: 1, active: true, body: "Report text")
  end

  test "catalog entry must belong to the same organization as the dated agenda" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_entry = other.agenda_item_catalog_entries.create!(title: "Other", category: "reports", behavior_type: "report_slot", position: 1, active: true)

    item = @agenda.dated_agenda_items.build(agenda_item_catalog_entry: other_entry, position: 1, title: "Other", behavior_type: "report_slot")

    assert_not item.valid?
    assert_includes item.errors[:agenda_item_catalog_entry], "must belong to the same organization"
  end

  test "behavior_type must be one of the supported catalog behavior types" do
    item = @agenda.dated_agenda_items.build(
      agenda_item_catalog_entry: @catalog_entry,
      position: 1,
      title: "Reports",
      behavior_type: "not_real"
    )

    assert_not item.valid?
    assert_includes item.errors[:behavior_type], "is not included in the list"
  end

  test "create_from_catalog_entry copies rich text body" do
    item = DatedAgendaItem.create_from_catalog_entry!(@catalog_entry, position: 1, dated_agenda: @agenda)

    assert_equal "Reports", item.title
    assert_equal "report_slot", item.behavior_type
    assert_includes item.body.to_s, "Report text"
  end

  test "stale item update and destroy fail after parent approval" do
    item = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Reports", behavior_type: "report_slot", active: true)
    stale_item = DatedAgendaItem.find(item.id)
    fresh_agenda = DatedAgenda.find(@agenda.id)
    fresh_agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    assert_not stale_item.update(title: "Blocked")
    assert_includes stale_item.errors.full_messages.join, "agenda is locked"

    assert_not stale_item.destroy
    assert_includes stale_item.errors.full_messages.join, "agenda is locked"
  end

  test "reorder! rewrites positions to match the given id order" do
    entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
    entry_b = @organization.agenda_item_catalog_entries.create!(title: "B", category: "reports", behavior_type: "report_slot", position: 11, active: true)
    first = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)
    second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_b, position: 2, title: "B", behavior_type: "report_slot", active: true)

    DatedAgendaItem.reorder!(@agenda, [ second.id, first.id ])

    assert_equal 1, second.reload.position
    assert_equal 2, first.reload.position
  end

  test "reorder! uses only active agenda items when validating the id set" do
    entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
    entry_b = @organization.agenda_item_catalog_entries.create!(title: "B", category: "reports", behavior_type: "report_slot", position: 11, active: true)
    entry_c = @organization.agenda_item_catalog_entries.create!(title: "C", category: "reports", behavior_type: "report_slot", position: 12, active: true)
    active_first = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)
    active_second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_b, position: 2, title: "B", behavior_type: "report_slot", active: true)
    @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_c, position: 3, title: "C", behavior_type: "report_slot", active: false)

    DatedAgendaItem.reorder!(@agenda, [ active_second.id, active_first.id ])

    assert_equal 1, active_second.reload.position
    assert_equal 2, active_first.reload.position
  end

  test "reorder! succeeds when an inactive agenda item occupies position one" do
    entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
    entry_b = @organization.agenda_item_catalog_entries.create!(title: "B", category: "reports", behavior_type: "report_slot", position: 11, active: true)
    entry_c = @organization.agenda_item_catalog_entries.create!(title: "C", category: "reports", behavior_type: "report_slot", position: 12, active: true)
    @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: false)
    active_first = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_b, position: 2, title: "B", behavior_type: "report_slot", active: true)
    active_second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_c, position: 3, title: "C", behavior_type: "report_slot", active: true)

    DatedAgendaItem.reorder!(@agenda, [ active_second.id, active_first.id ])

    assert_equal 2, active_second.reload.position
    assert_equal 3, active_first.reload.position
  end

  test "reorder! bumps lock_version" do
    entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
    entry_b = @organization.agenda_item_catalog_entries.create!(title: "B", category: "reports", behavior_type: "report_slot", position: 11, active: true)
    first = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)
    second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_b, position: 2, title: "B", behavior_type: "report_slot", active: true)

    assert_difference -> { first.reload.lock_version }, 2 do
      DatedAgendaItem.reorder!(@agenda, [ second.id, first.id ])
    end
  end

  test "reorder! raises when the id set does not match the agenda's items" do
    entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
    only = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)

    assert_raises(ActiveRecord::RecordNotFound) do
      DatedAgendaItem.reorder!(@agenda, [ only.id, 999_999 ])
    end
  end

  test "reorder! raises when given only a subset of agenda item ids" do
    entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
    entry_b = @organization.agenda_item_catalog_entries.create!(title: "B", category: "reports", behavior_type: "report_slot", position: 11, active: true)
    first = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)
    @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_b, position: 2, title: "B", behavior_type: "report_slot", active: true)

    assert_raises(ActiveRecord::RecordNotFound) do
      DatedAgendaItem.reorder!(@agenda, [ first.id ])
    end
  end
end
