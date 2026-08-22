class TrackedItemUpdatesController < ApplicationController
  before_action -> { require_capability("manage_agendas") }
  before_action :set_tracked_item

  def create
    update = @tracked_item.updates.new(update_params)
    update.author = current_user

    if update.save
      redirect_to @tracked_item, notice: "Update added."
    else
      redirect_to @tracked_item, alert: update.errors.full_messages.to_sentence
    end
  end

  private

  def set_tracked_item
    @tracked_item = Organization.first!.tracked_items.find(params[:tracked_item_id])
  end

  def update_params
    params.require(:tracked_item_update).permit(:body)
  end
end
