require "test_helper"
require_relative "../support/minutes_distribution_provider"

class RosterEmailReconciliationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @organization = Organization.create!(name: "Synthetic roster Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @organization.create_minutes_distribution_setting!(post_members_list_id: "members", minutes_recipients_list_id: "minutes")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = User.create!(person: Person.create!(first_name: "Roster", last_name: "Administrator"), email_address: "roster-admin@example.test")
    @admin.permission_grants.create!(capability: "manage_settings")
    @person = Person.create!(first_name: "John", last_name: "Smith", member_number: "000204540637",
      roster_member_status: "Active", roster_email_address: "old@example.test", roster_imported_at: 1.day.ago)
    @member = User.create!(person: @person, email_address: "old@example.test", email_verified_at: Time.current)
  end

  test "upload replaces login email then only the new address receives a working sign-in code" do
    old_link = MagicLink.create_for!(@member)
    grant = @member.permission_grants.create!(capability: "view_internal_records")
    provider = MinutesDistributionProvider.new
    provider.add("old@example.test", userId: "american-legion-member:000204540637", mailingLists: { "members" => true, "minutes" => true })
    original_contact = provider.contacts.fetch("old@example.test").deep_dup
    @organization.loops_roster_enrollments.create!(email: "old@example.test", list_id: "members",
      member_user_id: "american-legion-member:000204540637", loops_contact_id: original_contact.fetch("id"))
    sign_in_as(@admin)

    assert_no_emails { upload(file_fixture("roster_valid.csv").read) }
    result = RosterImport.order(:id).last
    get admin_roster_import_path(result)
    assert_select ".item", text: /Sign-in emails updated from National: 1/
    assert_equal "john.smith@example.com", @member.reload.email_address
    assert_equal [ grant.id ], @member.permission_grants.pluck(:id)
    sync = LoopsRosterSync.create!(roster_import: result, requested_by: @admin)
    Loops::RosterSynchronizer.new(sync, client: provider, sleeper: ->(_) { }).call
    assert_equal 0, sync.reload.failed_count
    assert_equal original_contact.merge("email" => "john.smith@example.com", "firstName" => "John", "lastName" => "Smith"),
      provider.contacts.fetch("john.smith@example.com")
    assert_not provider.contacts.key?("old@example.test")

    browser = open_session
    browser.post magic_link_session_path, params: { token: old_link.token }
    assert_equal new_session_url, browser.response.location
    assert_no_emails do
      perform_enqueued_jobs { browser.post session_path, params: { email_address: "old@example.test" } }
    end
    assert_emails 1 do
      perform_enqueued_jobs { browser.post session_path, params: { email_address: "john.smith@example.com" } }
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "john.smith@example.com" ], mail.to
    code = mail.text_part.body.to_s[/\b\d{4} \d{4}\b/]
    assert code
    browser.post code_session_path, params: { code: code }
    assert_equal root_url, browser.response.location
    browser.get profile_path
    assert_equal 200, browser.response.status
    assert_includes browser.response.body, "John Smith"
    assert_equal "john.smith@example.com", @member.reload.email_address
    assert @member.reload.email_verified_at
  end

  test "departure and deceased status deny existing sessions and old links and globally stop Loops mail" do
    departed = Person.create!(first_name: "Former", last_name: "Member", member_number: "FORMER",
      roster_member_status: "Active", roster_email_address: "former@example.test", roster_imported_at: 1.day.ago)
    former_user = User.create!(person: departed, email_address: departed.roster_email_address)
    members = [ @member, former_user ]
    stale_links = members.map { |user| MagicLink.create_for!(user) }
    browsers = members.map do |user|
      open_session.tap do |browser|
        link = MagicLink.create_for!(user)
        browser.post magic_link_session_path, params: { token: link.token }
        browser.get profile_path
        assert_equal 200, browser.response.status
      end
    end
    provider = MinutesDistributionProvider.new
    members.each do |user|
      provider.add(user.email_address, userId: "american-legion-member:#{user.person.member_number}",
        mailingLists: { "members" => true, "minutes" => true })
    end
    sign_in_as(@admin)
    csv = file_fixture("roster_valid.csv").read.sub("JOHN.SMITH@example.com", "old@example.test").sub(",2026,Active", ",2026,Deceased")

    upload(csv)
    assert departed.reload.roster_removed_at
    assert_equal "Deceased", @person.reload.roster_member_status
    sync = LoopsRosterSync.create!(roster_import: RosterImport.order(:id).last, requested_by: @admin)
    Loops::RosterSynchronizer.new(sync, client: provider, sleeper: ->(_) { }).call
    assert_equal 0, sync.reload.failed_count
    assert_equal 2, sync.list_results.fetch("globally_unsubscribed")

    members.each_with_index do |user, index|
      assert user.reload.disabled_at
      assert_equal false, provider.contacts.fetch(user.email_address).fetch("subscribed")
      browser = browsers[index]
      browser.get profile_path
      assert_equal new_session_url, browser.response.location
      browser.post magic_link_session_path, params: { token: stale_links[index].token }
      assert_equal new_session_url, browser.response.location
      assert_no_emails do
        perform_enqueued_jobs { browser.post session_path, params: { email_address: user.email_address } }
      end
    end
  end

  private

  def upload(csv)
    Tempfile.create([ "synthetic-roster", ".csv" ]) do |file|
      file.write(csv)
      file.flush
      post admin_roster_imports_path, params: {
        roster_import: { file: Rack::Test::UploadedFile.new(file.path, "text/csv") }
      }
    end
    assert_equal "completed", RosterImport.order(:id).last.status
  end
end
