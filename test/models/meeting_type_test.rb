require "test_helper"

class MeetingTypeTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "derives slug from name when none is given" do
    meeting_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 1, active: true)

    assert_equal "pec-meeting", meeting_type.slug
  end

  test "derived slug avoids collisions within the organization" do
    @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    second = @organization.meeting_types.create!(name: "Membership/Meeting", position: 2, active: true)

    assert_equal "membership-meeting-2", second.slug
  end

  test "slug uniqueness is scoped to organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)

    meeting_type = other_organization.meeting_types.new(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)

    assert meeting_type.valid?
  end

  test "name uniqueness is scoped to organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    duplicate = @organization.meeting_types.new(name: "Membership Meeting", position: 2, active: true)
    same_name_elsewhere = other_organization.meeting_types.new(name: "Membership Meeting", position: 1, active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert same_name_elsewhere.valid?
  end

  test "position uniqueness is scoped to organization" do
    @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    duplicate = @organization.meeting_types.new(name: "PEC Meeting", position: 1, active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position], "has already been taken"
  end

  test "normalizes blank source key to nil" do
    meeting_type = @organization.meeting_types.create!(name: "Local Meeting", position: 1, active: true, source_key: "")

    assert_nil meeting_type.source_key
    assert_not meeting_type.seeded?
  end

  test "orders by position then name" do
    later = @organization.meeting_types.create!(name: "Later", position: 2, active: true)
    earlier = @organization.meeting_types.create!(name: "Earlier", position: 1, active: true)

    assert_equal [ earlier, later ], @organization.meeting_types.ordered.to_a
  end

  test "can be destroyed cleanly" do
    meeting_type = @organization.meeting_types.create!(name: "Annual Meeting", position: 1, active: true)

    assert_difference -> { MeetingType.count }, -1 do
      assert_difference -> { @organization.meeting_types.count }, -1 do
        meeting_type.destroy!
      end
    end
  end
end
