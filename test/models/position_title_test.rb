require "test_helper"

class PositionTitleTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    @b = PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2)
    @c = PositionTitle.create!(organization: @org, name: "Chaplain", display_order: 3)
  end

  test "reorder! rewrites display_order to the given 1-based sequence" do
    PositionTitle.reorder!(@org, [ @c.id, @a.id, @b.id ])

    assert_equal 1, @c.reload.display_order
    assert_equal 2, @a.reload.display_order
    assert_equal 3, @b.reload.display_order
  end

  test "reorder! rejects ids outside the organization and changes nothing" do
    other_org = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = PositionTitle.create!(organization: other_org, name: "Historian", display_order: 1)

    assert_raises(ActiveRecord::RecordNotFound) do
      PositionTitle.reorder!(@org, [ @a.id, foreign.id, @b.id ])
    end

    assert_equal 1, @a.reload.display_order
    assert_equal 2, @b.reload.display_order
    assert_equal 3, @c.reload.display_order
  end

  test "reorder! rejects duplicate ids" do
    assert_raises(ActiveRecord::RecordNotFound) do
      PositionTitle.reorder!(@org, [ @a.id, @a.id, @b.id ])
    end
  end

  test "approved guidance is saved initially and survives renaming and preset reuse" do
    original = @a.contact_guidance
    assert_equal "You want to raise an issue at a Post meeting.", @a.reload.contact_examples.last
    @a.update!(name: "Post Commander", contact_description: "Helps members raise Post concerns.",
      contact_examples_text: "You have a concern.\n\nYou want to discuss an idea.")
    @a.reload
    assert_equal "Helps members raise Post concerns.", @a.contact_description
    assert_equal [ "You have a concern.", "You want to discuss an idea." ], @a.contact_examples
    assert_not_equal original, @a.contact_guidance

    @b.update!(contact_description: "Maintains our Post's records.", contact_examples: [ "You need a membership card." ])
    AmericanLegionPostPreset.apply_to(@org)
    assert_equal "Maintains our Post's records.", @b.reload.contact_description
    assert_equal [ "You need a membership card." ], @b.contact_examples
    assert @org.position_titles.find_by!(name: "Service Officer").website_officer_listing?
    assert_not @b.website_officer_listing?
    assert_nil @org.position_titles.create!(name: "Custom role").contact_guidance
  end

  test "assistant guidance is saved as only assistance including after a rename" do
    role = @org.position_titles.create!(name: "Assistant Chaplain", contact_description: "Extra duties", contact_examples: [ "Extra example" ])
    assert_equal({ responsibility: "Assists the Chaplain.", examples: [] }, role.reload.contact_guidance)
    role.update!(name: "Assistant Adjutant", contact_examples_text: "Extra example")
    assert_equal({ responsibility: "Assists the Adjutant.", examples: [] }, role.reload.contact_guidance)
  end

  test "guidance accepts bounded plain text and can be cleared without reseeding" do
    [ nil, {}, [ nil ], [ "" ], [ "x" * 301 ], [ "One", "Two", "Three" ] ].each do |examples|
      @a.contact_examples = examples
      assert_not @a.valid?, "Accepted malformed examples: #{examples.inspect}"
    end
    @a.assign_attributes(contact_description: "", contact_examples: [ "An example" ])
    assert_not @a.valid?
    @a.assign_attributes(contact_description: "x" * 1001, contact_examples: [])
    assert_not @a.valid?
    @a.update!(contact_description: "", contact_examples_text: nil)
    assert_nil @a.reload.contact_guidance
    @a.update!(active: false)
    assert_nil @a.reload.contact_guidance
  end
end
