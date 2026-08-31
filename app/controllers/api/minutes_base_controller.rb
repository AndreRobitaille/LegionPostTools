module Api
  class MinutesBaseController < BaseController
    before_action -> { require_capability("manage_minutes") }
    before_action :set_meeting_and_minutes
    before_action :ensure_draft_minutes

    private

    def set_meeting_and_minutes
      @meeting = organization.meetings.find(params[:meeting_id])
      @minutes = @meeting.minutes || raise(ActiveRecord::RecordNotFound)
    end

    def ensure_draft_minutes
      return if @minutes.draft?

      render_error("Only draft minutes can be changed.", status: :unprocessable_entity)
    end

    def exact_order_ids!(scope)
      raw_ids = params.require(:ids)
      raise ArgumentError, "ids must be an array." unless raw_ids.is_a?(Array)

      ids = raw_ids.map { |id| Integer(id.to_s, 10) }
      expected = scope.pluck(:id)
      unless ids.uniq.length == ids.length && ids.sort == expected.sort
        raise ArgumentError, "ids must contain every current record in this parent exactly once."
      end

      ids
    rescue ActionController::ParameterMissing => error
      raise ArgumentError, error.message
    end

    def normalize_outcome_attributes(permitted, outcome: nil)
      attributes = permitted.to_h.symbolize_keys
      other_disposition = attributes.delete(:other_disposition)
      attributes[:disposition] = other_disposition if attributes[:disposition] == "other"
      if attributes.key?(:disposition) && !attributes[:disposition].in?(MinutesOutcome::DISPOSITIONS - [ "not_recorded" ])
        raise ArgumentError, "Choose a recorded outcome: adopted, lost, withdrawn, postponed, referred, or no_vote."
      end

      normalize_participant!(attributes, :mover, outcome: outcome)
      normalize_participant!(attributes, :seconder, outcome: outcome)
      attributes
    end

    def normalize_participant!(attributes, role, outcome:)
      unidentified_key = :"#{role}_unidentified"
      person_id_key = :"#{role}_person_id"
      name_key = :"#{role}_name"
      unidentified = ActiveModel::Type::Boolean.new.cast(attributes.delete(unidentified_key))

      if unidentified
        attributes[person_id_key] = nil
        attributes[name_key] = nil
      elsif attributes.key?(person_id_key) && attributes[person_id_key].present?
        existing_ids = [ outcome&.mover_person_id, outcome&.seconder_person_id ]
        person = minutes_people(existing_ids).find(attributes[person_id_key])
        attributes[person_id_key] = person.id
        attributes[name_key] = person.full_name
      elsif attributes.key?(person_id_key)
        attributes[person_id_key] = nil
        attributes[name_key] = nil
      end
    end

    def minutes_people(existing_ids = [])
      ids = Array(existing_ids).compact_blank
      Person.directory_visible
        .or(Person.where(id: ids))
        .includes(position_assignments: :position_title)
        .order(:last_name, :first_name, :id)
    end
  end
end
