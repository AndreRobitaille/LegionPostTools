class DatedAgendaPdfSourcesController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :resume_session

  def show
    return head :not_found unless request.local?

    payload = DatedAgendaPdf.verify_source_token!(params.require(:token))
    @organization = Organization.find(payload.fetch("organization_id"))
    @dated_agenda = @organization.dated_agendas.find(payload.fetch("dated_agenda_id"))

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"

    if payload.fetch("variant") == "officer_notes"
      render "admin/dated_agendas/commander", layout: "print"
    else
      render "admin/dated_agendas/print", layout: "print"
    end
  rescue ActionController::ParameterMissing,
         ActiveRecord::RecordNotFound,
         ActiveSupport::MessageVerifier::InvalidSignature,
         ArgumentError,
         KeyError
    head :not_found
  end
end
