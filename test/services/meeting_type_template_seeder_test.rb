require "test_helper"

class MeetingTypeTemplateSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(@organization)
  end

  test "seeds default meeting types" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal [ "PEC Meeting", "Membership Meeting" ], @organization.meeting_types.ordered.pluck(:name)
    assert @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").seeded?
    assert @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting").seeded?
  end

  test "seeds membership meeting with ceremony and reports" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    titles = membership.meeting_type_agenda_items.ordered.pluck(:title)

    assert_includes titles, "Opening Ceremony"
    assert_includes titles, "Committee Reports"
    assert_includes titles, "Closing Ceremony"
  end

  test "seeds pec meeting without ceremony or officer reports" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    titles = pec.meeting_type_agenda_items.ordered.pluck(:title)

    assert_includes titles, "Roll Call and Quorum"
    assert_includes titles, "Previous Meeting Minutes"
    assert_includes titles, "Unfinished / Old Business"
    assert_includes titles, "New Business and Correspondence"
    assert_not_includes titles, "Opening Ceremony"
    assert_not_includes titles, "Closing Ceremony"
    assert_not_includes titles, "Committee Reports"
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

  test "seeding is independent by organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(other_organization)

    MeetingTypeTemplateSeeder.seed_for!(@organization)
    MeetingTypeTemplateSeeder.seed_for!(other_organization)

    assert_equal 2, @organization.meeting_types.count
    assert_equal 2, other_organization.meeting_types.count
  end
end
