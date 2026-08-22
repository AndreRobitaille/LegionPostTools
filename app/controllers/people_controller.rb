class PeopleController < ApplicationController
  before_action :require_authentication

  def index
    @can_manage = current_user.can?("manage_settings")
    scope = people_visible_to_current_user.left_outer_joins(:user).includes(:user, position_assignments: :position_title)

    if params[:q].present?
      scope = apply_search(scope)
    end

    if full_membership_access?
      scope = apply_membership_filters(scope)
      @filter_options = build_filter_options
    end

    scope = apply_sort(scope)

    people = scope.limit(500).to_a
    @officers = people.select { |person| person.active_role_labels.any? }
    @members = people - @officers
  end

  def show
    @person = people_visible_to_current_user.includes(:user, position_assignments: :position_title).find(params[:id])
    @user = @person.user
    @can_manage = current_user.can?("manage_settings")

    if @can_manage
      @position_titles = PositionTitle.where(organization: Organization.first, active: true).order(:display_order, :name)
    end
  end

  private

  MEMBERSHIP_SORT_OPTIONS = {
    "name" => [ :last_name, :first_name ],
    "member_id" => [ :member_number ],
    "paid_through" => [ Arel.sql("roster_paid_through_year DESC NULLS LAST"), :last_name ],
    "status" => [ :roster_member_status, :last_name ],
    "branch" => [ :roster_branch, :last_name ]
  }.freeze

  MEMBER_SORT_OPTIONS = MEMBERSHIP_SORT_OPTIONS.slice("name", "branch").freeze

  def apply_search(scope)
    search_columns = [ "first_name ILIKE :q", "last_name ILIKE :q", "roster_name ILIKE :q" ]
    search_columns << "member_number ILIKE :q" if full_membership_access?

    scope.where(search_columns.join(" OR "), q: "%#{params[:q]}%")
  end

  def apply_sort(scope)
    sort_options = full_membership_access? ? MEMBERSHIP_SORT_OPTIONS : MEMBER_SORT_OPTIONS
    order_columns = sort_options.fetch(params[:sort], sort_options["name"])
    scope.order(*order_columns)
  end

  def apply_membership_filters(scope)
    scope = scope.where(roster_member_status: params[:roster_member_status]) if params[:roster_member_status].present?
    scope = scope.where(roster_paid_through_year: params[:roster_paid_through_year]) if params[:roster_paid_through_year].present?
    return scope unless @can_manage

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

  def people_visible_to_current_user
    full_membership_access? ? Person.all : Person.directory_visible
  end
end
