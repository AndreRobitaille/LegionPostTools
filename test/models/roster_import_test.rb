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

  test "problems and removed_members read from summary safely" do
    ri = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "x.csv",
      summary: { "problems" => [ { "row" => 4, "message" => "m" } ], "removed_members" => [ { "name" => "N" } ] })
    assert_equal 1, ri.problems.size
    assert_equal "N", ri.removed_members.first["name"]
    blank = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "y.csv")
    assert_equal [], blank.problems
    assert_equal [], blank.removed_members
    assert_equal({}, blank.field_changes)
    assert_equal [], blank.created_members
    assert_equal [], blank.created_accounts
    assert_equal [], blank.status_changes
    assert_equal [], blank.deceased_status_reversals
    assert_equal 0, blank.returned_count
    assert_not blank.detailed_change_summary?
  end

  test "older imports retain deceased reversal warnings without inventing member identities" do
    roster_import = RosterImport.new(summary: {
      field_changes: { roster_member_status: { transitions: [
        { from: "Deceased", to: "Active", count: 1 },
        { from: "Active", to: "Deceased", count: 2 },
        { from: "Deceased", to: " deceased ", count: 1 }
      ] } }
    })

    assert_equal [ { "from" => "Deceased", "to" => "Active", "count" => 1 } ], roster_import.deceased_status_reversals
  end

  test "history orders newest first" do
    older = RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "old.csv")
    newer = RosterImport.create!(status: "completed", imported_at: 1.hour.ago, uploaded_filename: "new.csv")
    assert_equal [ newer, older ], RosterImport.history.to_a.first(2)
  end

  test "pending confirmation requires an attached csv" do
    roster_import = RosterImport.new(
      status: "pending_confirmation",
      imported_at: Time.current,
      uploaded_filename: "large-removal.csv",
      summary: { removal_confirmation_required: true }
    )

    assert_not roster_import.valid?
    assert_includes roster_import.errors[:pending_csv], "must be attached"

    roster_import.pending_csv.attach(
      io: StringIO.new("Member ID,Name\n0001,Example\n"),
      filename: "large-removal.csv",
      content_type: "text/csv"
    )

    assert roster_import.valid?
    assert roster_import.pending_csv.attached?
  end
end
