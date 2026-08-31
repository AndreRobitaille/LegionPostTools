module Api
  class MinutesAttestationsController < BaseController
    before_action -> { require_capability("attest_minutes") }

    def create
      minutes = organization.meetings.find(params[:meeting_id]).minutes || raise(ActiveRecord::RecordNotFound)
      token = Current.agent_access_token
      return render_error("Use the signed-in minutes screen for a human browser attestation.", status: :unprocessable_entity) unless token

      confirmation = OfficialActionConfirmation.for_delegated_agent!(
        minutes:,
        agent_access_token: token,
        action: "attest"
      )
      attestation = minutes.attest_with_confirmation!(confirmation:)
      render json: {
        minutes: minutes_detail_payload(minutes.reload),
        attestation: attestation_payload(attestation),
        execution: { mode: "delegated_agent", agent_access_token_id: token.id }
      }
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "The minutes could not be attested.")
    end
  end
end
