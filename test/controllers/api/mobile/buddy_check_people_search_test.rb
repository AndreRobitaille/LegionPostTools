require "test_helper"
require_relative "../../../support/buddy_checks_helpers"

class MobileBuddyCheckPeopleSearchTest < ActionDispatch::IntegrationTest
  include BuddyChecksHelpers

  BASE = "/api/mobile/v1/buddy-checks/people"

  setup do
    setup_buddy_checks
    @member.update!(first_name: "Tobin", last_name: "Alderwick")
    @unassigned.update!(first_name: "Maris", last_name: "Brookvale")
    @headers = mobile_headers
  end

  teardown { restore_buddy_configuration }

  test "partial and complete names span fields case insensitively" do
    [ "Tobin", "alder", "tob ald", "TOBIN ALDERWICK", "Alderwick tobin" ].each do |query|
      assert_search query, [ @member ]
    end
  end

  test "leading trailing and repeated whitespace is normalized" do
    [ "  tobin alderwick  ", "tobin   alderwick", "\tTobin\n Alderwick\r", " " * 80 + "Tobin" + " " * 80 ].each do |query|
      assert_search query, [ @member ]
    end
  end

  test "names with multiple words are searchable across both fields" do
    @member.update!(first_name: "Tobin Elias", last_name: "Alderwick North")
    assert_search "eli ald north", [ @member ]
  end

  test "one insertion deletion substitution or adjacent transposition is tolerated" do
    [ "tobin alderwicck", "tobin alderwik", "tobin aldarwick", "TOBIN ADLERWICK", "tobyn alderwick",
      "xtobin alderwick", "tobin alderwickx", "tobin lderwick" ].each do |query|
      assert_search query, [ @member ]
    end
  end

  test "multiple edits and misspelled partial words do not expand search" do
    [ "tobyn aldarwick", "tobin aldxrwixk", "tobin aldarw", "tobin xylophone" ].each do |query|
      assert_search query, []
    end
  end

  test "short names support literal matches without typo expansion" do
    @member.update!(first_name: "Al", last_name: "Li")
    assert_search "al li", [ @member ]
    assert_search "LI", [ @member ]
    assert_search "ai li", []
    assert_search "al lj", []
    @member.update!(first_name: "Ian")
    assert_search "iann li", []
    @member.update!(first_name: "Nora")
    assert_search "nra li", []
    assert_search "nira li", [ @member ]
  end

  test "ordinary matches suppress typo candidates even after their final cursor" do
    @unassigned.update!(first_name: "Tobin", last_name: "Aldarwick")
    assert_search "tobin alderwick", [ @member ]
    assert_search "tobin aldarwick", [ @unassigned ]
    assert_search "tobin alderwick", [], cursor: @member.id, limit: 1
    assert_nil response.parsed_body["next_cursor"]
  end

  test "ordinary and typo searches use bounded deterministic ID pagination" do
    people = 52.times.map { |index| Person.create!(first_name: "Pageford", last_name: "Example#{index}") }
    [ "Pageford", "Pagefrod" ].each do |query|
      assert_search query, people.first(25)
      assert_equal people[24].id.to_s, response.parsed_body["next_cursor"]
      assert_search query, people.first(50), limit: 50
      cursor = response.parsed_body["next_cursor"]
      assert_equal people[49].id.to_s, cursor
      assert_search query, people.last(2), limit: 50, cursor: cursor
      assert_nil response.parsed_body["next_cursor"]
      assert_search query, [], cursor: people.last.id
      assert_nil response.parsed_body["next_cursor"]
    end
  end

  test "wildcards backslashes regex and SQL syntax are literal input" do
    @unassigned.update!(first_name: "Percent%Mark", last_name: "Under_score\\Trail")
    [ "t%M", "r_s", "e\\T" ].each { |query| assert_search query, [ @unassigned ] }
    [ "%%", "__", "\\\\", "[a-z]", "(.*|Tobin)", "Tobin' OR 1=1 --", "Alderw.ck" ].each do |query|
      assert_search query, []
    end
    @unassigned.update!(first_name: "Regex[ab].*", last_name: "Literal")
    assert_search "[ab].*", [ @unassigned ]
    assert_search ".*", [ @unassigned ]
  end

  test "no results and invalid normalized query lengths preserve the contract" do
    assert_search "Nobody Zyxwvuts", []
    assert_nil response.parsed_body["next_cursor"]
    [ nil, "", " \t\n ", "x", "a" * 81 ].each do |query|
      get BASE, params: { q: query }, headers: @headers
      assert_response :unprocessable_entity
      assert_equal "invalid_request", response.parsed_body.dig("error", "code")
    end
    assert_search "To", [ @member ]
    @unassigned.update!(first_name: "a" * 80)
    assert_search "a" * 80, [ @unassigned ]
  end

  test "invalid pagination is rejected for ordinary and typo searches" do
    [ "Tobin", "Tobyn" ].each do |query|
      [ { limit: 0 }, { limit: 51 }, { limit: "bad" }, { cursor: -1 }, { cursor: "bad" } ].each do |pagination|
        get BASE, params: { q: query }.merge(pagination), headers: @headers
        assert_response :unprocessable_entity
        assert_equal "invalid_request", response.parsed_body.dig("error", "code")
      end
    end
  end

  test "directory loss and restoration affect both search paths using the same token" do
    assert_member_searches [ @member ]
    @member.update!(roster_member_status: "Expired")
    assert_member_searches []
    @member.update!(roster_member_status: "Active")
    assert_member_searches [ @member ]
  end

  test "an inaccessible ordinary match cannot suppress a permitted typo match" do
    @unassigned.update!(first_name: "Tobin", last_name: "Adlerwick", roster_member_status: "Expired")
    assert_search "Tobin Adlerwick", [ @member ]
  end

  test "only own current Buddy Check assignments supplement directory access" do
    @member.update!(roster_member_status: "Expired")
    @drive.update!(purpose: "buddy_check")
    assert_member_searches []
    @headers = mobile_headers(@officer)
    assert_member_searches []
    @headers = mobile_headers(@volunteer)
    assert_member_searches [ @member ]
    @drive.update!(purpose: "renewal")
    assert_member_searches []
    @drive.update!(purpose: "buddy_check")
    assert_member_searches [ @member ]
  end

  test "assignment closure revocation expiry and future start remove search access immediately" do
    @member.update!(roster_member_status: "Expired")
    @drive.update!(purpose: "buddy_check")
    @headers = mobile_headers(@volunteer)
    assert_member_searches [ @member ]
    @drive.update!(closed_at: Time.current)
    assert_member_searches []
    @drive.update!(closed_at: nil)
    assert_member_searches [ @member ]
    @assignment.update!(revoked_at: Time.current)
    assert_member_searches []
    @assignment.update!(revoked_at: nil, expires_on: Organization.current_local_date)
    assert_member_searches [ @member ]
    @assignment.update!(expires_on: Organization.current_local_date - 1)
    assert_member_searches []
    @assignment.update!(expires_on: @drive.ends_on)
    @drive.update!(starts_on: Organization.current_local_date + 1)
    assert_member_searches []
    @drive.update!(starts_on: Organization.current_local_date)
    assert_member_searches [ @member ]
  end

  test "removed and deceased people remain absent even with an own assignment" do
    @drive.update!(purpose: "buddy_check")
    @headers = mobile_headers(@volunteer)
    assert_member_searches [ @member ]
    @member.update!(roster_removed_at: Time.current)
    assert_member_searches []
    @member.update!(roster_removed_at: nil, roster_member_status: "  DeCeAsEd  ")
    assert_member_searches []
  end

  test "current mobile grant and enabled account are enforced on every search" do
    assert_member_searches [ @member ]
    @other.permission_grants.find_by!(capability: "use_mobile_buddy_checks").destroy!
    assert_denied_searches :forbidden
    @other.permission_grants.create!(capability: "use_mobile_buddy_checks")
    assert_member_searches [ @member ]
    @other.update!(disabled_at: Time.current)
    assert_denied_searches :unauthorized
  end

  test "repeated searches project only identity and leave persisted records unchanged" do
    @member.update!(roster_address: "Synthetic private address", member_number: "SYNTHETIC PRIVATE NUMBER")
    people_before = Person.order(:id).map(&:attributes)
    models = [ MembershipContact, MembershipAssignment, BuddyFollowUp, BuddySnooze, BuddyOperation ]
    counts_before = models.map(&:count)
    2.times { assert_member_searches [ @member ] }
    assert_equal people_before, Person.order(:id).map(&:attributes)
    assert_equal counts_before, models.map(&:count)
    get "#{BASE}/#{@member.id}", headers: @headers
    assert_response :success
    assert_equal "Tobin", response.parsed_body["first_name"]
    assert response.parsed_body.dig("eligibility", "eligible")
  end

  private

  def assert_search(query, people, **pagination)
    get BASE, params: { q: query }.merge(pagination), headers: @headers
    assert_response :success
    assert_equal people.map { |person| { "id" => person.id, "first_name" => person.first_name, "last_name" => person.last_name } },
      response.parsed_body["items"], "Search: #{query.inspect} #{pagination.inspect}"
    assert_equal %w[items next_cursor], response.parsed_body.keys.sort
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  def assert_member_searches(people)
    [ "Tobin Alderwick", "Tobin Adlerwick" ].each { |query| assert_search query, people }
  end

  def assert_denied_searches(status)
    [ "Tobin Alderwick", "Tobin Adlerwick" ].each do |query|
      get BASE, params: { q: query }, headers: @headers
      assert_response status
      assert_equal({ "error" => { "code" => "account_unavailable" } }, response.parsed_body)
    end
  end
end
