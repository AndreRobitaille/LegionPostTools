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
    PositionAssignment.create!(person: @person, position_title: commander, starts_on: Date.current)

    instructions = AgentOperatorInstructions.new(
      user: @user,
      organization: @organization,
      base_url: "https://members.wipost165.org"
    ).to_s

    assert_includes instructions, "You assist Jane Doe, the Commander of Robert E. Burns Post 165"
    assert_includes instructions, "Routine terminal API"
    assert_includes instructions, "At the start of every working session"
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
end
