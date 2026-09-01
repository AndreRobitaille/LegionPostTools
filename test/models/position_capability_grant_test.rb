require "test_helper"

class PositionCapabilityGrantTest < ActiveSupport::TestCase
  test "allows officer duties but never app administration" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    title = PositionTitle.create!(organization:, name: "Adjutant", display_order: 1)

    assert PositionCapabilityGrant.new(position_title: title, capability: "manage_minutes").valid?

    grant = PositionCapabilityGrant.new(position_title: title, capability: "manage_settings")
    assert_not grant.valid?
    assert_includes grant.errors[:capability], "is not included in the list"
  end

  test "does not duplicate a capability on one position" do
    organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    title = PositionTitle.create!(organization:, name: "Commander", display_order: 1)
    title.position_capability_grants.create!(capability: "manage_agendas")

    duplicate = title.position_capability_grants.new(capability: "manage_agendas")
    assert_not duplicate.valid?
  end
end
