require "test_helper"
require_relative "../../support/minutes_distribution_provider"
require_relative "../../support/minutes_distribution_data"

class MinutesDistribution::RosterCoexistenceTest < ActiveSupport::TestCase
  include MinutesDistributionData
  setup { setup_distribution }

  test "two roster syncs preserve external minutes recipients and other lists then minutes sends" do
    overlap = Person.create!(first_name: "Overlap", last_name: "Member", member_number: "S100",
      roster_member_status: "Active", roster_email_address: recipient.email)
    only_member = Person.create!(first_name: "Only", last_name: "Member", member_number: "S101",
      roster_member_status: "Grace", roster_email_address: "member@example.test")
    outside = add_recipient("district@example.test", office: "District Commander")
    provider.contacts[recipient.email]["mailingLists"]["unrelated"] = true
    provider.contacts[outside.email]["firstName"] = "External name stays"
    provider.add(only_member.roster_email_address, subscribed: false, mailingLists: { "unrelated" => true })
    untouched = provider.contacts[outside.email].deep_dup
    2.times { sync_roster }
    assert_equal untouched, provider.contacts[outside.email]
    assert_equal({ "minutes" => true, "unrelated" => true, "members" => true }, provider.contacts[recipient.email]["mailingLists"])
    assert_equal false, provider.contacts[only_member.roster_email_address]["subscribed"]
    provider.payloads.each do |payload|
      assert_equal [ "members" ], payload.fetch(:mailingLists).keys
      assert_not payload.key?(:subscribed)
      assert_not payload.key?(:userGroup)
    end
    dispatch(attest)
    assert_equal [ recipient.email, outside.email ].sort, provider.messages.map { |message| message.fetch(:email) }.sort
    overlap.update!(roster_removed_at: Time.current)
    sync = sync_roster
    assert_equal 1, sync.list_results.fetch("removed")
    assert_equal({ "minutes" => true, "unrelated" => true }, provider.contacts[recipient.email]["mailingLists"])
    assert provider.contacts.key?(recipient.email)
    dispatch(correct("Balance: $112."))
    assert_equal 4, provider.messages.size
    assert provider.messages.last(2).any? { |message| message[:email] == recipient.email }
  end

  test "member identity collisions and address moves need review without moving minutes subscriptions" do
    member = Person.create!(first_name: "Old", last_name: "Member", member_number: "S200",
      roster_member_status: "Active", roster_email_address: "old@example.test")
    provider.add("old@example.test", userId: "american-legion-member:S200", mailingLists: { "minutes" => true, "members" => true })
    organization.loops_roster_enrollments.create!(email: "old@example.test", member_user_id: "american-legion-member:S200",
      loops_contact_id: provider.contacts.fetch("old@example.test").fetch("id"), list_id: "members")
    member.update!(roster_email_address: recipient.email)
    before = provider.contacts.deep_dup
    sync = sync_roster
    assert_equal 2, sync.failed_count, "Both the new-address conflict and old-address removal need review"
    assert_equal 1, sync.list_results.fetch("identity_conflicts")
    assert_equal 1, sync.list_results.fetch("removal_needs_review")
    assert_equal before, provider.contacts
    assert_empty provider.payloads
  end

  test "recipient list opt-out survives sync and explicit enrollment reads back its actual state" do
    Person.create!(first_name: "List", last_name: "Choice", member_number: "S201",
      roster_member_status: "Active", roster_email_address: recipient.email)
    provider.list_opt_outs << [ recipient.email, "members" ]
    provider.list_opt_outs << [ recipient.email, "minutes" ]
    provider.contacts[recipient.email]["mailingLists"].delete("minutes")
    sync = sync_roster
    assert_equal 1, sync.list_results.fetch("retained_opt_outs")
    MinutesDistribution::Enrollment.call(recipient, client: provider)
    assert_equal "opted_out", recipient.reload.enrollment_status
    assert_equal({}, provider.contacts.fetch(recipient.email).fetch("mailingLists"))
    dispatch(attest)
    assert_empty provider.messages
  end

  test "missing identical or public group configuration cannot become an all-audience fallback" do
    [ [], [ { "id" => "members", "isPublic" => true }, { "id" => "minutes", "isPublic" => false } ] ].each do |lists|
      provider.lists = lists
      sync = sync_roster
      assert_equal "failed", sync.status
      assert_empty provider.payloads
      dispatch(attest) if minutes.editable?
      assert_empty provider.messages
    end
    settings = organization.minutes_distribution_setting
    assert_not settings.update(minutes_recipients_list_id: "members")
  end

  test "unresolved former member identity is visible as a partial sync with its address" do
    organization.loops_roster_enrollments.create!(email: "former@example.test", member_user_id: "american-legion-member:former",
      loops_contact_id: "missing-contact", list_id: "members")
    sync = sync_roster
    assert_equal 1, sync.list_results.fetch("removal_needs_review")
    assert_equal 1, sync.failed_count
    assert_equal "former@example.test", sync.failures.sole.fetch("email")
    assert_match(/identity|review/i, sync.failures.sole.fetch("message"))
  end

  private

  def sync_roster
    source = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "synthetic-roster.csv")
    sync = LoopsRosterSync.create!(roster_import: source, requested_by: officer)
    Loops::RosterSynchronizer.new(sync, client: provider, sleeper: ->(_) { }).call
    sync.reload
  end
end
