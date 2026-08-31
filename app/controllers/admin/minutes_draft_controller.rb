module Admin
  class MinutesDraftController < ApplicationController
    before_action -> { require_capability("manage_minutes") }
    before_action :set_meeting_and_minutes
    before_action :ensure_draft_minutes

    private

    def set_meeting_and_minutes
      @organization = Organization.first!
      @meeting = @organization.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_draft_minutes
      return if @minutes.draft?

      redirect_to admin_meeting_minutes_path(@meeting), alert: "Reopen these minutes before changing the working record."
    end

    def workspace_path
      admin_meeting_minutes_path(@meeting)
    end

    def minutes_people(existing_ids = [])
      ids = Array(existing_ids).compact_blank
      Person.directory_visible
        .or(Person.where(id: ids))
        .includes(position_assignments: :position_title)
        .order(:last_name, :first_name, :id)
    end

    def normalized_outcome_attributes(permitted)
      attributes = permitted.to_h.symbolize_keys
      other_disposition = attributes.delete(:other_disposition)
      attributes[:disposition] = other_disposition if attributes[:disposition] == "other"
      reviewable_dispositions = MinutesOutcome::DISPOSITIONS - [ "not_recorded" ]
      raise KeyError unless attributes[:disposition].in?(reviewable_dispositions)

      normalize_participant!(attributes, :mover)
      normalize_participant!(attributes, :seconder)
      attributes
    end

    def normalize_participant!(attributes, role)
      unidentified = attributes.delete(:"#{role}_unidentified") == "1"
      person_id_key = :"#{role}_person_id"
      name_key = :"#{role}_name"

      if unidentified
        attributes[person_id_key] = nil
        attributes[name_key] = nil
      elsif attributes[person_id_key].present?
        existing_ids = [ @outcome&.mover_person_id, @outcome&.seconder_person_id ]
        person = minutes_people(existing_ids).find(attributes[person_id_key])
        attributes[person_id_key] = person.id
        attributes[name_key] = person.full_name
      end
    end

    def moved_record_ids(records, record)
      current = records.index(record)
      target = params[:direction] == "up" ? current - 1 : current + 1
      valid_move = params[:direction].in?(%w[up down]) && target.between?(0, records.length - 1)
      raise ActiveRecord::RecordNotFound unless valid_move

      records[current], records[target] = records[target], records[current]
      records.map(&:id)
    end
  end
end
