require "test_helper"

class PostContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Synthetic American Legion Post", unit_type: "american_legion_post",
      timezone: "America/Chicago", public_email: "post@example.test", mailing_address: "PO Box 100\nExample, WI 53000")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @member = User.create!(person: Person.create!(first_name: "Alex", last_name: "Member"), email_address: "member@example.test")
    @today = @organization.calendar_time_zone.today
  end

  test "signed out visitors see no contacts and return after signing in" do
    assignment = assign_officer("Commander", "Morgan", email_address: "commander@example.test")
    get post_contact_path
    assert_redirected_to new_session_path
    assert_not_includes response.body, "commander@example.test"
    post magic_link_session_path, params: { token: MagicLink.create_for!(@member).token }
    assert_redirected_to post_contact_path
    follow_redirect!
    assert_response :success
    assert_select ".post-contact-name", assignment.person.roster_display_name
    assert_select ".nav-tab[aria-current=page][href=?]", post_contact_path, text: "Contact the Post"
    assert_select ".app-menu-link[aria-current=page][href=?]", post_contact_path, text: "Contact the Post"
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
  end

  test "ordinary members get directory contact details without membership or login information" do
    assignment = assign_officer("Commander", "Morgan", email_address: "directory@example.test", phone_number: "+1 (920) 555-0101 ext. 42",
      roster_email_address: "roster@example.test", roster_phone_number: "9205550199", member_number: "PRIVATE123", roster_address: "Private home address")
    User.create!(person: assignment.person, email_address: "private-login@example.test")
    sign_in_as(@member)
    get post_contact_path
    assert_response :success
    assert_select ".post-contact-general a[href='mailto:post@example.test']", text: "post@example.test"
    assert_select "address", text: /PO Box 100.*Example, WI 53000/m
    assert_select "a[href='mailto:directory@example.test']", text: "directory@example.test"
    assert_select "a[href='tel:+19205550101;ext=42']", text: "+1 (920) 555-0101 ext. 42"
    assert_select ".post-contact-page .btn-primary, .post-contact-page .btn-secondary, .post-contact-page button", count: 0
    assert_select ".post-contact-details", text: /directory@example.test.*\+1 \(920\) 555-0101 ext\. 42/m
    assert_select "a[href=?]", people_path, text: "View member directory"
    %w[PRIVATE123 private-login@example.test roster@example.test 9205550199].each { |private_value| assert_not_includes response.body, private_value }
    assert_not_includes response.body, "Private home address"
  end

  test "Commander and Service Officer explain the two main needs before the remaining directory" do
    commander = assign_officer("Commander", "Morgan", order: 9, email_address: "commander@example.test")
    service = assign_officer("Service Officer", "Casey", order: 20, phone_number: "9205550104")
    assign_officer("Adjutant", "James", order: 1)
    assign_officer("Past Post Commander", "Former", order: 0)
    sign_in_as(@member)
    get post_contact_path
    assert_select ".post-contact-choice .post-contact-office" do |offices|
      assert_equal [ "Commander", "Service Officer" ], offices.map(&:text)
    end
    assert_select ".post-contact-choice .post-contact-name" do |names|
      assert_equal [ "Morgan Officer", "Casey Officer" ], names.map(&:text)
    end
    assert_select ".post-contact-responsibility", "Helps veterans and families understand benefits and find help with claims and other needs."
    assert_select ".post-contact-choice", count: 2 do
      assert_select ".post-contact-examples li", count: 4
    end
    assert_select ".post-contact-examples li", "You need help getting started with a VA claim."
    assert_select ".post-contact-officers .post-contact-name" do |names|
      assert_equal [ "Former Officer", "James Officer" ], names.map(&:text)
    end
    assert_select ".post-contact-officers .post-contact-responsibility", "Manages Post records, meeting minutes and member communications."
    assert_select ".post-contact-officers .post-contact-examples li", "Your address or contact information has changed."
    assert_select ".post-contact-officers .post-contact-examples li", "You need a replacement membership card or a copy of meeting minutes."
    assert_select ".post-contact-officers .post-contact-role-help", count: 1
    assert_equal 9, commander.position_title.reload.display_order
    assert_equal 20, service.position_title.reload.display_order
    assert_empty @member.permission_grants
  end

  test "assistant roles explain only whom they assist and retain their contact details" do
    chaplain = assign_officer("Assistant Chaplain", "Robin", email_address: "assistant@example.test")
    adjutant = assign_officer("Assistant Adjutant", "Taylor", phone_number: "9205550103")
    assign_officer("1st Vice Commander", "Pat")
    sign_in_as(@member)
    get post_contact_path
    [ [ chaplain, "Chaplain" ], [ adjutant, "Adjutant" ] ].each do |assignment, primary_role|
      assert_select "article[aria-labelledby='officer-#{assignment.id}']" do
        assert_select ".post-contact-responsibility", "Assists the #{primary_role}."
        assert_select ".post-contact-examples", count: 0
        assert_select ".post-contact-name", assignment.person.roster_display_name
      end
    end
    assert_select "a[href='mailto:assistant@example.test']", text: "assistant@example.test"
    assert_select "a[href='tel:9205550103']", text: "9205550103"
    assert_select ".post-contact-responsibility", "Leads member recruitment and retention, and fills in for the Commander."
    assert_select ".post-contact-examples li", "You need help renewing your membership."
  end

  test "missing primary officeholders or direct details offer the Post email without inventing a contact" do
    assign_officer("Commander", "Morgan")
    sign_in_as(@member)
    get post_contact_path
    assert_select ".post-contact-choice .post-contact-name", count: 1
    assert_select ".post-contact-choice", text: /A current Service Officer is not listed yet/
    assert_select ".post-contact-choice .post-contact-fallback a", count: 2
    assert_select ".post-contact-choice .post-contact-fallback a", "post@example.test"
    assert_select "a[href='mailto:post@example.test?subject=For%20the%20Service%20Officer']"
    assert_select "a[href^='tel:']", count: 0
  end

  test "only current visible people in this Posts active positions appear in configured order" do
    travel_to Time.utc(2026, 10, 19, 2) do
      # It is still October 18 at the Post, even when the request uses UTC.
      @today = Date.new(2026, 10, 18)
      first = assign_officer("Renamed Commander", "First", order: 1, starts_on: @today, ends_on: @today)
      second = assign_officer("Adjutant", "Second", order: 2)
      PositionAssignment.create!(person: first.person, position_title: second.position_title, starts_on: @today)
      PositionAssignment.create!(person: first.person, position_title: first.position_title, starts_on: @today)
      assign_officer("Former office", "Former", ends_on: @today - 1)
      assign_officer("Future office", "Future", starts_on: @today + 1)
      assign_officer("Inactive office", "Inactive", active: false)
      assign_officer("Removed office", "Removed", roster_removed_at: Time.current)
      assign_officer("Deceased office", "Deceased", roster_member_status: "Deceased")
      other = Organization.create!(name: "Another Post", unit_type: "american_legion_post", timezone: "UTC")
      assign_officer("Foreign office", "Foreign", organization: other)
      sign_in_as(@member)
      Time.use_zone("UTC") { get post_contact_path }
      assert_response :success
      assert_select ".post-contact-officers .post-contact-office", count: 3
      assert_select ".post-contact-officers .post-contact-office" do |headings|
        assert_equal [ "Renamed Commander", "Adjutant", "Adjutant" ], headings.map(&:text)
      end
      assert_select ".post-contact-name" do |names|
        assert_equal [ "First Officer", "First Officer", "Second Officer" ], names.map(&:text)
      end
    end
  end

  test "saved turnover and contact changes appear on the next request in the same session" do
    outgoing = assign_officer("Commander", "Outgoing", email_address: "outgoing@example.test")
    incoming = Person.create!(first_name: "Incoming", last_name: "Officer", roster_email_address: "incoming@example.test")
    sign_in_as(@member)
    get post_contact_path
    assert_select ".post-contact-name", "Outgoing Officer"
    outgoing.update!(ends_on: @today - 1)
    PositionAssignment.create!(position_title: outgoing.position_title, person: incoming, starts_on: @today)
    @organization.update!(public_email: "updated-post@example.test")
    get post_contact_path
    assert_select ".post-contact-name", "Incoming Officer"
    assert_not_includes response.body, "outgoing@example.test"
    assert_select "a[href='mailto:incoming@example.test']", text: "incoming@example.test"
    assert_select ".post-contact-general a[href='mailto:updated-post@example.test']", text: "updated-post@example.test"
    incoming.update!(roster_removed_at: Time.current)
    get post_contact_path
    assert_select ".post-contact-officer", count: 0
    assert_select ".empty", "Current officers have not been listed yet."
  end

  test "missing and partial contact details only offer usable actions including roster fallback" do
    assign_officer("Email only", "Email", roster_email_address: "email-only@example.test")
    assign_officer("Phone only", "Phone", roster_phone_number: "(920) 555-0102")
    assign_officer("No contacts", "None")
    assign_officer("Unusable phone", "Unknown", phone_number: "N/A")
    @organization.update!(public_email: nil, mailing_address: nil)
    sign_in_as(@member)
    get post_contact_path
    assert_select ".post-contact-general", text: /A general Post email has not been added yet/
    assert_select ".post-contact-general a", count: 0
    assert_select "address", count: 0
    assert_select ".post-contact-officer a[href^='mailto:']", count: 1
    assert_select ".post-contact-officer a[href^='tel:']", count: 1
    assert_select "a[href='tel:9205550102']", text: "(920) 555-0102"
    assert_select ".post-contact-note", "No direct contact details listed."
    assert_not_includes response.body, "Use the Post contact above"
  end

  test "membership leaders still see only the member contact projection" do
    assign_officer("Hidden officer", "Hidden", roster_removed_at: Time.current)
    visible = assign_officer("Commander", "Visible", member_number: "PRIVATE999", roster_address: "Hidden home address")
    visible.position_title.update!(grants_full_membership_access: true)
    PositionAssignment.create!(person: @member.person, position_title: visible.position_title, starts_on: @today)
    sign_in_as(@member)
    get post_contact_path
    assert_select ".post-contact-name", "Visible Officer"
    assert_not_includes response.body, "Hidden Officer"
    assert_not_includes response.body, "PRIVATE999"
    assert_not_includes response.body, "Hidden home address"
  end

  test "disabled members cannot keep reading contact details with an existing session" do
    sign_in_as(@member)
    get post_contact_path
    assert_response :success
    @member.update!(disabled_at: Time.current)
    get post_contact_path
    assert_redirected_to new_session_path
    assert_not_includes response.body, "post@example.test"
  end

  private

  def assign_officer(title, first_name, order: 10, starts_on: nil, ends_on: nil, active: true, organization: @organization, **person_attributes)
    position = organization.position_titles.create!(name: title, display_order: order, active:)
    person = Person.create!({ first_name:, last_name: "Officer" }.merge(person_attributes))
    PositionAssignment.create!(position_title: position, person:, starts_on: starts_on || @today - 1.year, ends_on:)
  end
end
