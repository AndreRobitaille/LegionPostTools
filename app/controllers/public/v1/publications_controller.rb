module Public
  module V1
    class PublicationsController < ActionController::API
      before_action :require_website_token
      before_action :read_only
      rate_limit to: 240, within: 1.minute, with: -> { response.set_header("Retry-After", "60"); error(429, "rate_limited", "Try again later") }
      rescue_from StandardError, with: :unavailable
      # Declare specific handlers last: Rails resolves them in reverse order.
      rescue_from ActiveRecord::RecordNotFound, with: -> { error(404, "not_found", "Not found") }

      def featured
        with_feed { |feed| json(feed.featured) }
      end

      def story
        with_feed { |feed| json(feed.story_detail(params[:id])) }
      end

      def events
        with_feed { |feed| json(feed.events(from: params[:from], to: params[:to])) }
      rescue ArgumentError
        error(400, "invalid_interval", "Supply from and to as dates spanning 1 to 93 days.")
      end

      def event
        with_feed { |feed| json(feed.event_detail(params[:id])) }
      end

      def portrait
        with_feed do |feed|
          bytes = feed.portrait(id: params[:id], revision: params[:revision], size: params[:size])
          represent(bytes, "image/webp")
        end
      end

      def missing
        error(404, "not_found", "Not found")
      end

      private

      def require_website_token
        response.set_header("Vary", "Authorization")
        scheme, credential = request.headers["Authorization"].to_s.split(" ", 2)
        @website_token = WebsiteAccessToken.authenticate(credential) if scheme&.casecmp?("Bearer")
        return if @website_token

        response.set_header("WWW-Authenticate", 'Bearer realm="website"')
        error(401, "unauthorized", "A valid website token is required")
      end

      def read_only
        return if request.get? || request.head?
        response.set_header("Allow", "GET, HEAD")
        error(405, "method_not_allowed", "Use GET or HEAD")
      end

      def with_feed
        raise "Publisher temporarily unavailable" if ENV["PUBLIC_PUBLISHER_UNAVAILABLE"] == "1"
        organization = @website_token.organization
        origin = ENV.fetch("PUBLIC_PUBLISHER_ORIGIN") { "https://#{ENV.fetch("APP_HOST")}" }
        uri = URI.parse(origin)
        unless uri.host && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? && uri.path.empty? && (uri.scheme == "https" || (!Rails.env.production? && uri.scheme == "http"))
          raise "Invalid publisher origin"
        end
        WebsitePublishing::Boundary.synchronize(organization.id) do
          yield WebsitePublishing::Feed.new(organization, origin: origin)
        end
      end

      def json(body)
        represent(ActiveSupport::JSON.encode(body), "application/json")
      end

      def represent(body, content_type)
        response.set_header("Cache-Control", "private, max-age=300, must-revalidate")
        response.set_header("Date", Time.current.httpdate)
        response.set_header("Age", "0")
        response.set_header("ETag", %Q("#{Digest::SHA256.hexdigest(body)}"))
        response.set_header("X-Content-Type-Options", "nosniff")
        response.set_header("Content-Type", content_type)
        if request.fresh?(response)
          head :not_modified
        else
          self.response_body = body
        end
      end

      def error(status, code, message)
        response.set_header("Cache-Control", "no-store")
        response.delete_header("ETag")
        render json: { schema_version: 1, error: { code: code, message: message } }, status: status
      end

      def unavailable(exception)
        Rails.logger.error("Public publisher unavailable: #{exception.class.name}")
        response.set_header("Retry-After", "60")
        error(503, "unavailable", "Temporarily unavailable")
      end
    end
  end
end
