class EndeavorsController < ApplicationController
  before_action :require_authentication
  before_action -> { require_capability("manage_agendas") }, only: %i[new create edit update complete reopen]
  before_action :set_organization
  before_action :set_endeavor, only: %i[show edit update complete reopen]

  def index
    active_items = @organization.endeavors.active.includes(:meeting_body).to_a
    @priority_groups = Endeavor::PRIORITY_BUCKETS.keys.index_with do |bucket|
      active_items.select { |item| item.priority_bucket == bucket }.sort_by(&:priority_sort_key)
    end
    @completed_items = @organization.endeavors.recently_completed.includes(:meeting_body).limit(20).to_a
  end

  def show
    @history = EndeavorHistory::Presenter.new(@endeavor, before: params[:before])
    @open_tasks = @endeavor.tasks.open.ordered
    @completed_tasks = @endeavor.tasks.completed.order(completed_at: :desc)
    @calendar_events = @endeavor.calendar_events.where("COALESCE(ends_at, starts_at) >= ?", Time.current.beginning_of_day).order(:starts_at)
    @past_events = @endeavor.calendar_events.where("COALESCE(ends_at, starts_at) < ?", Time.current.beginning_of_day).order(starts_at: :desc)
  end

  def new
    @endeavor = @organization.endeavors.new(importance: "standard", status: "active")
    set_meeting_bodies
  end

  def create
    @endeavor = @organization.endeavors.new(endeavor_params.except(:lock_version))
    @endeavor.created_by = current_user

    if @endeavor.save
      redirect_to @endeavor, notice: "Endeavor created."
    else
      set_meeting_bodies
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_meeting_bodies
  end

  def update
    if @endeavor.update(endeavor_params)
      redirect_to @endeavor, notice: "Endeavor updated."
    else
      set_meeting_bodies
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    redirect_to @endeavor, alert: "This Endeavor changed elsewhere. Review the latest version before editing again."
  end

  def complete
    @endeavor.complete!(current_user)
    redirect_to @endeavor, notice: "Endeavor completed."
  rescue ActiveRecord::RecordInvalid
    redirect_to @endeavor, alert: @endeavor.errors.full_messages.to_sentence
  end

  def reopen
    @endeavor.reopen!
    redirect_to @endeavor, notice: "Endeavor reopened."
  rescue ActiveRecord::RecordInvalid
    redirect_to @endeavor, alert: @endeavor.errors.full_messages.to_sentence
  end

  private

  def set_organization
    @organization = Organization.first!
  end

  def set_endeavor
    @endeavor = @organization.endeavors.find(params[:id])
  end

  def set_meeting_bodies
    @meeting_bodies = @organization.meeting_bodies.where(active: true).order(:name)
  end

  def endeavor_params
    permitted = params.require(:endeavor).permit(:title, :summary, :details, :importance, :due_on, :raise_by_on, :meeting_body_id, :lock_version)
    date_key = permitted.key?(:due_on) ? :due_on : :raise_by_on
    permitted.delete(:raise_by_on) if date_key == :due_on
    if permitted.key?(date_key)
      raw = permitted[date_key]
      permitted[date_key] = raw.blank? ? nil : (helpers.parse_legion_date(raw) || raw)
    end
    permitted
  end
end
