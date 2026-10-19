class PostContactsController < ApplicationController
  before_action :require_authentication

  def show
    response.headers["Cache-Control"] = "no-store"
    @organization = Organization.first!
    today = @organization.calendar_time_zone.today
    @officer_assignments = PositionAssignment
      .joins(:person, :position_title)
      .merge(Person.directory_visible)
      .merge(@organization.position_titles.where(active: true))
      .where("starts_on <= :today AND (ends_on IS NULL OR ends_on >= :today)", today:)
      .includes(:person, :position_title)
      .order("position_titles.display_order", "position_titles.name", "people.last_name", "people.first_name", :id)
      .to_a.uniq { |assignment| [ assignment.position_title_id, assignment.person_id ] }
    titles = @organization.position_titles.where(active: true, name: PostContactGuidance::PRIMARY_OFFICES).index_by(&:name)
    @primary_contacts = PostContactGuidance::PRIMARY_OFFICES.map do |office|
      { office:, guidance: titles[office]&.contact_guidance, assignments: @officer_assignments.select { |assignment| assignment.position_title.name == office } }
    end
    @other_officer_assignments = @officer_assignments.reject do |assignment|
      PostContactGuidance::PRIMARY_OFFICES.include?(assignment.position_title.name)
    end
  end
end
