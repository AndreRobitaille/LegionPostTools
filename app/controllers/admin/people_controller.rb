module Admin
  class PeopleController < BaseController
    def index
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?

      @people = Person.left_outer_joins(:user).includes(:user).order(:last_name, :first_name)
      @people = @people.where(
        "first_name ILIKE :q OR last_name ILIKE :q OR roster_name ILIKE :q OR member_number ILIKE :q",
        q: "%#{params[:q]}%"
      ) if params[:q].present?
      @people = @people.where(roster_member_status: params[:roster_member_status]) if params[:roster_member_status].present?
      @people = @people.where(roster_paid_through_year: params[:roster_paid_through_year]) if params[:roster_paid_through_year].present?
      @people = @people.where(roster_branch: params[:roster_branch]) if params[:roster_branch].present?
      case params[:login_status]
      when "enabled"
        @people = @people.where.not(users: { id: nil }).where(users: { disabled_at: nil })
      when "disabled"
        @people = @people.where.not(users: { id: nil }).where.not(users: { disabled_at: nil })
      when "no_login"
        @people = @people.where(users: { id: nil })
      end
      @people = @people.limit(100)
    end

    def show
      @person = Person.includes(:user).find(params[:id])
      @user = @person.user
      @position_assignment = @person.position_assignments.new
      @position_titles = PositionTitle.where(active: true).order(:display_order, :name)
    end
  end
end
