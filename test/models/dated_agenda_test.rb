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
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    assert_equal "Membership Meeting — 04 AUG 2026", agenda.title
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

  test "meeting upcoming uses the installation's local calendar-day boundary" do
    Time.use_zone("America/Chicago") do
      travel_to Time.zone.local(2026, 8, 4, 0, 30) do
        previous_evening = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 3, 23, 30), title: "Previous evening", status: "published")
        current_evening = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Current evening", status: "published")

        assert_not_includes Meeting.upcoming, previous_evening.meeting
        assert_includes Meeting.upcoming, current_evening.meeting
      end
    end
  end

  test "stores an installation-local start as UTC" do
    Time.use_zone("America/Chicago") do
      agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 7, 7, 18, 30), title: "Summer meeting", status: "draft")

      assert_equal Time.utc(2026, 7, 7, 23, 30), agenda.reload.starts_at.utc
    end
  end

  test "create_from_template snapshots document controls and Commander notes" do
    @template_item.update!(
      show_wording_on_agenda: false,
      show_wording_in_minutes: false,
      commander_notes: "Wait for the color guard."
    )

    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    item = agenda.dated_agenda_items.first

    assert_not item.show_wording_on_agenda?
    assert_not item.show_wording_in_minutes?
    assert_includes item.commander_notes.to_plain_text, "color guard"

    @template_item.update!(show_wording_on_agenda: true, show_wording_in_minutes: true, commander_notes: "Changed later")

    assert_not item.reload.show_wording_on_agenda?
    assert_not item.show_wording_in_minutes?
    assert_includes item.commander_notes.to_plain_text, "color guard"
  end

  test "create_from_template copies section structure and item membership" do
    opening = @meeting_type.default_agenda_section
    opening.update!(title: "Opening Ceremony")
    business = @meeting_type.meeting_type_agenda_sections.create!(title: "Post Business", position: 2)
    business_entry = @organization.agenda_item_catalog_entries.create!(title: "New Business", category: "business", behavior_type: "business_item", position: 2, active: true)
    business_item = @meeting_type.meeting_type_agenda_items.create!(agenda_section: business, agenda_item_catalog_entry: business_entry, position: 1, title: "New Business", active: true)

    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    assert_equal [ "Opening Ceremony", "Post Business" ], agenda.dated_agenda_sections.ordered.pluck(:title)
    assert_equal [ [ "Opening" ], [ "New Business" ] ], agenda.dated_agenda_sections.ordered.map { |section| section.agenda_items.pluck(:title) }
    assert_equal business, agenda.dated_agenda_sections.find_by!(title: "Post Business").meeting_type_agenda_section
    assert_equal business_item, agenda.dated_agenda_items.find_by!(title: "New Business").meeting_type_agenda_item
  end

  test "copied dated agenda sections are independent from template sections" do
    @meeting_type.default_agenda_section.update!(title: "Opening Ceremony")
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    @meeting_type.default_agenda_section.update!(title: "Changed Template Section")

    assert_equal "Opening Ceremony", agenda.default_agenda_section.reload.title
  end

  test "copied dated agenda items are independent from later template edits" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    item = agenda.dated_agenda_items.first

    @template_item.update!(title: "Changed Template", summary: "Changed summary", body: "Changed body")

    assert_equal "Opening", item.reload.title
    assert_equal "Template summary", item.summary
    assert_includes item.body.to_s, "Template body"
  end

  test "editing a dated agenda item does not change the template item" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    agenda.dated_agenda_items.first.update!(title: "Meeting-specific Opening", body: "Meeting-specific body")

    assert_equal "Opening", @template_item.reload.title
    assert_includes @template_item.body.to_s, "Template body"
  end

  test "locked agendas reject ordinary item changes" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.first
    assert_not item.update(title: "Changed after approval")
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end

  test "locked agendas reject item creation" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.build(agenda_item_catalog_entry: @catalog_entry, position: 2, title: "New Item", behavior_type: "scripted_ceremony")

    assert_not item.save
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end

  test "locked agendas reject item destruction" do
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.first

    assert_not item.destroy
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end

  test "a locked agenda can be destroyed as a whole with its sections and items" do
    user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
    agenda = create_dated_agenda_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(user)
    agenda.publish!(user)
    item_ids = agenda.dated_agenda_items.ids
    section_ids = agenda.dated_agenda_sections.ids

    assert agenda.destroy!

    assert_not DatedAgenda.exists?(agenda.id)
    assert_not DatedAgendaItem.where(id: item_ids).exists?
    assert_not DatedAgendaSection.where(id: section_ids).exists?
  end

  test "approve only allows draft agendas" do
    user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
    agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")

    agenda.approve!(user)

    assert_equal "approved", agenda.reload.status
    assert_equal user, agenda.approved_by

    assert_raises(ActiveRecord::RecordInvalid) { agenda.approve!(user) }
    assert_equal user, agenda.reload.approved_by
  end

  test "publish only allows approved agendas" do
    user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
    agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")

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
    agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")

    assert_raises(ActiveRecord::RecordInvalid) { agenda.reopen!(user) }

    agenda.approve!(user)
    agenda.reopen!(user)

    assert_equal "draft", agenda.reload.status
    assert_nil agenda.approved_by
  end
end
