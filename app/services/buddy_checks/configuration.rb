module BuddyChecks
  module Configuration
    def self.enabled?
      ENV["MOBILE_BUDDY_CHECK_ENABLED"] == "true"
    end

    def self.export_enabled?
      enabled? && ENV["MOBILE_CONTACT_EXPORT_ENABLED"] == "true"
    end

    def self.issuer
      ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER", "")
    end

    def self.client_id
      ENV.fetch("MOBILE_BUDDY_CHECK_CLIENT_ID", "")
    end

    def self.client?(application)
      application && !application.confidential? && client_id.present? && application.uid == client_id &&
        application.scopes.to_s == "buddy_check"
    end

    def self.origin?(request)
      configured = URI.parse(issuer)
      configured.host.present? && configured.path.to_s.in?([ "", "/" ]) && configured.query.nil? &&
        configured.fragment.nil? && configured.userinfo.nil? &&
        (configured.scheme == "https" || (!Rails.env.production? && configured.scheme == "http")) &&
        request.base_url == issuer.delete_suffix("/")
    rescue URI::InvalidURIError
      false
    end
  end
end
