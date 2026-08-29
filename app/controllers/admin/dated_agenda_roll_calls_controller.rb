module Admin
  class DatedAgendaRollCallsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_records
    before_action :ensure_draft_agenda

    def edit
      set_form_options
    end

    def update
      entries = replacement_entries

      @dated_agenda.with_lock do
        @dated_agenda.reload
        return redirect_locked_agenda if @dated_agenda.locked_for_editing?

        @item.replace_roll_call_entries!(entries)
      end

      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Officer list saved for this meeting."
    rescue ActiveRecord::RecordInvalid
      set_form_options
      flash.now[:alert] = @item.errors.full_messages.to_sentence.presence || "Officer list could not be saved."
      render :edit, status: :unprocessable_entity
    end

    private

    def set_records
      @organization = Organization.first!
      @dated_agenda = @organization.dated_agendas.find(params[:dated_agenda_id])
      @item = @dated_agenda.dated_agenda_items.find(params[:agenda_item_id])
      raise ActiveRecord::RecordNotFound unless @item.roll_call?
    end

    def ensure_draft_agenda
      return unless @dated_agenda.locked_for_editing?

      redirect_locked_agenda
    end

    def redirect_locked_agenda
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing the officer list."
    end

    def replacement_entries
      permitted = roll_call_params
      submitted_entries = permitted.fetch(:entries, {})
      people = selectable_people.index_by { |person| person.id.to_s }

      entries = @item.roll_call_entries.filter_map do |entry|
        submitted = submitted_entries.fetch(entry.id.to_s, {})
        next if ActiveModel::Type::Boolean.new.cast(submitted[:remove])

        person = selected_person(submitted[:person_id], people)
        {
          position_title: entry.position_title,
          person: person,
          office_name: entry.office_name,
          person_name: person&.full_name,
          sort_order: [ entry.position_title&.display_order || 1_000_000, entry.position ]
        }
      end

      append_new_entry(entries, permitted[:new_entry], people)
      entries
        .sort_by { |entry| entry[:sort_order] }
        .map { |entry| entry.except(:sort_order) }
    end

    def append_new_entry(entries, attributes, people)
      return if attributes.blank? || attributes[:position_title_id].blank?

      title = @organization.position_titles.where(active: true).find(attributes[:position_title_id])
      person = selected_person(attributes[:person_id], people)
      entries << {
        position_title: title,
        person: person,
        office_name: title.name,
        person_name: person&.full_name,
        sort_order: [ title.display_order, 1_000_000 ]
      }
    end

    def selected_person(person_id, people)
      return nil if person_id.blank?

      people.fetch(person_id.to_s) do
        @item.errors.add(:base, "selected officer is not available")
        raise ActiveRecord::RecordInvalid, @item
      end
    end

    def selectable_people
      existing_ids = @item.roll_call_entries.where.not(person_id: nil).select(:person_id)
      Person.directory_visible.or(Person.where(id: existing_ids)).order(:last_name, :first_name, :id)
    end

    def set_form_options
      @people = selectable_people
      @position_titles = @organization.position_titles.where(active: true).order(:display_order, :name)
    end

    def roll_call_params
      params.require(:roll_call).permit(
        entries: %i[person_id remove],
        new_entry: %i[position_title_id person_id]
      )
    end
  end
end
