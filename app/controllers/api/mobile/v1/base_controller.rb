module Api
  module Mobile
    module V1
      class BaseController < ActionController::API
        wrap_parameters false
        before_action :authenticate_mobile
        rescue_from ActiveRecord::RecordNotFound, with: -> { error("not_found", :not_found) }
        rescue_from BuddyChecks::Denied, with: ->(exception) { error(exception.message, :forbidden) }
        rescue_from BuddyChecks::Conflict, ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique,
          with: ->(exception) { error(exception.is_a?(BuddyChecks::Conflict) ? exception.message : "stale_revision", :conflict) }
        rescue_from ArgumentError, TypeError, KeyError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid,
          with: ->(_exception) { error("invalid_request", :unprocessable_entity) }

        private

        def authenticate_mobile
          response.headers["Cache-Control"] = "no-store"
          return error("unavailable", :service_unavailable) unless BuddyChecks::Configuration.enabled? && BuddyChecks::Configuration.origin?(request)
          scheme, secret = request.headers["Authorization"].to_s.split(" ", 2)
          @token = Doorkeeper::AccessToken.by_token(secret) if scheme&.casecmp?("Bearer") && secret.present?
          user = User.find_by(id: @token&.resource_owner_id, disabled_at: nil)
          unless @token && @token.scopes.to_s == "buddy_check" && BuddyChecks::Configuration.client?(@token.application)
            return error("invalid_session", :unauthorized)
          end
          return error("revoked_session", :unauthorized) if @token.revoked?
          return error("account_unavailable", :unauthorized) unless user
          return error("expired_session", :unauthorized) if @token.expired?
          return error("account_unavailable", :forbidden) unless user.mobile_buddy_checks_access?
          @access = BuddyChecks::Access.new(user:, organization: Organization.first!)
          @operations = BuddyChecks::Operations.new(@access)
        end

        def error(code, status)
          render json: { error: { code: } }, status:
        end

        def payload
          @payload ||= begin
            raw = request.request_parameters
            allowed = {
              "create" => %w[operation_id person_id facts follow_up assignment_id],
              "correct" => %w[operation_id expected_revision facts],
              "schedule" => %w[operation_id person_id due_at entry_zone],
              "change_follow_up" => %w[operation_id expected_revision action due_at entry_zone],
              "snooze" => %w[operation_id person_id until_at],
              "undo_snooze" => %w[operation_id expected_revision]
            }.fetch(action_name)
            raise ArgumentError unless (raw.keys - allowed).empty?
            raw.deep_symbolize_keys
          end
        end

        def page(scope)
          limit = Integer(params.fetch(:limit, 25).to_s, 10)
          cursor = Integer(params.fetch(:cursor, 0).to_s, 10)
          raise ArgumentError unless limit.between?(1, 50) && cursor >= 0
          rows = scope.where("#{scope.klass.table_name}.id > ?", cursor).order(:id).limit(limit + 1).to_a
          more = rows.size > limit
          rows = rows.first(limit)
          { items: rows.map { |row| yield row }, next_cursor: more ? rows.last.id.to_s : nil }
        end
      end
    end
  end
end
