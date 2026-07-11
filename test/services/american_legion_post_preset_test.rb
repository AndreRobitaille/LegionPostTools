require "test_helper"

class AmericanLegionPostPresetTest < ActiveSupport::TestCase
  test "creates standard post titles and meeting bodies" do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )

    AmericanLegionPostPreset.apply_to(organization)

    assert_equal ["Commander", "1st Vice Commander", "2nd Vice Commander", "Adjutant"],
      organization.position_titles.order(:display_order).limit(4).pluck(:name)
    assert_equal ["membership", "pec"], organization.meeting_bodies.order(:slug).pluck(:slug)
  end

  test "can be applied more than once without duplicates" do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )

    2.times { AmericanLegionPostPreset.apply_to(organization) }

    assert_equal 11, organization.position_titles.count
    assert_equal 2, organization.meeting_bodies.count
  end
end
