require "test_helper"

class MeetingTypeTemplateSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(@organization)
  end

  test "seeds default meeting types for an unseeded organization" do
    organization = Organization.create!(name: "Fresh Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { organization.agenda_item_catalog_entries.count }, 17 do
      assert_difference -> { organization.meeting_types.count }, 2 do
        MeetingTypeTemplateSeeder.seed_for!(organization)
      end
    end

    assert_equal [ "PEC Meeting", "Membership Meeting" ], organization.meeting_types.ordered.pluck(:name)
    assert_equal 17, organization.agenda_item_catalog_entries.count
    assert_equal 2, organization.meeting_types.count
    assert organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").seeded?
    assert organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting").seeded?
  end

  test "seeds membership meeting with exact ordered titles" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    titles = membership.meeting_type_agenda_items.ordered.pluck(:title)

    assert_equal [
      "Opening Ceremony",
      "Opening Prayer",
      "POW/MIA Empty Chair",
      "Pledge of Allegiance",
      "American Legion Preamble",
      "Roll Call and Quorum",
      "Previous Meeting Minutes",
      "Introduction of Guests and Prospective/New Members",
      "Committee Reports",
      "Balloting on Applications",
      "Sick Call, Relief, and Employment",
      "Post Service Officer Report",
      "Unfinished / Old Business",
      "New Business and Correspondence",
      "Memorial to a Departed Post Member",
      "Good of The American Legion",
      "Closing Ceremony"
    ], titles
  end

  test "seeds pec meeting with exact ordered titles" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    titles = pec.meeting_type_agenda_items.ordered.pluck(:title)

    assert_equal [
      "Roll Call and Quorum",
      "Previous Meeting Minutes",
      "Unfinished / Old Business",
      "New Business and Correspondence",
      "Good of The American Legion"
    ], titles
  end

  test "reseeding does not overwrite local edits" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    item = membership.meeting_type_agenda_items.ordered.first

    membership.update!(name: "Local Membership Meeting", active: false)
    item.update!(title: "Local Template Item", summary: "Local summary", body: "Local body", position: 99, active: false)

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal "Local Membership Meeting", membership.reload.name
    assert_not membership.active?
    assert_equal "Local Template Item", item.reload.title
    assert_equal "Local summary", item.summary
    assert_equal "Local body", item.body.to_plain_text
    assert_equal 99, item.position
    assert_not item.active?
  end

  test "reseeding does not change meeting type or template item counts" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_no_difference -> { @organization.meeting_types.count } do
      assert_no_difference -> { @organization.meeting_types.sum { |meeting_type| meeting_type.meeting_type_agenda_items.count } } do
        MeetingTypeTemplateSeeder.seed_for!(@organization)
      end
    end
  end

  test "seeding is independent by organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(other_organization)

    MeetingTypeTemplateSeeder.seed_for!(@organization)
    MeetingTypeTemplateSeeder.seed_for!(other_organization)

    assert_equal 2, @organization.meeting_types.count
    assert_equal 2, other_organization.meeting_types.count
  end
end
