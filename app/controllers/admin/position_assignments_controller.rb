module Admin
  class PositionAssignmentsController < BaseController
    include LegionFormatHelper

    def create
      @person = Person.find(params[:person_id])
      @position_title = PositionTitle.where(active: true).order(:display_order, :name).find_by(id: position_assignment_params[:position_title_id])

      unless @position_title
        redirect_to person_path(@person), alert: "Selected post role is not available."
        return
      end

      @position_assignment = @person.position_assignments.new(position_assignment_params.except(:position_title_id).merge(position_title: @position_title))

      if @position_assignment.save
        redirect_to person_path(@person), notice: "Post role assigned."
      else
        redirect_to person_path(@person), alert: @position_assignment.errors.full_messages.to_sentence
      end
    end

    def update
      @person = Person.find(params[:person_id])
      @position_assignment = @person.position_assignments.find(params[:id])

      if @position_assignment.update(dated_update_params)
        redirect_to person_path(@person), notice: "Post role updated."
      else
        redirect_to person_path(@person), alert: @position_assignment.errors.full_messages.to_sentence
      end
    end

    private

    def position_assignment_params
      raw = params.require(:position_assignment).permit(:position_title_id, :starts_on, :ends_on)
      raw.merge(starts_on: coerce_date(raw[:starts_on]), ends_on: coerce_date(raw[:ends_on]))
    end

    def dated_update_params
      raw = params.require(:position_assignment).permit(:starts_on, :ends_on)
      permitted = {}
      permitted[:starts_on] = coerce_date(raw[:starts_on]) if raw.key?(:starts_on)
      permitted[:ends_on] = coerce_date(raw[:ends_on]) if raw.key?(:ends_on)
      permitted
    end

    def coerce_date(value)
      return nil if value.blank?

      parse_legion_date(value) || value
    end
  end
end
