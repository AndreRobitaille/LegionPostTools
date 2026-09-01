class AmericanLegionPostPreset
  POSITION_TITLES = [
    { name: "Commander", required: true, membership_access: true, capabilities: %w[manage_agendas approve_minutes] },
    { name: "1st Vice Commander", required: true, membership_access: true, capabilities: [] },
    { name: "2nd Vice Commander", required: true, membership_access: false, capabilities: [] },
    { name: "Adjutant", required: true, membership_access: true, capabilities: %w[manage_agendas manage_minutes attest_minutes] },
    { name: "Finance Officer", required: true, membership_access: false, capabilities: [] },
    { name: "Chaplain", required: true, membership_access: false, capabilities: [] },
    { name: "Sergeant-at-Arms", required: true, membership_access: false, capabilities: [] },
    { name: "Historian", required: false, membership_access: false, capabilities: [] },
    { name: "Service Officer", required: false, membership_access: false, capabilities: [] },
    { name: "Judge Advocate", required: false, membership_access: false, capabilities: [] },
    { name: "Assistant Chaplain", required: false, membership_access: false, capabilities: [] }
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
    POSITION_TITLES.each_with_index do |policy, index|
      position_title = organization.position_titles.find_or_initialize_by(name: policy.fetch(:name))
      position_title.display_order = index + 1
      position_title.required_by_default = policy.fetch(:required)
      position_title.grants_full_membership_access = policy.fetch(:membership_access)
      position_title.save!

      capabilities = policy.fetch(:capabilities)
      position_title.position_capability_grants.where.not(capability: capabilities).destroy_all
      capabilities.each do |capability|
        position_title.position_capability_grants.find_or_create_by!(capability: capability)
      end
    end
  end

  def create_meeting_bodies
    MEETING_BODIES.each do |attributes|
      meeting_body = organization.meeting_bodies.find_or_initialize_by(slug: attributes[:slug])
      meeting_body.name = attributes[:name]
      meeting_body.default_distribution = attributes[:default_distribution]
      meeting_body.save!
    end
  end
end
