module Admin
  class MinutesItemEndeavorsController < MinutesDraftController
    before_action :set_item_and_proposal
    before_action :set_mode
    before_action -> { require_capability("manage_agendas") if @mode == "create" }
    before_action :set_endeavors

    def new
      @values = {
        "lock_version" => @item.lock_version,
        "title" => @suggestion&.payload&.fetch("title") || @item.title,
        "body" => @suggestion&.payload&.fetch("body") || (@item.body.present? ? @item.body.to_plain_text : @item.agenda_body.to_plain_text),
        "endeavor_id" => @suggestion&.payload&.dig("endeavor_id") || @item.endeavor_id
      }
    end

    def create
      @values = confirmation_params.to_h
      endeavor = MinutesEndeavors::Confirm.call(item: @item, reviewer: current_user,
        attributes: @values.merge("endeavor_action" => @mode), suggestion: @suggestion)
      redirect_to workspace_path, notice: "Endeavor linked: #{endeavor.title}."
    rescue ActiveRecord::RecordInvalid => error
      @form_errors = error.record.errors.full_messages
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::StaleObjectError
      @form_errors = [ "This minutes item changed. Return to the minutes and review its current version before confirming." ]
      render :new, status: :unprocessable_entity
    end

    private

    def set_item_and_proposal
      @item = @minutes.items.find(params[:item_id])
      return if params[:suggestion_id].blank?

      @suggestion = MinutesDraftSuggestion.joins(:minutes_draft_run)
        .where(minutes_draft_runs: { meeting_minutes_id: @minutes.id })
        .where(kind: "endeavor_proposal", minutes_item: @item, review_state: "unreviewed")
        .find(params[:suggestion_id])
    end

    def set_mode
      @mode = params[:mode] || params.dig(:confirmation, :endeavor_action) || "create"
      raise ActiveRecord::RecordNotFound unless @mode.in?(%w[create link])
    end

    def set_endeavors
      @endeavors = @organization.endeavors.order(:title)
    end

    def confirmation_params
      params.require(:confirmation).permit(:title, :body, :endeavor_id, :lock_version)
    end
  end
end
