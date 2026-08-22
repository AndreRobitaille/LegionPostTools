require "test_helper"

class TrackedItemTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @user = User.create!(person: Person.create!(first_name: "Pat", last_name: "Adjutant"), email_address: "pat-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
  end

  test "priority bucket combines importance and a thirty day urgency window" do
    today = Date.new(2026, 8, 22)

    necessity = build_item(importance: "important", raise_by_on: today + 30.days)
    focus = build_item(importance: "important", raise_by_on: today + 31.days)
    delegate = build_item(importance: "standard", raise_by_on: today)
    keep_tracking = build_item(importance: "standard", raise_by_on: nil)

    assert_equal "necessity", necessity.priority_bucket(on: today)
    assert_equal "focus", focus.priority_bucket(on: today)
    assert_equal "delegate", delegate.priority_bucket(on: today)
    assert_equal "keep_tracking", keep_tracking.priority_bucket(on: today)
  end

  test "meeting body must belong to the same organization" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_body = other.meeting_bodies.create!(name: "Other Membership", slug: "other-membership")

    item = build_item(meeting_body: other_body)

    assert_not item.valid?
    assert_includes item.errors[:meeting_body], "must belong to the same organization"
  end

  test "complete and reopen record a human-controlled lifecycle" do
    item = build_item
    item.save!

    item.complete!(@user)

    assert item.reload.completed?
    assert_equal @user, item.completed_by
    assert_not_nil item.completed_at

    item.reopen!

    assert item.reload.active?
    assert_nil item.completed_by
    assert_nil item.completed_at
  end

  test "completion and reopen reject invalid transitions" do
    item = build_item
    item.save!

    assert_raises(ActiveRecord::RecordInvalid) { item.reopen! }
    item.complete!(@user)
    assert_raises(ActiveRecord::RecordInvalid) { item.complete!(@user) }
  end

  private

  def build_item(attributes = {})
    TrackedItem.new({
      organization: @organization,
      meeting_body: @meeting_body,
      created_by: @user,
      title: "Car Show",
      summary: "Confirm the permit plan."
    }.merge(attributes))
  end
end
