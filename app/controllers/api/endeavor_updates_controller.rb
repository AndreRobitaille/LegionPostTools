module Api
  class EndeavorUpdatesController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_endeavor

    def create
      update = @endeavor.updates.new(body: params[:body])
      update.author = current_user

      if update.save
        render json: {
          endeavor_update: {
            id: update.id,
            body: update.body.to_plain_text.presence || update.body.to_s,
            created_at: update.created_at.iso8601
          }
        }, status: :created
      else
        render_error(update.errors.full_messages.to_sentence, status: :unprocessable_entity, details: update.errors.full_messages)
      end
    end

    private

    def set_endeavor
      @endeavor = organization.endeavors.find(params[:endeavor_id])
    end
  end
end
