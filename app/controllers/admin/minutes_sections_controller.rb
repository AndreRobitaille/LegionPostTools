module Admin
  class MinutesSectionsController < MinutesDraftController
    before_action :set_section, only: %i[edit update destroy move]

    def new
      @section = @minutes.sections.new(position: next_position)
    end

    def create
      @minutes.with_lock do
        @section = @minutes.sections.new(section_params.merge(position: next_position))
        @section.save!
      end
      redirect_to workspace_path, notice: "Minutes section added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      @section ||= @minutes.sections.new(section_params)
      @section.errors.add(:base, "The section could not be added because the minutes changed. Try again.") if @section.errors.empty?
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      @section.update!(section_params)
      redirect_to workspace_path, notice: "Minutes section updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to workspace_path, alert: "This section changed while you were editing it. Review the latest version."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      if @section.items.exists?
        redirect_to workspace_path, alert: "Move or remove this section's items before removing the section."
      elsif @minutes.sections.count == 1
        redirect_to workspace_path, alert: "Minutes must keep at least one section."
      else
        @section.destroy!
        redirect_to workspace_path, notice: "Minutes section removed."
      end
    end

    def move
      ordered = @minutes.sections.ordered.to_a
      MinutesSection.reorder!(@minutes, moved_record_ids(ordered, @section))
      redirect_to workspace_path, notice: "Minutes section moved."
    rescue ActiveRecord::RecordNotFound
      redirect_to workspace_path, alert: "That section cannot move farther."
    end

    private

    def set_section
      @section = @minutes.sections.find(params[:id])
    end

    def section_params
      params.require(:minutes_section).permit(:title, :lock_version)
    end

    def next_position
      @minutes.sections.maximum(:position).to_i + 1
    end
  end
end
