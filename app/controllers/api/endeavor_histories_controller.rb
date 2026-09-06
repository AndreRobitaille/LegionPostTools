module Api
  class EndeavorHistoriesController < BaseController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_endeavor

    def show
      render json: {
        enabled: EndeavorHistory::Config.enabled?, withdrawn: @endeavor.history_withdrawn?, lock_version: @endeavor.lock_version,
        guidance: @endeavor.history_guidances.order(id: :desc).first&.slice(:id, :body, :created_at),
        runs: @endeavor.history_runs.recent.limit(20).map { |run| run.slice(:id, :status, :error_category, :manifest, :steps, :created_at, :finished_at) },
        editions: @endeavor.history_editions.order(id: :desc).limit(10).map { |edition| edition.slice(:id, :payload, :sha256, :created_at) }
      }
    end

    def create
      case params[:operation]
      when "refresh"
        meeting = organization.meetings.find(params[:meeting_id]) if params[:meeting_id].present?
        raise EndeavorHistory::Error, "no_sources" if meeting && !meeting.minutes&.member_visible?
        run = EndeavorHistory::Processing.request(@endeavor, requester: current_user, force: true, meeting_id: meeting&.id)
        render json: { run: run.slice(:id, :status) }, status: :accepted
      when "guidance", "withdraw", "resume"
        EndeavorHistory::Manage.change(@endeavor, user: current_user, action: params[:operation],
          lock_version: params[:lock_version], guidance: params[:guidance])
        run = EndeavorHistory::Processing.request(@endeavor, requester: current_user, force: true) if params[:operation] == "resume" && EndeavorHistory::Config.enabled? && EndeavorHistory::Sources.new(@endeavor).revisions.any?
        render json: { lock_version: @endeavor.lock_version, withdrawn: @endeavor.history_withdrawn?, run: run&.slice(:id, :status) }
      else
        raise EndeavorHistory::Error, "invalid_action"
      end
    rescue EndeavorHistory::Error => error
      render_error(helpers.endeavor_history_error(error.category), status: :unprocessable_entity)
    rescue ActiveRecord::StaleObjectError
      render_error("This Endeavor changed. Fetch it again before retrying.", status: :conflict)
    rescue ActiveRecord::RecordInvalid => error
      render_error(error.record.errors.full_messages.to_sentence, status: :unprocessable_entity)
    end

    private

    def set_endeavor
      @endeavor = organization.endeavors.find(params[:endeavor_id])
    end
  end
end
