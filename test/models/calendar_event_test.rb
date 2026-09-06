require "test_helper"

class CalendarEventTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Example Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @user = User.create!(person: Person.create!(first_name: "Calendar", last_name: "Admin"), email_address: "calendar@example.com")
  end

  test "public projection excludes internal ownership and planning records" do
    endeavor = @organization.endeavors.create!(title: "Private planning", details: "Private notes", created_by: @user)
    event = build_event(endeavor: endeavor)
    assert_nil event.public_calendar_attributes
    event.visibility = "public"
    event.save!
    assert_equal %w[all_day cancelled description ends_at id location starts_at title updated_at], event.public_calendar_attributes.keys.sort
    assert_not_includes event.public_calendar_attributes.to_json, "Private planning"
    event.update!(visibility: "members")
    assert_not_includes CalendarEvent.publicly_visible, event
  end

  test "calendar month includes overlapping events and excludes unrelated months and organizations" do
    overlapping = build_event(starts_at: Time.zone.local(2026, 8, 30, 9), ends_at: Time.zone.local(2026, 9, 2, 10)).tap(&:save!)
    outside = build_event(starts_at: Time.zone.local(2026, 7, 1, 9)).tap(&:save!)
    other = Organization.create!(name: "Other", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = build_event(organization: other).tap(&:save!)
    month = CalendarMonth.new(organization: @organization, date: Date.new(2026, 9, 1))
    assert_includes month.entries, overlapping
    assert_not_includes month.entries, outside
    assert_not_includes month.entries, foreign
    assert_includes month.entries_on(Date.new(2026, 9, 2)), overlapping
    assert_not_includes month.entries_on(Date.new(2026, 9, 3)), overlapping
  end

  test "missing Endeavor is reported as a validation error" do
    event = build_event(endeavor_id: -1)
    assert_not event.valid?
    assert event.errors[:endeavor].any?
  end

  test "end must not precede start and visibility is constrained" do
    event = build_event(ends_at: Time.zone.local(2026, 9, 1, 8), visibility: "everyone")
    assert_not event.valid?
    assert event.errors[:ends_at].any?
    assert event.errors[:visibility].any?
  end

  test "completed steps and projects do not appear as calendar deadlines" do
    project = @organization.endeavors.create!(title: "Newsletter", due_on: Date.new(2026, 9, 20), created_by: @user)
    task = project.tasks.create!(title: "Print", due_on: Date.new(2026, 9, 19), created_by: @user, updated_by: @user)
    task.set_completion(true, user: @user)
    task.save!
    project.complete!(@user)
    month = CalendarMonth.new(organization: @organization, date: Date.new(2026, 9, 1), view: "deadlines")
    assert_empty month.entries
  end

  private

  def build_event(**attributes)
    CalendarEvent.new(organization: @organization, title: "Public breakfast", starts_at: Time.zone.local(2026, 9, 1, 9), created_by: @user, updated_by: @user, **attributes)
  end
end
