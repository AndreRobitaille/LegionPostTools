require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_officer
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end

  def sign_in_plain_member
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)
  end

  test "officer index lists members with membership status column" do
    prepare_setup_complete_state
    sign_in_officer
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_member_status: "Active")
    get people_path
    assert_response :success
    assert_select "h1", "People"
    assert_select ".mrow-name", text: /Alber/
    assert_select ".mrow-status .st"
  end

  test "member index omits the membership status column" do
    prepare_setup_complete_state
    sign_in_plain_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_member_status: "Active")
    get people_path
    assert_response :success
    assert_select ".mrow-name", text: /Alber/
    assert_select ".mrow-status", count: 0
  end

  test "officer index search filters by name" do
    prepare_setup_complete_state
    sign_in_officer
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "1", roster_name: "Alber, Vincent")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "2", roster_name: "Roe, Jane")
    get people_path, params: { q: "Vincent" }
    assert_select ".mrow-name", text: /Alber/
    assert_select ".mrow-name", text: /Roe, Jane/, count: 0
  end

  test "officer index sorts by member number when requested" do
    prepare_setup_complete_state
    sign_in_officer
    Person.create!(first_name: "Zed", last_name: "Zephyr", member_number: "001")
    Person.create!(first_name: "Amy", last_name: "Adams", member_number: "002")
    get people_path, params: { sort: "member_id" }
    assert_response :success
    names = css_select(".mrow-name").map(&:text)
    zephyr_index = names.index { |n| n.include?("Zephyr") }
    adams_index = names.index { |n| n.include?("Adams") }
    assert_operator zephyr_index, :<, adams_index
  end

  test "officer index sorts by paid-through year descending when requested" do
    prepare_setup_complete_state
    sign_in_officer
    Person.create!(first_name: "Amy", last_name: "Adams", member_number: "1", roster_paid_through_year: 2024)
    Person.create!(first_name: "Zed", last_name: "Zephyr", member_number: "2", roster_paid_through_year: 2027)
    get people_path, params: { sort: "paid_through" }
    assert_response :success
    names = css_select(".mrow-name").map(&:text)
    zephyr_index = names.index { |n| n.include?("Zephyr") }
    adams_index = names.index { |n| n.include?("Adams") }
    assert_operator zephyr_index, :<, adams_index
  end

  test "officer index filters by member status, paid year, and sign-in" do
    prepare_setup_complete_state
    sign_in_officer
    active = Person.create!(first_name: "A", last_name: "One", member_number: "1", roster_member_status: "Active", roster_paid_through_year: 2027)
    Person.create!(first_name: "B", last_name: "Two", member_number: "2", roster_member_status: "Expired", roster_paid_through_year: 2024)
    get people_path, params: { roster_member_status: "Active" }
    assert_select ".mrow-name", text: /One/
    assert_select ".mrow-name", text: /Two/, count: 0
    get people_path, params: { roster_paid_through_year: 2027 }
    assert_select ".mrow-name", text: /One/
    assert_select ".mrow-name", text: /Two/, count: 0
    User.create!(person: active, email_address: "a@example.com", email_verified_at: Time.current)
    get people_path, params: { login_status: "no_login" }
    assert_select ".mrow-name", text: /Two/
    assert_select ".mrow-name", text: /One/, count: 0
  end
end
