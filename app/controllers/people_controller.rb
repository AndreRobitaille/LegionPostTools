class PeopleController < ApplicationController
  before_action :require_authentication

  def index
    scope = Person.left_outer_joins(:user).includes(:user, position_assignments: :position_title)
                  .order(:last_name, :first_name)

    if params[:q].present?
      scope = scope.where(
        "first_name ILIKE :q OR last_name ILIKE :q OR roster_name ILIKE :q OR member_number ILIKE :q",
        q: "%#{params[:q]}%"
      )
    end

    if officer?
      scope = apply_officer_filters(scope)
      @filter_options = build_filter_options
    end

    people = scope.limit(500).to_a
    @officers = people.select { |person| person.active_role_labels.any? }
    @members = people - @officers

    render officer? ? :index : :index
  end

  private

  def apply_officer_filters(scope)
    scope = scope.where(roster_member_status: params[:roster_member_status]) if params[:roster_member_status].present?
    scope = scope.where(roster_paid_through_year: params[:roster_paid_through_year]) if params[:roster_paid_through_year].present?
    case params[:login_status]
    when "enabled"  then scope.where.not(users: { id: nil }).where(users: { disabled_at: nil })
    when "disabled" then scope.where.not(users: { id: nil }).where.not(users: { disabled_at: nil })
    when "no_login" then scope.where(users: { id: nil })
    else scope
    end
  end

  def build_filter_options
    {
      statuses: Person.where.not(roster_member_status: [ nil, "" ]).distinct.order(:roster_member_status).pluck(:roster_member_status),
      years: Person.where.not(roster_paid_through_year: nil).distinct.order(roster_paid_through_year: :desc).pluck(:roster_paid_through_year)
    }
  end
end
