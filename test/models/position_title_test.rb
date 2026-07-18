require "test_helper"

class PositionTitleTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    @b = PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2)
    @c = PositionTitle.create!(organization: @org, name: "Chaplain", display_order: 3)
  end

  test "reorder! rewrites display_order to the given 1-based sequence" do
    PositionTitle.reorder!(@org, [@c.id, @a.id, @b.id])

    assert_equal 1, @c.reload.display_order
    assert_equal 2, @a.reload.display_order
    assert_equal 3, @b.reload.display_order
  end

  test "reorder! rejects ids outside the organization and changes nothing" do
    other_org = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = PositionTitle.create!(organization: other_org, name: "Historian", display_order: 1)

    assert_raises(ActiveRecord::RecordNotFound) do
      PositionTitle.reorder!(@org, [@a.id, foreign.id, @b.id])
    end

    assert_equal 1, @a.reload.display_order
    assert_equal 2, @b.reload.display_order
    assert_equal 3, @c.reload.display_order
  end

  test "reorder! rejects duplicate ids" do
    assert_raises(ActiveRecord::RecordNotFound) do
      PositionTitle.reorder!(@org, [@a.id, @a.id, @b.id])
    end
  end
end
