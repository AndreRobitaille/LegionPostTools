require "test_helper"

class Loops::RosterAudienceTest < ActiveSupport::TestCase
  test "selects present active and grace members with unique valid emails" do
    active = roster_person("Active", status: " Active ", email: "ACTIVE@example.com")
    grace = roster_person("Grace", status: "grace", email: "grace@example.com")
    roster_person("Expired", status: "expired", email: "expired@example.com")
    roster_person("Removed", status: "active", email: "removed@example.com", removed: true)
    Person.create!(first_name: "Local", last_name: "Only", roster_member_status: "active", roster_email_address: "local@example.com")

    audience = Loops::RosterAudience.new

    assert_equal [ active, grace ], audience.contacts.map(&:person)
    assert_equal 2, audience.eligible_count
  end

  test "counts and skips blank invalid and shared roster emails" do
    roster_person("Blank", status: "active", email: nil)
    roster_person("Invalid", status: "active", email: "not-an-email")
    roster_person("Shared One", status: "active", email: "shared@example.com")
    roster_person("Shared Two", status: "grace", email: "SHARED@example.com")

    audience = Loops::RosterAudience.new

    assert_empty audience.contacts
    assert_equal 1, audience.missing_email_count
    assert_equal 1, audience.invalid_email_count
    assert_equal 2, audience.shared_email_count
  end

  test "contact payload uses stable member identity and never changes Loops audience choices" do
    person = roster_person("Alex", status: "active", email: "alex@example.com")
    person.update!(roster_name: "Legion, Alex Q.")

    payload = Loops::RosterAudience.new.contacts.first.payload

    assert_equal "alex@example.com", payload[:email]
    assert_equal "american-legion-member:#{person.member_number}", payload[:userId]
    assert_equal "Alex Q.", payload[:firstName]
    assert_equal "Legion", payload[:lastName]
    assert_not payload.key?(:subscribed)
    assert_not payload.key?(:userGroup)
    assert_not payload.key?(:mailingLists)
  end

  private

  def roster_person(first_name, status:, email:, removed: false)
    Person.create!(
      first_name: first_name,
      last_name: "Member",
      member_number: "M#{Person.count + 1}",
      roster_member_status: status,
      roster_email_address: email,
      roster_removed_at: (Time.current if removed)
    )
  end
end
