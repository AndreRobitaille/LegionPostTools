require "test_helper"

class DatedAgendaTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", slug: "opening-ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, summary: "Open the meeting", body: "Opening words")
    @template_item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", summary: "Template summary", active: true, body: "Template body")
  end

  test "create_from_template copies active template items into a dated agenda" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    assert_equal "Membership Meeting — August 4, 2026", agenda.title
    assert agenda.draft?
    assert_equal 1, agenda.dated_agenda_items.count

    item = agenda.dated_agenda_items.first
    assert_equal @template_item, item.meeting_type_agenda_item
    assert_equal @catalog_entry, item.agenda_item_catalog_entry
    assert_equal "Opening", item.title
    assert_equal "Template summary", item.summary
    assert_equal "scripted_ceremony", item.behavior_type
    assert_includes item.body.to_s, "Template body"
  end

  test "copied dated agenda items are independent from later template edits" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    item = agenda.dated_agenda_items.first

    @template_item.update!(title: "Changed Template", summary: "Changed summary", body: "Changed body")

    assert_equal "Opening", item.reload.title
    assert_equal "Template summary", item.summary
    assert_includes item.body.to_s, "Template body"
  end

  test "editing a dated agenda item does not change the template item" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    agenda.dated_agenda_items.first.update!(title: "Meeting-specific Opening", body: "Meeting-specific body")

    assert_equal "Opening", @template_item.reload.title
    assert_includes @template_item.body.to_s, "Template body"
  end

  test "locked agendas reject ordinary item changes" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.first
    assert_not item.update(title: "Changed after approval")
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end

  test "locked agendas reject item creation" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.build(agenda_item_catalog_entry: @catalog_entry, position: 2, title: "New Item", behavior_type: "scripted_ceremony")

    assert_not item.save
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end

  test "locked agendas reject item destruction" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.first

    assert_not item.destroy
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end

  test "approve only allows draft agendas" do
    user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
    agenda = DatedAgenda.create!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")

    agenda.approve!(user)

    assert_equal "approved", agenda.reload.status
    assert_equal user, agenda.approved_by

    assert_raises(ActiveRecord::RecordInvalid) { agenda.approve!(user) }
    assert_equal user, agenda.reload.approved_by
  end

  test "publish only allows approved agendas" do
    user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
    agenda = DatedAgenda.create!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")

    assert_raises(ActiveRecord::RecordInvalid) { agenda.publish!(user) }

    agenda.approve!(user)
    agenda.publish!(user)

    assert_equal "published", agenda.reload.status
    assert_equal user, agenda.published_by

    assert_raises(ActiveRecord::RecordInvalid) { agenda.publish!(user) }
    assert_equal user, agenda.reload.published_by
    assert_equal user, agenda.approved_by
  end

  test "reopen only allows approved or published agendas" do
    user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
    agenda = DatedAgenda.create!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")

    assert_raises(ActiveRecord::RecordInvalid) { agenda.reopen!(user) }

    agenda.approve!(user)
    agenda.reopen!(user)

    assert_equal "draft", agenda.reload.status
    assert_nil agenda.approved_by
  end
end
