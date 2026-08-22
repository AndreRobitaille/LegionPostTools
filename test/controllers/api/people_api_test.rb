require "test_helper"

class ApiPeopleApiTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      locality: "Two Rivers, Wisconsin",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @member = create_user("Standard", "Member")
    @membership_officer = create_user("Current", "Leader")
    @membership_title = PositionTitle.create!(
      organization: @organization,
      name: "Membership Leadership",
      display_order: 1,
      grants_full_membership_access: true
    )
    @membership_assignment = PositionAssignment.create!(
      person: @membership_officer.person,
      position_title: @membership_title,
      starts_on: Date.current - 1
    )
  end

  test "unauthenticated directory request is private" do
    get "/api/people", as: :json

    assert_response :unauthorized
    assert_equal "This is a private post operations app. Sign in, then open /api.", response.parsed_body["error"]
  end

  test "standard member receives a bulk directory without roster or login fields" do
    directory_person = Person.create!(
      first_name: "Jane", last_name: "Smith", member_number: "000000000001",
      email_address: "directory@example.com", roster_email_address: "roster@example.com",
      phone_number: "555-1000", roster_phone_number: "555-2000",
      roster_member_status: "Active", roster_paid_through_year: 2027,
      roster_address: "123 Private Street"
    )
    User.create!(person: directory_person, email_address: "login-secret@example.com")
    PositionAssignment.create!(person: directory_person, position_title: @membership_title, starts_on: Date.current)
    Person.create!(first_name: "Former", last_name: "Member", member_number: "000000000002", roster_member_status: "Expired")
    sign_in_as(@member)

    get "/api/people", as: :json

    assert_response :success
    body = response.parsed_body
    row = body.fetch("people").find { |person| person["id"] == directory_person.id }
    assert_equal "directory@example.com", row["email_address"]
    assert_equal "555-1000", row["phone_number"]
    assert_equal [ "Membership Leadership" ], row["roles"]
    assert_nil row["member_number"]
    assert_nil row["paid_through_year"]
    assert_not_includes response.body, "123 Private Street"
    assert_not_includes response.body, "login-secret@example.com"
    assert_not_includes response.body, "Former Member"
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal body["people"].size, body["returned_count"]
    assert_not body["truncated"]
  end

  test "directory name search does not match hidden member numbers" do
    person = Person.create!(
      first_name: "Vincent", last_name: "Alber", member_number: "000204540637",
      roster_member_status: "Active"
    )
    sign_in_as(@member)

    get "/api/people", params: { q: "Vincent" }, as: :json
    assert_includes response.parsed_body.fetch("people").pluck("id"), person.id

    get "/api/people", params: { q: "000204540637" }, as: :json
    assert_not_includes response.parsed_body.fetch("people").pluck("id"), person.id
  end

  test "standard member cannot show an expired or removed person by id" do
    expired = roster_person("Expired", status: "Expired", paid_through: 2025)
    removed = roster_person("Removed", status: "Active", paid_through: 2027, removed: true)
    sign_in_as(@member)

    get "/api/people/#{expired.id}", as: :json
    assert_response :not_found

    get "/api/people/#{removed.id}", as: :json
    assert_response :not_found
  end

  test "officer directory lists current assignments and filters exact role names" do
    commander_title = PositionTitle.create!(organization: @organization, name: "Commander", display_order: 2)
    commander = roster_person("Alex", status: "Active", paid_through: 2027)
    PositionAssignment.create!(person: commander, position_title: commander_title, starts_on: Date.current)
    former = roster_person("Former", status: "Active", paid_through: 2027)
    PositionAssignment.create!(
      person: former, position_title: commander_title,
      starts_on: Date.current - 2.years, ends_on: Date.current - 1.year
    )
    sign_in_as(@member)

    get "/api/officers", params: { role: "commander" }, as: :json

    assert_response :success
    ids = response.parsed_body.fetch("people").pluck("id")
    assert_includes ids, commander.id
    assert_not_includes ids, former.id
    assert_equal Date.current.iso8601, response.parsed_body["as_of"]
  end

  test "standard member and past officer are forbidden from membership information" do
    past = create_user("Past", "Commander")
    PositionAssignment.create!(
      person: past.person,
      position_title: @membership_title,
      starts_on: Date.current - 2.years,
      ends_on: Date.current - 1.year
    )

    [ @member, past ].each do |user|
      sign_in_as(user)
      get "/api/membership/summary", params: { membership_year: 2027 }, as: :json
      assert_response :forbidden
    end
  end

  test "current membership officer receives summary renewal worklist and full roster" do
    due = roster_person("Due", status: "Active", paid_through: 2026)
    paid = roster_person("Paid", status: "Active", paid_through: 2027)
    pufl = roster_person("Life", status: "Active", paid_through: 2026, type: "Paid Up For Life")
    lapsed = roster_person("Lapsed", status: "Expired", paid_through: 2025)
    removed = roster_person("Removed", status: "Active", paid_through: 2027, removed: true)
    RosterImport.create!(status: "completed", imported_at: 1.day.ago, uploaded_filename: "roster.csv")
    sign_in_as(@membership_officer)

    get "/api/membership/summary", params: { membership_year: 2027 }, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body.dig("counts", "needs_renewal")
    assert_equal 1, response.parsed_body.dig("counts", "paid_for_year")
    assert_equal 1, response.parsed_body.dig("counts", "paid_up_for_life")
    assert_equal 1, response.parsed_body.dig("counts", "lapsed")
    assert_equal 1, response.parsed_body.dig("counts", "removed")
    assert_not response.parsed_body.dig("roster_source", "stale")

    get "/api/membership/renewals", params: { membership_year: 2027 }, as: :json
    worklist_ids = response.parsed_body.fetch("people").pluck("id")
    assert_includes worklist_ids, due.id
    assert_includes worklist_ids, lapsed.id
    assert_not_includes worklist_ids, paid.id
    assert_not_includes worklist_ids, pufl.id
    assert_not_includes worklist_ids, removed.id

    get "/api/membership/roster", params: { membership_year: 2027 }, as: :json
    assert_response :success
    roster_ids = response.parsed_body.fetch("people").pluck("id")
    assert_includes roster_ids, removed.id
    due_payload = response.parsed_body.fetch("people").find { |person| person["id"] == due.id }
    assert_equal "needs_renewal", due_payload["renewal_state"]
    assert due_payload.key?("member_number")
    assert due_payload.key?("mailing_address")
    assert_not_includes response.body, @membership_officer.email_address
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "membership person never exposes login state grants or notes" do
    person = roster_person("Private", status: "Active", paid_through: 2026)
    person.update!(notes: "Do not expose this note")
    user = User.create!(person: person, email_address: "login-only@example.com", disabled_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(@membership_officer)

    get "/api/membership/people/#{person.id}", params: { membership_year: 2027 }, as: :json

    assert_response :success
    payload = response.parsed_body.fetch("person")
    assert_equal person.member_number, payload["member_number"]
    assert_nil payload["login_state"]
    assert_not_includes response.body, "login-only@example.com"
    assert_not_includes response.body, "manage_settings"
    assert_not_includes response.body, "Do not expose this note"
  end

  test "membership endpoints validate year state limit and offset" do
    sign_in_as(@membership_officer)

    get "/api/membership/summary", as: :json
    assert_response :unprocessable_entity
    assert_match(/four-digit year/, response.parsed_body["error"])

    get "/api/membership/renewals", params: { membership_year: 2027, state: "anything" }, as: :json
    assert_response :unprocessable_entity
    assert_match(/state must be one of/, response.parsed_body["error"])

    get "/api/membership/roster", params: { membership_year: 2027, limit: 501 }, as: :json
    assert_response :unprocessable_entity
    assert_match(/limit must be between/, response.parsed_body["error"])

    get "/api/people", params: { offset: -1 }, as: :json
    assert_response :unprocessable_entity
    assert_match(/offset must be zero/, response.parsed_body["error"])
  end

  test "bearer membership authority changes immediately when the assignment ends" do
    _token, plaintext = AgentAccessToken.issue!(user: @membership_officer, name: "Agent", expires_in: 30.days)
    headers = { "Authorization" => "Bearer #{plaintext}" }

    get "/api/membership/summary", params: { membership_year: 2027 }, as: :json, headers: headers
    assert_response :success

    @membership_assignment.update!(ends_on: Date.current - 1)
    get "/api/membership/summary", params: { membership_year: 2027 }, as: :json, headers: headers
    assert_response :forbidden
  end

  private

  def create_user(first_name, last_name)
    person = Person.create!(first_name: first_name, last_name: last_name)
    User.create!(
      person: person,
      email_address: "#{first_name.downcase}-#{last_name.downcase}-#{SecureRandom.hex(3)}@example.com",
      email_verified_at: Time.current
    )
  end

  def roster_person(label, status:, paid_through:, type: "Member", removed: false)
    Person.create!(
      first_name: label,
      last_name: "Member",
      member_number: SecureRandom.random_number(10**12).to_s.rjust(12, "0"),
      roster_member_status: status,
      roster_membership_type: type,
      roster_paid_through_year: paid_through,
      roster_email_address: "#{label.downcase}@roster.example.com",
      roster_phone_number: "555-1212",
      roster_address: "123 #{label} Street",
      roster_imported_at: Time.current,
      roster_removed_at: (Time.current if removed)
    )
  end
end
