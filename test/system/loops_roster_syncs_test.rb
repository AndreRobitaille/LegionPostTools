require "application_system_test_case"
require_relative "../support/minutes_distribution_provider"

class LoopsRosterSyncsSystemTest < ApplicationSystemTestCase
  class PartialClient < MinutesDistributionProvider
    def update_contact(payload)
      if payload[:email] == "rejected@example.test"
        raise Loops::Client::RequestError.new("Synthetic contact rejected", status: 400)
      end
      super
    end
  end

  test "administrator reads actual partial sync output and loses access after grant removal" do
    Organization.create!(name: "Synthetic email audience Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Organization.first!.create_minutes_distribution_setting!(post_members_list_id: "members", minutes_recipients_list_id: "minutes")
    Installation.singleton.update!(setup_completed_at: Time.current)
    admin = User.create!(person: Person.create!(first_name: "Audience", last_name: "Administrator"),
      email_address: "audience-admin@example.test", email_verified_at: Time.current)
    grant = PermissionGrant.create!(user: admin, capability: "manage_settings")
    Person.create!(first_name: "Rejected", last_name: "First", member_number: "M109-A",
      roster_member_status: "Active", roster_email_address: "rejected@example.test")
    Person.create!(first_name: "Accepted", last_name: "Later", member_number: "M109-B",
      roster_member_status: "Active", roster_email_address: "accepted@example.test")
    source = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "synthetic-audience.csv")
    sync = LoopsRosterSync.create!(roster_import: source, requested_by: admin, eligible_count: 2)
    Loops::RosterSynchronizer.new(sync, client: PartialClient.new, sleeper: ->(_) { }).call
    assert_equal [ "completed", 1, 1 ], [ sync.reload.status, sync.synced_count, sync.failed_count ]

    system_sign_in(admin)
    original_source = [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), source.attributes, sync.attributes ]
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, width == 1400 ? 1400 : 844)
      visit admin_loops_roster_sync_path(sync)
      assert_selector "h1", text: "Roster sync finished with problems"
      assert_selector ".stat-tile--created .stat-n", text: "1"
      assert_selector ".stat-tile--problems .stat-n", text: "1"
      assert_text "Rejected First"
      assert_text "M109-A"
      assert_text "rejected@example.test"
      assert_text "Synthetic contact rejected"
      assert_text "synthetic-audience.csv"
      assert_text "Existing opt-outs remain unchanged"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      capture_system_screenshot("offline-sync-partial-#{width}")
      page.execute_script("arguments[0].scrollIntoView({block: 'center'})", find(".card--alert"))
      capture_system_screenshot("offline-sync-failure-detail-#{width}")
      click_link "Review another sync"
      assert_selector "h1", text: "Sync roster to Loops"
      assert_selector ".stat-tile--created .stat-n", text: "2"
      assert_text "An existing Loops contact who opted out stays opted out"
      find("a[href='#{admin_loops_roster_sync_path(sync)}']").click
      assert_selector "h1", text: "Roster sync finished with problems"
    end
    assert_equal original_source, [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), source.reload.attributes, sync.reload.attributes ]

    grant.destroy!
    visit admin_loops_roster_sync_path(sync)
    assert_current_path root_path
    assert_no_selector "h1", text: "Roster sync finished with problems"
    assert_no_text "rejected@example.test"
    visit profile_path
    assert_selector "h1", text: "Your profile"
    assert_selector ".profile-lead .page-sub", text: "Audience Administrator"
    assert_equal original_source, [ Person.order(:id).map(&:attributes), User.order(:id).map(&:attributes), source.reload.attributes, sync.reload.attributes ]
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
