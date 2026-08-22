module Api
  class OfficersController < BaseController
    before_action :prevent_private_data_caching

    def index
      today = Date.current
      scope = Person.directory_visible
        .joins(position_assignments: :position_title)
        .includes(position_assignments: :position_title)
        .where("position_assignments.starts_on <= ?", today)
        .where("position_assignments.ends_on IS NULL OR position_assignments.ends_on >= ?", today)
      scope = scope.where("LOWER(position_titles.name) = ?", params[:role].to_s.strip.downcase) if params[:role].present?
      scope = scope.distinct.order(:last_name, :first_name, :id)
      page = collection_page(scope)
      return if performed?

      render json: page[:metadata].merge(as_of: today.iso8601, people: page[:records].map { |person| directory_person_payload(person) })
    end
  end
end
