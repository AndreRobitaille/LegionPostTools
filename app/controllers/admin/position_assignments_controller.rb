module Admin
  class PositionAssignmentsController < BaseController
    def create
      @person = Person.find(params[:person_id])
      @position_title = PositionTitle.where(active: true).order(:display_order, :name).find_by(id: position_assignment_params[:position_title_id])

      unless @position_title
        redirect_to admin_person_path(@person), alert: "Selected post role is not available."
        return
      end

      @position_assignment = @person.position_assignments.new(position_assignment_params.except(:position_title_id).merge(position_title: @position_title))

      if @position_assignment.save
        redirect_to admin_person_path(@person), notice: "Post role assigned."
      else
        redirect_to admin_person_path(@person), alert: @position_assignment.errors.full_messages.to_sentence
      end
    end

    def update
      @person = Person.find(params[:person_id])
      @position_assignment = @person.position_assignments.find(params[:id])

      if @position_assignment.update(ends_on_params)
        redirect_to admin_person_path(@person), notice: "Post role updated."
      else
        redirect_to admin_person_path(@person), alert: @position_assignment.errors.full_messages.to_sentence
      end
    end

    private

    def position_assignment_params
      params.require(:position_assignment).permit(:position_title_id, :starts_on, :ends_on)
    end

    def ends_on_params
      params.require(:position_assignment).permit(:ends_on)
    end
  end
end
