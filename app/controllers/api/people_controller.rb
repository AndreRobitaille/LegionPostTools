module Api
  class PeopleController < BaseController
    before_action :prevent_private_data_caching

    def index
      scope = Person.directory_visible.includes(position_assignments: :position_title).order(:last_name, :first_name, :id)
      scope = apply_name_search(scope) if params[:q].present?
      page = collection_page(scope)
      return if performed?

      render json: page[:metadata].merge(people: page[:records].map { |person| directory_person_payload(person) })
    end

    def show
      person = Person.directory_visible.includes(position_assignments: :position_title).find(params[:id])
      render json: { person: directory_person_payload(person) }
    end

    private

    def apply_name_search(scope)
      query = "%#{params[:q].to_s.strip}%"
      scope.where("first_name ILIKE :query OR last_name ILIKE :query OR roster_name ILIKE :query", query: query)
    end
  end
end
