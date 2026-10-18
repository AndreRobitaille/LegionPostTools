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
    @primary_contacts = PostContactGuidance::PRIMARY_CONTACTS.map do |office, guidance|
      { office:, guidance:, assignments: @officer_assignments.select { |assignment| assignment.position_title.name == office } }
    end
    @other_officer_assignments = @officer_assignments.reject do |assignment|
      PostContactGuidance::PRIMARY_CONTACTS.key?(assignment.position_title.name)
    end
  end
end
