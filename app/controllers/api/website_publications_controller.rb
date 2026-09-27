require "base64"
require "stringio"

module Api
  class WebsitePublicationsController < BaseController
    prepend_before_action :prevent_private_data_caching
    before_action -> { require_capability("publish_public_content") }
    before_action :set_publication, except: %i[index create featured feature]
    # Check current editorial authority even when returning a stored retry response.
    skip_around_action :with_agent_idempotency
    around_action :with_agent_idempotency

    rescue_from WebsitePublication::Conflict, ActiveRecord::StaleObjectError, with: :render_conflict
    rescue_from ArgumentError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid, with: :render_invalid
    rescue_from WebsitePublication::Forbidden, with: ->(error) { render_error(error.message, status: :forbidden) }

    def index
      records = scope.order(:id)
      %w[kind status].each do |field|
        next unless params.key?(field)
        choices = field == "kind" ? %w[story event] : %w[draft published withdrawn]
        raise ArgumentError, "Invalid #{field}." unless choices.include?(params[field])
        records = records.where(field => params[field])
      end
      page = collection_page(records.includes(:calendar_event))
      return unless page

      render json: { website_publications: page[:records].map { |record| publication_payload(record) }, pagination: page[:metadata] }
    end

    def show
      render_publication
    end

    def create
      unless params[:calendar_event_id].nil?
        id = nonnegative_integer!(params[:calendar_event_id], "calendar_event_id")
        source = organization.calendar_events.find(id)
      end
      @publication = WebsitePublication.create_draft!(organization: organization, actor: current_user, calendar_event: source)
      render_publication(status: :created)
    end

    def update
      draft = params[:draft]
      raise ArgumentError, "draft must be an object." unless draft.is_a?(ActionController::Parameters)
      fields = @publication.story? ? WebsitePublication::STORY_FIELDS : WebsitePublication::EVENT_FIELDS
      raise ArgumentError, "draft contains unsupported fields." if (draft.keys - fields).any?
      raise ArgumentError, "draft fields must be strings." unless draft.values.all? { |value| value.is_a?(String) }
      @publication.edit_draft!(actor: current_user, version: version!, attributes: draft.permit(*fields).to_h)
      render_publication
    end

    def upload_portrait
      version = version!
      encoded = params[:portrait_base64]
      unless encoded.is_a?(String) && encoded.present? && encoded.bytesize <= ((10.megabytes + 2) / 3) * 4
        raise ArgumentError, "portrait_base64 must contain a JPEG, PNG or WebP image of at most 10 MiB."
      end
      bytes = Base64.strict_decode64(encoded)
      @publication.edit_draft!(actor: current_user, version: version, attributes: {}, portrait: StringIO.new(bytes))
      render_publication
    end

    def portrait
      raise ActiveRecord::RecordNotFound unless %w[small large].include?(params[:size])
      image = @publication.portraits.find_by!(revision: params[:revision])
      send_data image.public_send(params[:size]), type: "image/webp", disposition: "inline"
    end

    def consent
      @publication.confirm_consent!(actor: current_user, version: version!, note: params[:note])
      render_publication
    end

    def eligibility
      @publication.approve_eligibility!(actor: current_user, version: version!, source_version: source_version!,
        reason: params[:reason], resolve_flags: boolean!(:resolve_flags))
      render_publication
    end

    def internal
      @publication.mark_internal!(actor: current_user, version: version!, source_version: source_version!)
      render_publication
    end

    def publish
      @publication.publish!(actor: current_user, version: version!, source_version: @publication.story? ? nil : source_version!)
      render_publication
    end

    def withdraw
      @publication.withdraw!(actor: current_user, version: version!, revoke_consent: boolean!(:revoke_consent))
      render_publication
    end

    def featured
      render json: featured_payload
    end

    def feature
      ids = params[:public_ids]
      versions = params[:versions]
      unless ids.is_a?(Array) && ids.all? { |id| id.is_a?(String) && id.present? } && versions.is_a?(ActionController::Parameters)
        raise ArgumentError, "Send public_ids as an array and versions as the complete story id/version object from GET featured."
      end
      reviewed_versions = versions.to_unsafe_h.transform_values { |value| nonnegative_integer!(value, "versions value").to_s }
      WebsitePublication.feature!(organization: organization, actor: current_user, ids: ids, versions: reviewed_versions)
      render json: featured_payload
    end

    def history
      page = collection_page(@publication.publication_events.order(:id))
      return unless page
      render json: { publication_events: page[:records].map { |event|
        { id: event.id, action: event.action, actor_id: event.actor_id, version: event.version,
          details: event.details, created_at: event.created_at.iso8601(6) }
      }, pagination: page[:metadata] }
    end

    private

    def scope
      WebsitePublication.where(organization: organization)
    end

    def set_publication
      @publication = scope.find(params[:id])
    end

    def version!
      nonnegative_integer!(params[:lock_version], "lock_version")
    end

    def source_version!
      raise ArgumentError, "This action requires an event publication." if @publication.story?
      nonnegative_integer!(params[:source_lock_version], "source_lock_version")
    end

    def nonnegative_integer!(value, name)
      raise ArgumentError, "#{name} must be a nonnegative JSON integer." unless value.is_a?(Integer) && value >= 0
      value
    end

    def boolean!(name)
      return false unless params.key?(name)
      value = params[name]
      raise ArgumentError, "#{name} must be a JSON boolean." unless value == true || value == false
      value
    end

    def render_publication(status: :ok)
      render json: { website_publication: publication_payload(@publication.reload) }, status: status
    end

    def publication_payload(record)
      source = record.calendar_event
      {
        id: record.id, public_id: record.public_id, kind: record.kind, status: record.status,
        lock_version: record.lock_version, draft: record.draft.except("consent_draft"), snapshot: record.snapshot,
        consent: record.consent, consent_note: record.consent_note, consent_covers_draft: record.consent_covers_draft?,
        featured_position: record.featured_position, eligibility_reason: record.eligibility_reason,
        eligibility_source_version: record.eligibility_source_version, published_source_version: record.published_source_version,
        calendar_event_id: record.calendar_event_id, original_calendar_event_id: record.original_calendar_event_id,
        source: source ? {
          id: source.id, lock_version: source.lock_version, title: source.title, description: source.description,
          visibility: source.visibility, website_designation: source.website_designation,
          calendar_category: source.calendar_category, title_flag: record.title_flag,
          stored_internal_category: WebsitePublication::INTERNAL_CATEGORIES.include?(source.calendar_category),
          **record.source_fields.symbolize_keys
        } : nil,
        timezone: organization.calendar_time_zone.name, pending_source_changes: record.pending_source_changes?,
        draft_portrait: portrait_paths(record, record.draft["portrait_revision"]),
        snapshot_portrait: portrait_paths(record, record.snapshot["portrait_revision"]),
        history_path: "/api/website_publications/#{record.id}/history",
        public_path: "/public/v1/#{record.story? ? 'member_stories' : 'events'}/#{record.public_id}",
        updated_at: record.updated_at.iso8601(6)
      }
    end

    def portrait_paths(record, revision)
      return nil unless record.story? && revision
      %w[small large].index_with { |size| "/api/website_publications/#{record.id}/portrait/#{revision}/#{size}.webp" }
    end

    def featured_payload
      WebsitePublishing::Boundary.synchronize(organization.id) do
        stories = scope.where(kind: "story").order(:id).to_a
        {
          public_ids: stories.select(&:featured_position).sort_by(&:featured_position).map(&:public_id),
          versions: stories.to_h { |record| [ record.id.to_s, record.lock_version ] }
        }
      end
    end

    def render_conflict(error)
      render_error(error.message, status: :conflict)
    end

    def render_invalid(error)
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    end
  end
end
