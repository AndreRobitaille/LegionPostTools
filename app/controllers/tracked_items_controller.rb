class TrackedItemsController < ApplicationController
  before_action :require_authentication
  before_action -> { require_capability("manage_agendas") }, only: %i[new create edit update complete reopen]
  before_action :set_organization
  before_action :set_tracked_item, only: %i[show edit update complete reopen]

  def index
    active_items = @organization.tracked_items.active.includes(:meeting_body).to_a
    @priority_groups = TrackedItem::PRIORITY_BUCKETS.keys.index_with do |bucket|
      active_items.select { |item| item.priority_bucket == bucket }.sort_by(&:priority_sort_key)
    end
    @completed_items = @organization.tracked_items.recently_completed.includes(:meeting_body).limit(20).to_a
  end

  def show
    build_timeline
  end

  def new
    @tracked_item = @organization.tracked_items.new(importance: "standard", status: "active")
    set_meeting_bodies
  end

  def create
    @tracked_item = @organization.tracked_items.new(tracked_item_params.except(:lock_version))
    @tracked_item.created_by = current_user

    if @tracked_item.save
      redirect_to @tracked_item, notice: "Tracked item created."
    else
      set_meeting_bodies
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    set_meeting_bodies
  end

  def update
    if @tracked_item.update(tracked_item_params)
      redirect_to @tracked_item, notice: "Tracked item updated."
    else
      set_meeting_bodies
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StaleObjectError
    redirect_to @tracked_item, alert: "This tracked item changed elsewhere. Review the latest version before editing again."
  end

  def complete
    @tracked_item.complete!(current_user)
    redirect_to @tracked_item, notice: "Tracked item completed."
  rescue ActiveRecord::RecordInvalid
    redirect_to @tracked_item, alert: @tracked_item.errors.full_messages.to_sentence
  end

  def reopen
    @tracked_item.reopen!
    redirect_to @tracked_item, notice: "Tracked item reopened."
  rescue ActiveRecord::RecordInvalid
    redirect_to @tracked_item, alert: @tracked_item.errors.full_messages.to_sentence
  end

  private

  def set_organization
    @organization = Organization.first!
  end

  def set_tracked_item
    @tracked_item = @organization.tracked_items.find(params[:id])
  end

  def set_meeting_bodies
    @meeting_bodies = @organization.meeting_bodies.where(active: true).order(:name)
  end

  def tracked_item_params
    permitted = params.require(:tracked_item).permit(:title, :summary, :details, :importance, :raise_by_on, :meeting_body_id, :lock_version)
    # The shared date field submits DD MMM YYYY text, matching how dates read
    # everywhere else in the app.
    if permitted.key?(:raise_by_on)
      raw = permitted[:raise_by_on]
      permitted[:raise_by_on] = raw.blank? ? nil : (helpers.parse_legion_date(raw) || raw)
    end
    permitted
  end

  def build_timeline
    updates = @tracked_item.updates.includes(author: :person).map do |update|
      [ update.created_at, :update, update ]
    end
    # Timestamped by the meeting date, not when the row was created: the entry is
    # about the meeting the business was carried to, and the reader sees that same
    # date on the card. Two disagreeing dates on one entry is just confusing.
    appearances = @tracked_item.dated_agenda_items.includes(dated_agenda: :meeting_body).map do |agenda_item|
      [ agenda_item.dated_agenda.starts_at, :agenda, agenda_item ]
    end
    @timeline_entries = (updates + appearances).sort_by { |time, _, _| time }.reverse
  end
end
