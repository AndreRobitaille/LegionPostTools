class AmericanLegionPostPreset
  POSITION_TITLES = [
    ["Commander", true],
    ["1st Vice Commander", true],
    ["2nd Vice Commander", true],
    ["Adjutant", true],
    ["Finance Officer", true],
    ["Chaplain", true],
    ["Sergeant-at-Arms", true],
    ["Historian", false],
    ["Service Officer", false],
    ["Judge Advocate", false],
    ["Assistant Chaplain", false]
  ].freeze

  MEETING_BODIES = [
    { name: "Post Executive Committee", slug: "pec", default_distribution: "print" },
    { name: "Membership Meeting", slug: "membership", default_distribution: "email" }
  ].freeze

  def self.apply_to(organization)
    new(organization).apply
  end

  def initialize(organization)
    @organization = organization
  end

  def apply
    ApplicationRecord.transaction do
      create_position_titles
      create_meeting_bodies
    end
  end

  private

  attr_reader :organization

  def create_position_titles
    POSITION_TITLES.each_with_index do |(name, required_by_default), index|
      organization.position_titles.find_or_create_by!(name: name) do |position_title|
        position_title.display_order = index + 1
        position_title.required_by_default = required_by_default
      end
    end
  end

  def create_meeting_bodies
    MEETING_BODIES.each do |attributes|
      organization.meeting_bodies.find_or_create_by!(slug: attributes[:slug]) do |meeting_body|
        meeting_body.name = attributes[:name]
        meeting_body.default_distribution = attributes[:default_distribution]
      end
    end
  end
end
