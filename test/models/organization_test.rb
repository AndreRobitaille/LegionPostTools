require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "the saved Post date is independent of the request zone and changes at local midnight" do
    Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    travel_to Time.utc(2026, 11, 11, 5, 59) do
      Time.use_zone("Asia/Tokyo") { assert_equal Date.new(2026, 11, 10), Organization.current_local_date }
    end
    travel_to Time.utc(2026, 11, 11, 6) do
      Time.use_zone("Pacific/Honolulu") { assert_equal Date.new(2026, 11, 11), Organization.current_local_date }
    end
  end

  test "setup and an invalid legacy saved zone use the configured app zone across request contexts" do
    previous_zone = Rails.application.config.time_zone
    travel_to Time.utc(2026, 11, 11, 1) do
      [ [ "UTC", Date.new(2026, 11, 11) ], [ "America/Chicago", Date.new(2026, 11, 10) ] ].each do |configured_zone, expected_date|
        Rails.application.config.time_zone = configured_zone
        Time.use_zone("Pacific/Honolulu") do
          assert_equal expected_date, Organization.current_local_date
          organization = Organization.create!(name: "Legacy Post", unit_type: "american_legion_post", timezone: "Invalid/LegacyZone")
          assert_equal configured_zone, organization.calendar_time_zone.name
          assert_equal expected_date, Organization.current_local_date
          organization.destroy!
        end
      end
    end
  ensure
    Rails.application.config.time_zone = previous_zone
  end

  test "the saved Post date uses the daylight-saving midnight on a short day" do
    Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    [
      [ Time.utc(2026, 3, 8, 5, 59), Date.new(2026, 3, 7) ],
      [ Time.utc(2026, 3, 8, 6), Date.new(2026, 3, 8) ],
      [ Time.utc(2026, 3, 9, 4, 59), Date.new(2026, 3, 8) ],
      [ Time.utc(2026, 3, 9, 5), Date.new(2026, 3, 9) ]
    ].each do |instant, expected_date|
      travel_to(instant) { assert_equal expected_date, Organization.current_local_date }
    end
  end

  test "normalizes and validates the public document email" do
    organization = Organization.new(
      name: "Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago",
      public_email: " POST@EXAMPLE.ORG "
    )

    assert organization.valid?
    assert_equal "post@example.org", organization.public_email

    organization.public_email = "not an email"

    assert_not organization.valid?
    assert_includes organization.errors[:public_email], "is invalid"
  end

  test "limits the printed mailing address to two nonblank lines" do
    organization = Organization.new(
      name: "Test Post",
      unit_type: "american_legion_post",
      timezone: "America/Chicago",
      mailing_address: "P.O. Box 11\n\nTwo Rivers, WI 54241"
    )

    assert organization.valid?
    assert_equal [ "P.O. Box 11", "Two Rivers, WI 54241" ], organization.mailing_address_lines

    organization.mailing_address = "Post 165\nP.O. Box 11\nTwo Rivers, WI 54241"

    assert_not organization.valid?
    assert_includes organization.errors[:mailing_address], "must fit on no more than two lines"
  end
end
