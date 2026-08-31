module Api
  class MinutesApprovalsController < BaseController
    before_action -> { require_capability("approve_minutes") }

    def create
      minutes = organization.meetings.find(params[:meeting_id]).minutes || raise(ActiveRecord::RecordNotFound)
      token = Current.agent_access_token
      return render_error("Use the signed-in minutes screen for a human browser approval.", status: :unprocessable_entity) unless token

      confirmation = OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: token,
        action: "approve"
      )
      revision = minutes.approve_with_confirmation!(confirmation:)
      render json: {
        minutes: minutes_detail_payload(minutes.reload),
        approval: revision_payload(revision),
        execution: { mode: "delegated_agent", agent_access_token_id: token.id }
      }
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "The minutes could not be approved.")
    end
  end
end
