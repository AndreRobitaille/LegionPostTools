require "test_helper"
require "open3"

class TimeZoneConfigurationTest < ActiveSupport::TestCase
  test "defaults to UTC when APP_TIME_ZONE is absent" do
    stdout, stderr, status = boot_time_zone(nil)

    assert status.success?, stderr
    assert_equal "Etc/UTC", stdout
  end

  test "uses the installation time zone from APP_TIME_ZONE" do
    stdout, stderr, status = boot_time_zone("America/Chicago")

    assert status.success?, stderr
    assert_equal "America/Chicago", stdout
  end

  test "rejects an invalid APP_TIME_ZONE at boot" do
    _stdout, stderr, status = boot_time_zone("Central Wisconsin Time")

    assert_not status.success?
    assert_includes stderr, "APP_TIME_ZONE must identify a valid Rails time zone"
  end

  private

  def boot_time_zone(value)
    Open3.capture3(
      { "APP_TIME_ZONE" => value, "RAILS_ENV" => "test" },
      "bin/rails", "runner", "print Time.zone.tzinfo.name",
      chdir: Rails.root.to_s
    )
  end
end
