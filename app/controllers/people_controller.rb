class PeopleController < ApplicationController
  before_action :require_authentication

  def index
    scope = Person.left_outer_joins(:user).includes(:user, position_assignments: :position_title)

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

    scope = apply_sort(scope)

    people = scope.limit(500).to_a
    @officers = people.select { |person| person.active_role_labels.any? }
    @members = people - @officers
  end

  private

  SORT_OPTIONS = {
    "name" => [ :last_name, :first_name ],
    "member_id" => [ :member_number ],
    "paid_through" => [ Arel.sql("roster_paid_through_year DESC NULLS LAST"), :last_name ],
    "status" => [ :roster_member_status, :last_name ],
    "branch" => [ :roster_branch, :last_name ]
  }.freeze

  def apply_sort(scope)
    order_columns = SORT_OPTIONS.fetch(params[:sort], SORT_OPTIONS["name"])
    scope.order(*order_columns)
  end

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
