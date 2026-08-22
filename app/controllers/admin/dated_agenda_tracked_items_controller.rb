module Admin
  class DatedAgendaTrackedItemsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_context
    before_action :ensure_draft_agenda

    def new
      existing_ids = @dated_agenda.dated_agenda_items.where.not(tracked_item_id: nil).pluck(:tracked_item_id).to_set
      active_items = @organization.tracked_items.active.includes(:meeting_body).to_a
      active_items.sort_by! { |item| [ meeting_body_rank(item), *item.priority_sort_key ] }
      @priority_groups = TrackedItem::PRIORITY_BUCKETS.keys.index_with do |bucket|
        active_items.select { |item| item.priority_bucket == bucket }.map { |item| [ item, existing_ids.include?(item.id) ] }
      end
    end

    def create
      tracked_item = @organization.tracked_items.active.find(params[:tracked_item_id])

      @dated_agenda.with_lock do
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        DatedAgendaItem.create_from_tracked_item!(
          tracked_item,
          dated_agenda: @dated_agenda,
          agenda_section: @agenda_section,
          position: @agenda_section.agenda_items.maximum(:position).to_i + 1
        )
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Tracked business added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to new_admin_dated_agenda_tracked_item_path(@dated_agenda, dated_agenda_section_id: @agenda_section.id), alert: "That tracked item is already on this agenda."
    end

    private

    def set_context
      @organization = Organization.first!
      @dated_agenda = @organization.dated_agendas.find(params[:dated_agenda_id])
      @agenda_section = if params[:dated_agenda_section_id].present?
        @dated_agenda.dated_agenda_sections.find(params[:dated_agenda_section_id])
      else
        @dated_agenda.default_agenda_section
      end
    end

    def ensure_draft_agenda
      redirect_locked_agenda if @dated_agenda.locked_for_editing?
    end

    def redirect_locked_agenda
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before adding tracked business."
    end

    def meeting_body_rank(item)
      return 0 if item.meeting_body_id == @dated_agenda.meeting_body_id
      return 1 if item.meeting_body_id.nil?

      2
    end
  end
end
