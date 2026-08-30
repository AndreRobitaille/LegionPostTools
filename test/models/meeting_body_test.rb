require "test_helper"

class MeetingBodyTest < ActiveSupport::TestCase
  test "uses the meeting body's location before the organization default" do
    organization = Organization.create!(
      name: "Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago",
      default_location_name: "Post Hall",
      default_location_address: "100 Main Street"
    )
    meeting_body = organization.meeting_bodies.create!(
      name: "Membership",
      slug: "membership",
      default_location_name: "Gun Club",
      default_location_address: "200 Range Road"
    )

    assert_equal "Gun Club", meeting_body.effective_location_name
    assert_equal "200 Range Road", meeting_body.effective_location_address

    meeting_body.update!(default_location_name: nil, default_location_address: nil)

    assert_equal "Post Hall", meeting_body.effective_location_name
    assert_equal "100 Main Street", meeting_body.effective_location_address
  end
end
