require "test_helper"

class AgentOperatorInstructionsTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      timezone: "America/Chicago"
    )
    @person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: @person, email_address: "jane@example.com")
  end

  test "identifies an assigned officer by name and current role" do
    commander = PositionTitle.create!(organization: @organization, name: "Commander", display_order: 1)
    PositionAssignment.create!(person: @person, position_title: commander, starts_on: Organization.current_local_date)

    instructions = AgentOperatorInstructions.new(
      user: @user,
      organization: @organization,
      base_url: "https://members.wipost165.org"
    ).to_s

    assert_includes instructions, "You assist Jane Doe, the Commander of Robert E. Burns Post 165"
    assert_includes instructions, "Routine terminal API"
    assert_includes instructions, "At the start of every working session"
    assert_includes instructions, "authenticated with a Post-owned website token"
    assert_includes instructions, "Neither a browser session nor an agent token proves fresh human intent"
    assert_not_includes instructions, "not built yet"
  end

  test "identifies a person without an assigned office as a post member" do
    instructions = AgentOperatorInstructions.new(
      user: @user,
      organization: @organization,
      base_url: "https://members.wipost165.org"
    ).to_s

    assert_includes instructions, "You assist Jane Doe, a member of Robert E. Burns Post 165"
    assert_not_includes instructions, "officer"
  end

  test "standing maintainer brief matches generated website credential and unavailable-operation guidance" do
    standing = Rails.root.join("docs/agent-operator-skill.md").read
    assert_includes standing, "website token"
    assert_not_includes standing, "approved anonymous"
    assert_includes standing, "HEAD and conditional reads"
    assert_includes standing, "Minutes reopening and recording membership approval currently use the signed-in website"
    assert_includes standing, "later amendments are not implemented"
    assert_includes standing, "Do not guess API routes"
  end
end
