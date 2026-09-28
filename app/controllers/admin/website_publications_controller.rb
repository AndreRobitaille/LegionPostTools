module Admin
  class WebsitePublicationsController < ApplicationController
    include CalendarTimeZone
    before_action -> { require_capability("publish_public_content") }
    before_action :load_organization
    before_action :load_publication, except: %i[index create feature]
    before_action -> { response.set_header("Cache-Control", "no-store") }
    rescue_from WebsitePublication::Conflict, ActiveRecord::StaleObjectError, with: :conflict
    rescue_from ArgumentError, ActiveRecord::RecordInvalid, with: :invalid
    rescue_from WebsitePublication::Forbidden, with: -> { head :forbidden }

    def index
      @stories = scope.where(kind: "story").order(:id).to_a
      @events = scope.where(kind: "event").includes(:calendar_event).order(updated_at: :desc)
      @calendar_events = @organization.calendar_events.where.not(id: scope.where(kind: "event").select(:calendar_event_id).where.not(calendar_event_id: nil)).order(starts_at: :desc)
    end

    def create
      source = @organization.calendar_events.find(params[:calendar_event_id]) if params[:calendar_event_id].present?
      publication = WebsitePublication.create_draft!(organization: @organization, actor: current_user, calendar_event: source)
      redirect_to edit_admin_website_publication_path(publication)
    end

    def edit
      if !@publication.story? && @organization.website_calendar_enabled?
        redirect_to admin_website_calendar_path, notice: "Event listings are managed on the calendar."
      end
    end

    def update
      @publication.edit_draft!(actor: current_user, version: params[:version],
        attributes: params.require(:draft).permit(*WebsitePublication::STORY_FIELDS, *WebsitePublication::EVENT_FIELDS).to_h,
        portrait: params[:portrait])
      done("Draft saved. Review it before publishing.")
    end

    def publish
      @publication.publish!(actor: current_user, version: params[:version], source_version: params[:source_version])
      done("Published to the public website.")
    end

    def withdraw
      @publication.withdraw!(actor: current_user, version: params[:version], revoke_consent: params[:revoke_consent] == "1")
      done("Withdrawn from the public website.")
    end

    def consent
      @publication.confirm_consent!(actor: current_user, version: params[:version], note: params[:note])
      done("Consent recorded for this draft and portrait.")
    end

    def eligibility
      @publication.approve_eligibility!(actor: current_user, version: params[:version], source_version: params[:source_version], reason: params[:reason], resolve_flags: params[:resolve_flags] == "1")
      done("Eligibility approved. Review and publish when ready.")
    end

    def internal
      @publication.mark_internal!(actor: current_user, version: params[:version], source_version: params[:source_version])
      done("Marked internal and withdrawn from the public website.")
    end

    def feature
      WebsitePublication.feature!(organization: @organization, actor: current_user, ids: Array(params[:ids]), versions: params.fetch(:versions, ActionController::Parameters.new).permit(*scope.where(kind: "story").pluck(:id).map(&:to_s)).to_h)
      redirect_to admin_website_publications_path, notice: "Homepage introductions updated."
    end

    def portrait
      image = @publication.portraits.find_by!(revision: params[:revision])
      raise ActiveRecord::RecordNotFound unless %w[small large].include?(params[:size])
      send_data image.public_send(params[:size]), type: "image/webp", disposition: "inline"
    end

    private

    def load_organization
      @organization = Organization.first!
    end

    def scope
      WebsitePublication.where(organization: @organization)
    end

    def load_publication
      @publication = scope.find(params[:id])
    end

    def done(message)
      redirect_to edit_admin_website_publication_path(@publication), notice: message, status: :see_other
    end

    def conflict(exception)
      render plain: "#{exception.message} Return to the review page and reload before trying again.", status: :conflict
    end

    def invalid(exception)
      if @publication
        @publication.reload
        flash.now[:alert] = exception.message
        render :edit, status: :unprocessable_entity
      else
        redirect_to admin_website_publications_path, alert: exception.message
      end
    end
  end
end
