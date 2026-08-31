require "test_helper"

class MinutesAgendaWordingBackfillTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    type = organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    agenda = create_dated_agenda_from_template!(
      organization:,
      meeting_body: body,
      meeting_type: type,
      starts_at: 1.day.ago
    )
    source = agenda.default_agenda_section.agenda_items.create!(
      dated_agenda: agenda,
      title: "Community event",
      behavior_type: "business_item",
      active: true,
      position: 1,
      show_wording_in_minutes: true,
      body: "Bring the event date and volunteer needs."
    )
    @minutes = MeetingMinutes.create_from_meeting!(meeting: agenda.meeting)
    @item = @minutes.items.find_by!(source_dated_agenda_item: source)
    @agenda_html = source.rich_text_body.body.to_html
  end

  test "separates an exact legacy agenda snapshot from appended minutes paragraphs" do
    @item.rich_text_agenda_body.destroy!
    @item.update!(body: ActionText::Content.new(<<~HTML))
      <div class="lexxy-content">
        <div class="lexxy-content">
          #{@agenda_html}
        </div>
        <p>Members discussed volunteer assignments.</p>
      </div>
      <p>The chair set a follow-up date.</p>
    HTML

    MinutesAgendaWordingBackfill.call(scope: MinutesItem.where(id: @item.id))

    assert_equal "Bring the event date and volunteer needs.", @item.reload.agenda_body.to_plain_text.squish
    assert_equal "Members discussed volunteer assignments. The chair set a follow-up date.", @item.body.to_plain_text.squish
    assert_not_includes @item.body.to_plain_text, "Bring the event date"
  end

  test "moves agenda-only legacy wording without inventing minutes" do
    @item.rich_text_agenda_body.destroy!
    @item.update!(body: ActionText::Content.new(@agenda_html))

    MinutesAgendaWordingBackfill.call(scope: MinutesItem.where(id: @item.id))

    assert_equal "Bring the event date and volunteer needs.", @item.reload.agenda_body.to_plain_text.squish
    assert_predicate @item.body.to_plain_text, :blank?
  end

  test "refuses to guess when legacy wording is not an exact snapshot" do
    @item.rich_text_agenda_body.destroy!
    @item.update!(body: "Human-edited combined wording.")

    assert_raises(MinutesAgendaWordingBackfill::SeparationError) do
      MinutesAgendaWordingBackfill.call(scope: MinutesItem.where(id: @item.id))
    end

    assert_predicate @item.reload.agenda_body.to_plain_text, :blank?
    assert_equal "Human-edited combined wording.", @item.body.to_plain_text.squish
  end
end
