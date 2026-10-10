class CalendarPdfSourcesController < ApplicationController
  include PdfResourcePolicy

  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :resume_session

  def show
    return head :not_found unless request.local?

    payload = CalendarPdf.verify_source_token!(params.require(:token))
    @organization = Organization.find(payload.fetch("organization_id"))
    @managing = false

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"

    Time.use_zone(@organization.calendar_time_zone) do
      @month = CalendarMonth.new(organization: @organization, date: Date.iso8601(payload.fetch("date")),
        view: payload.fetch("view"), categories: payload.fetch("categories"))
      render "calendar/print", layout: "print"
    end
  rescue ActionController::ParameterMissing,
         ActiveRecord::RecordNotFound,
         ActiveSupport::MessageVerifier::InvalidSignature,
         ArgumentError,
         KeyError,
         TypeError
    head :not_found
  end
end
