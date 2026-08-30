require "test_helper"

class DatedAgendaSectionTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @agenda = create_dated_agenda!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 9, 1, 19), title: "Membership Meeting", status: "draft")
    @user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current)
  end

  test "new dated agendas receive a default section" do
    assert_equal [ "Order of Business" ], @agenda.dated_agenda_sections.pluck(:title)
  end

  test "source section must belong to the agenda meeting type" do
    other_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 2, active: true)
    section = @agenda.dated_agenda_sections.new(title: "Other", position: 2, meeting_type_agenda_section: other_type.default_agenda_section)

    assert_not section.valid?
    assert_includes section.errors[:meeting_type_agenda_section], "must belong to the agenda's meeting type"
  end

  test "locked agendas reject section creation update and destruction" do
    section = @agenda.default_agenda_section
    @agenda.approve!(@user)

    assert_not @agenda.dated_agenda_sections.create(title: "Post Business", position: 2).persisted?
    assert_not section.update(title: "Changed")
    assert_not section.destroy
    assert_includes section.errors.full_messages.join, "agenda is locked"
  end

  test "reorder persists section order" do
    first = @agenda.default_agenda_section
    second = @agenda.dated_agenda_sections.create!(title: "Post Business", position: 2)

    DatedAgendaSection.reorder!(@agenda, [ second.id, first.id ])

    assert_equal [ "Post Business", "Order of Business" ], @agenda.dated_agenda_sections.ordered.pluck(:title)
  end
end
