class EndeavorUpdatesController < ApplicationController
  before_action -> { require_capability("manage_agendas") }
  before_action :set_endeavor

  def create
    update = @endeavor.updates.new(update_params)
    update.author = current_user

    if update.save
      redirect_to @endeavor, notice: "Update added."
    else
      redirect_to @endeavor, alert: update.errors.full_messages.to_sentence
    end
  end

  private

  def set_endeavor
    @endeavor = Organization.first!.endeavors.find(params[:endeavor_id])
  end

  def update_params
    params.require(:endeavor_update).permit(:body)
  end
end
