require "test_helper"

class RosterImportTest < ActiveSupport::TestCase
  test "latest_successful returns newest successful import" do
    older = RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "old.csv")
    newer = RosterImport.create!(status: "completed", imported_at: 1.day.ago, uploaded_filename: "new.csv")
    RosterImport.create!(status: "failed", imported_at: Time.current, uploaded_filename: "bad.csv")

    assert_equal newer, RosterImport.latest_successful
    assert_not_equal older, RosterImport.latest_successful
  end

  test "stale when newest successful import is older than thirty days" do
    RosterImport.create!(status: "completed", imported_at: 31.days.ago, uploaded_filename: "old.csv")

    assert RosterImport.roster_stale?
  end

  test "fresh when newest successful import is within thirty days" do
    RosterImport.create!(status: "completed", imported_at: 5.days.ago, uploaded_filename: "fresh.csv")

    assert_not RosterImport.roster_stale?
  end
end
