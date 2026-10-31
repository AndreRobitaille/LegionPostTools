require "test_helper"
require_relative "../support/website_publishing_support"

class PublicOfficersTest < ActionDispatch::IntegrationTest
  include WebsitePublishingSupport

  setup do
    setup_publisher
    @organization.update!(public_email: "post@example.test")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @publisher.permission_grants.create!(capability: "manage_settings")
    @role = @organization.position_titles.create!(name: "Commander", display_order: 2, website_officer_listing: true)
    @member = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Member"), email_address: "member@example.test")
    @assignment = @role.position_assignments.create!(person: @member.person, starts_on: Date.new(2020, 1, 1))
    @token, secret = WebsiteAccessToken.issue!(organization: @organization, actor: @publisher, name: "Website")
    @headers = { "Authorization" => "Bearer #{secret}" }
  end

  teardown { teardown_publisher }

  test "website receives current officer names and saved guidance without personal contacts or private offices" do
    chaplain = @organization.position_titles.create!(name: "Chaplain", display_order: 1, website_officer_listing: true)
    assign(chaplain, "Robin", "Officer")
    assistant = @organization.position_titles.create!(name: "Assistant Chaplain", display_order: 3, website_officer_listing: true)
    assign(assistant, "Drew", "Assistant")
    custom = @organization.position_titles.create!(name: "Community Liaison", display_order: 4, website_officer_listing: true)
    assign(custom, "Taylor", "Liaison")
    private_role = @organization.position_titles.create!(name: "Private custom office", display_order: 0)
    assign(private_role, "Private", "Officer")
    inactive = @organization.position_titles.create!(name: "Finance Officer", active: false, website_officer_listing: true)
    assign(inactive, "Inactive", "Officer")
    @organization.position_titles.create!(name: "Historian", website_officer_listing: true)
    other = Organization.create!(name: "Separate Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    assign(other.position_titles.create!(name: "Service Officer", website_officer_listing: true), "Foreign", "Officer")
    @member.person.update!(first_name: "Charlie", last_name: "Example", roster_name: "Example, Sr. Charles Q.",
      email_address: "private-officer@example.test", phone_number: "9205550199", member_number: "PRIVATE-MEMBER")

    get "/public/v1/officers", headers: @headers
    assert_response :success
    body = response.parsed_body
    assert_equal %w[as_of complete officers post schema_version timezone], body.keys.sort
    assert_equal 1, body["schema_version"]
    assert_equal true, body["complete"]
    assert_equal({ "name" => "Synthetic Post", "email" => "post@example.test" }, body["post"])
    assert_equal [ "Chaplain", "Commander", "Assistant Chaplain", "Community Liaison" ], body["officers"].pluck("office")
    assert_equal [ "Robin Officer", "Charles Q. Example, Sr.", "Drew Assistant", "Taylor Liaison" ], body["officers"].pluck("name")
    body["officers"].each do |officer|
      assert_equal %w[display_order examples name office primary_contact responsibility], officer.keys.sort
    end
    assert_equal "Offers spiritual guidance and personal support to members and families, including during illness or loss.", body["officers"].first["responsibility"]
    assert_equal true, body["officers"][1]["primary_contact"]
    assert_equal "Assists the Chaplain.", body["officers"][2]["responsibility"]
    assert_empty body["officers"][2]["examples"]
    assert_nil body["officers"].last["responsibility"]
    assert_empty body["officers"].last["examples"]
    %w[private-officer@example.test member@example.test 9205550199 PRIVATE-MEMBER Private Foreign Inactive Historian].each do |private_value|
      assert_not_includes response.body, private_value
    end
    assert_equal "Charlie", @member.person.reload.first_name
    assert_equal "Example", @member.person.last_name
    assert_equal "Example, Sr. Charles Q.", @member.person.roster_name

    etag = response.headers.fetch("ETag")
    @member.person.update!(roster_name: "Example, Charles Q. Jr.")
    get "/public/v1/officers", headers: @headers.merge("If-None-Match" => etag)
    assert_response :success
    assert_not_equal etag, response.headers["ETag"]
    assert_equal "Charles Q. Example, Jr.", response.parsed_body["officers"][1]["name"]
    assert_equal "Charlie", @member.person.reload.first_name
  end

  test "editing through administration changes persisted member copy and the website representation on later requests" do
    get "/public/v1/officers", headers: @headers
    original_etag = response.headers.fetch("ETag")
    sign_in_as(@publisher)
    get edit_admin_position_title_path(@role)
    assert_response :success
    assert_select "textarea[name='position_title[contact_description]']", @role.contact_description
    assert_select "textarea[name='position_title[contact_examples_text]']", @role.contact_examples_text
    description = "Helps members bring concerns to the Post."
    examples = [ "You want to discuss <a Post idea>.", "You have a concern about a decision." ]
    patch admin_position_title_path(@role), params: { position_title: { contact_description: description, contact_examples_text: examples.join("\n") } }
    assert_redirected_to admin_position_titles_path
    assert_equal description, @role.reload.contact_description
    assert_equal examples, @role.contact_examples

    sign_in_as(@member)
    get post_contact_path
    assert_select ".post-contact-choice .post-contact-responsibility", description
    assert_select ".post-contact-choice .post-contact-examples li", examples.first
    assert_not_includes response.body, "<a Post idea>"
    get "/public/v1/officers", headers: @headers.merge("If-None-Match" => original_etag)
    assert_response :success
    assert_not_equal original_etag, response.headers["ETag"]
    officer = response.parsed_body.fetch("officers").sole
    assert_equal description, officer["responsibility"]
    assert_equal examples, officer["examples"]
  end

  test "invalid guidance retains input and saved values then a corrected submission succeeds" do
    sign_in_as(@publisher)
    original = @role.contact_guidance
    patch admin_position_title_path(@role), params: { position_title: { contact_description: "New description", contact_examples_text: "One\nTwo\nThree" } }
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /up to two examples/
    assert_select "textarea[name='position_title[contact_examples_text]']", "One\nTwo\nThree"
    assert_equal original, @role.reload.contact_guidance
    get "/public/v1/officers", headers: @headers
    assert_equal original.fetch(:responsibility), response.parsed_body["officers"].sole["responsibility"]
    patch admin_position_title_path(@role), params: { position_title: { contact_description: "New description", contact_examples_text: "One\nTwo" } }
    assert_redirected_to admin_position_titles_path
    assert_equal [ "One", "Two" ], @role.reload.contact_examples
  end

  test "ordinary members and revoked administrators cannot edit guidance and foreign Post edits are rejected" do
    sign_in_as(@member)
    get edit_admin_position_title_path(@role)
    assert_redirected_to root_path
    original = @role.contact_guidance
    patch admin_position_title_path(@role), params: { position_title: { contact_description: "Unauthorized change", website_officer_listing: false } }
    assert_redirected_to root_path
    assert_equal original, @role.reload.contact_guidance
    assert @role.website_officer_listing?

    sign_in_as(@publisher)
    get edit_admin_position_title_path(@role)
    assert_response :success
    @publisher.permission_grants.where(capability: "manage_settings").destroy_all
    patch admin_position_title_path(@role), params: { position_title: { contact_description: "Revoked change" } }
    assert_redirected_to root_path
    assert_equal original, @role.reload.contact_guidance

    @publisher.permission_grants.create!(capability: "manage_settings")
    other = Organization.create!(name: "Separate Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.position_titles.create!(name: "Historian")
    get edit_admin_position_title_path(foreign)
    assert_response :not_found
    patch admin_position_title_path(foreign), params: { position_title: { contact_description: "Foreign change" } }
    assert_response :not_found
    assert_equal "Preserves the Post's history and archives.", foreign.reload.contact_description
  end

  test "public names follow inclusive Post local dates with turnover duplicates multiple offices and directory exclusions" do
    travel_to Time.utc(2026, 10, 19, 2) do
      @assignment.update!(ends_on: Date.new(2026, 10, 18))
      @role.position_assignments.create!(person: @member.person, starts_on: Date.new(2026, 10, 18), ends_on: Date.new(2026, 10, 18))
      incoming = assign(@role, "Incoming", "Officer", starts_on: Date.new(2026, 10, 19))
      assign(@role, "Ended", "Officer", ends_on: Date.new(2026, 10, 17))
      hidden = assign(@role, "Hidden", "Officer")
      hidden.person.update!(roster_removed_at: Time.current)
      deceased = assign(@role, "Deceased", "Officer")
      deceased.person.update!(roster_member_status: "Deceased")
      second_office = @organization.position_titles.create!(name: "Adjutant", display_order: 3, website_officer_listing: true)
      second_office.position_assignments.create!(person: @member.person, starts_on: Date.new(2020, 1, 1))
      get "/public/v1/officers", headers: @headers
      assert_equal "2026-10-18", response.parsed_body["as_of"]
      assert_equal "America/Chicago", response.parsed_body["timezone"]
      assert_equal [ "Commander", "Adjutant" ], response.parsed_body["officers"].pluck("office")
      assert_equal [ "Synthetic Member", "Synthetic Member" ], response.parsed_body["officers"].pluck("name")
      etag = response.headers.fetch("ETag")

      travel_to Time.utc(2026, 10, 19, 6)
      get "/public/v1/officers", headers: @headers.merge("If-None-Match" => etag)
      assert_response :success
      assert_equal "2026-10-19", response.parsed_body["as_of"]
      assert_equal [ "Incoming Officer", "Synthetic Member" ], response.parsed_body["officers"].pluck("name")
    end
  end

  test "Post scoping public listing removal blank guidance and read-only restrictions apply on subsequent requests" do
    other = Organization.create!(name: "Separate Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    _, secret = WebsiteAccessToken.issue!(organization: other, actor: @publisher, name: "Other website")
    get "/public/v1/officers", headers: { "Authorization" => "Bearer #{secret}" }
    assert_empty response.parsed_body["officers"]
    assert_equal({ "name" => "Separate Post", "email" => nil }, response.parsed_body["post"])

    @role.update!(contact_description: "", contact_examples: [])
    get "/public/v1/officers", headers: @headers
    assert_nil response.parsed_body["officers"].sole["responsibility"]
    etag = response.headers.fetch("ETag")
    sign_in_as(@publisher)
    patch admin_position_title_path(@role), params: { position_title: { website_officer_listing: "0" } }
    assert_not @role.reload.website_officer_listing?
    get "/public/v1/officers", headers: @headers.merge("If-None-Match" => etag)
    assert_response :success
    assert_empty response.parsed_body["officers"]
    get post_contact_path
    assert_select ".post-contact-choice .post-contact-name", "Synthetic Member"
    post "/public/v1/officers", headers: @headers
    assert_response :method_not_allowed
    assert_equal "GET, HEAD", response.headers["Allow"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  private

  def assign(role, first_name, last_name, **dates)
    role.position_assignments.create!(person: Person.create!(first_name: first_name, last_name: last_name),
      starts_on: Date.new(2020, 1, 1), **dates)
  end
end
