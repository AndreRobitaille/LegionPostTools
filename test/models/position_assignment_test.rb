require "test_helper"

class PositionAssignmentTest < ActiveSupport::TestCase
  test "active_on? includes no-end-date assignments" do
    assignment = PositionAssignment.new(starts_on: Date.new(2024, 1, 1), ends_on: nil)

    assert assignment.active_on?(Date.new(2024, 6, 1))
  end

  test "active_on? excludes after end date" do
    assignment = PositionAssignment.new(starts_on: Date.new(2024, 1, 1), ends_on: Date.new(2024, 6, 1))

    assert_not assignment.active_on?(Date.new(2024, 6, 2))
  end
end
