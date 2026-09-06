module Admin
  class EndeavorHistoriesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_endeavor

    def show
      @sources = EndeavorHistory::Sources.new(@endeavor)
      @guidance = @endeavor.history_guidances.order(id: :desc).first
      @runs = @endeavor.history_runs.recent.limit(20)
      @editions = @endeavor.history_editions.order(id: :desc).limit(10)
    end

    def create
      case params[:operation]
      when "refresh"
        meeting = @endeavor.organization.meetings.find(params[:meeting_id]) if params[:meeting_id].present?
        if meeting && !meeting.minutes&.member_visible?
          raise EndeavorHistory::Error, "no_sources"
        end
        # A meeting rerun refreshes its complete Endeavor history as well, so the overview stays coherent.
        EndeavorHistory::Processing.request(@endeavor, requester: current_user, force: true, meeting_id: meeting&.id)
      when "guidance", "withdraw", "resume"
        EndeavorHistory::Manage.change(@endeavor, user: current_user, action: params[:operation],
          lock_version: params[:lock_version], guidance: params[:guidance])
        if params[:operation] == "resume" && EndeavorHistory::Config.enabled? && EndeavorHistory::Sources.new(@endeavor).revisions.any?
          EndeavorHistory::Processing.request(@endeavor, requester: current_user, force: true)
        end
      else
        raise EndeavorHistory::Error, "invalid_action"
      end
      redirect_to admin_endeavor_history_path(@endeavor), notice: "Endeavor history updated."
    rescue EndeavorHistory::Error => error
      redirect_to admin_endeavor_history_path(@endeavor), alert: helpers.endeavor_history_error(error.category)
    rescue ActiveRecord::StaleObjectError
      redirect_to admin_endeavor_history_path(@endeavor), alert: "This Endeavor changed. Refresh the page before trying again."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_endeavor_history_path(@endeavor), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_endeavor
      @endeavor = Organization.first!.endeavors.find(params[:endeavor_id])
    end
  end
end
