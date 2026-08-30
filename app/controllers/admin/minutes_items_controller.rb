module Admin
  class MinutesItemsController < MinutesDraftController
    before_action :set_item, only: %i[edit update destroy move]
    before_action :set_form_collections, only: %i[new create edit update]

    def new
      section = selected_section
      @item = section.items.new(position: next_position(section), behavior_type: "business_item")
    end

    def create
      section = selected_section
      section.with_lock do
        @item = section.items.new(item_params.except(:minutes_section_id).merge(position: next_position(section)))
        @item.save!
      end
      redirect_to workspace_path, notice: "Minutes item added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      @item ||= section.items.new(item_params.except(:minutes_section_id))
      @item.errors.add(:base, "The item could not be added because the minutes changed. Try again.") if @item.errors.empty?
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      attributes = item_params
      section_id = attributes.delete(:minutes_section_id)
      section = @minutes.sections.find(section_id)

      @item.transaction do
        if @item.minutes_section != section
          @item.minutes_section = section
          @item.position = next_position(section)
        end
        @item.update!(attributes)
      end
      redirect_to workspace_path, notice: "Minutes item updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to workspace_path, alert: "This item changed while you were editing it. Review the latest version."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @item.destroy!
      redirect_to workspace_path, notice: "Minutes item removed."
    end

    def move
      records = @item.minutes_section.items.to_a
      MinutesItem.reorder!(@item.minutes_section, moved_record_ids(records, @item))
      redirect_to workspace_path, notice: "Minutes item moved."
    rescue ActiveRecord::RecordNotFound
      redirect_to workspace_path, alert: "That item cannot move farther."
    end

    private

    def set_item
      @item = @minutes.items.find(params[:id])
    end

    def set_form_collections
      @sections = @minutes.sections.ordered
      @endeavors = @organization.endeavors.order(:title)
    end

    def selected_section
      section_id = params[:minutes_section_id] || params.dig(:minutes_item, :minutes_section_id)
      @minutes.sections.find(section_id)
    end

    def item_params
      params.require(:minutes_item).permit(
        :minutes_section_id,
        :title,
        :behavior_type,
        :body,
        :endeavor_id,
        :lock_version
      )
    end

    def next_position(section)
      section.items.maximum(:position).to_i + 1
    end
  end
end
