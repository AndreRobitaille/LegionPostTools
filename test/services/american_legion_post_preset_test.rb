require "test_helper"

class AmericanLegionPostPresetTest < ActiveSupport::TestCase
  test "creates standard post titles and meeting bodies" do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )

    AmericanLegionPostPreset.apply_to(organization)

    assert_equal [
      "Commander",
      "1st Vice Commander",
      "2nd Vice Commander",
      "Adjutant",
      "Finance Officer",
      "Chaplain",
      "Sergeant-at-Arms",
      "Historian",
      "Service Officer",
      "Judge Advocate",
      "Assistant Chaplain"
    ], organization.position_titles.order(:display_order).pluck(:name)

    assert_equal [ true, true, true, true, true, true, true, false, false, false, false ],
      organization.position_titles.order(:display_order).pluck(:required_by_default)

    assert_equal [ "membership", "pec" ], organization.meeting_bodies.order(:slug).pluck(:slug)
    assert_equal [ "Membership Meeting", "Post Executive Committee" ], organization.meeting_bodies.order(:slug).pluck(:name)
    assert_equal [ "email", "print" ], organization.meeting_bodies.order(:slug).pluck(:default_distribution)
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

  test "restores preset values without creating duplicates" do
    organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )

    AmericanLegionPostPreset.apply_to(organization)

    organization.position_titles.find_by!(name: "Commander").update!(display_order: 99, required_by_default: false)
    organization.position_titles.find_by!(name: "Assistant Chaplain").update!(display_order: 1, required_by_default: true)
    organization.meeting_bodies.find_by!(slug: "pec").update!(name: "Wrong Name", default_distribution: "sms")

    assert_no_difference -> { organization.position_titles.count + organization.meeting_bodies.count } do
      AmericanLegionPostPreset.apply_to(organization)
    end

    assert_equal [
      "Commander",
      "1st Vice Commander",
      "2nd Vice Commander",
      "Adjutant",
      "Finance Officer",
      "Chaplain",
      "Sergeant-at-Arms",
      "Historian",
      "Service Officer",
      "Judge Advocate",
      "Assistant Chaplain"
    ], organization.position_titles.order(:display_order).pluck(:name)

    assert_equal [ true, true, true, true, true, true, true, false, false, false, false ],
      organization.position_titles.order(:display_order).pluck(:required_by_default)

    assert_equal "Post Executive Committee", organization.meeting_bodies.find_by!(slug: "pec").name
    assert_equal "print", organization.meeting_bodies.find_by!(slug: "pec").default_distribution
  end
end
