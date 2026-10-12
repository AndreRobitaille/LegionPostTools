module BuddyChecks
  class Provisioning
    def self.activate!(email:)
      raise ArgumentError, "Mobile Buddy Checks and Contacts export must be explicitly enabled" unless Configuration.export_enabled?
      issuer = URI.parse(Configuration.issuer)
      raise ArgumentError, "Configure one exact HTTPS origin" unless issuer.scheme == "https" && issuer.host.present? &&
        issuer.path.empty? && issuer.query.nil? && issuer.fragment.nil? && issuer.userinfo.nil?
      uid = Configuration.client_id
      redirect_uri = ENV.fetch("MOBILE_BUDDY_CHECK_REDIRECT_URI")
      callback = URI.parse(redirect_uri)
      raise ArgumentError, "Configure a public client ID and exact native callback" unless uid.present? &&
        callback.scheme.present? && callback.scheme != "http" && callback.scheme != "https" &&
        callback.path.present? && callback.query.nil? && callback.fragment.nil? && callback.userinfo.nil?
      Organization.first!
      user = User.find_by!(email_address: email.to_s.strip.downcase, disabled_at: nil)

      Doorkeeper::Application.transaction do
        client = Doorkeeper::Application.find_or_initialize_by(uid:)
        if client.new_record?
          client.assign_attributes(name: "Buddy Checks for iPhone", redirect_uri:, scopes: "buddy_check", confidential: false)
          client.save!
        end
        raise ArgumentError, "Existing mobile client differs; review its registration before activation" unless
          Configuration.client?(client) && client.redirect_uri == redirect_uri && client.secret.nil?
        %w[use_mobile_buddy_checks export_buddy_contacts].each do |capability|
          user.permission_grants.find_or_create_by!(capability:)
        end
        { client_id: client.uid, redirect_uri: client.redirect_uri, scope: client.scopes.to_s,
          public_client: !client.confidential?, client_secret: false, user_id: user.id,
          pilot_access: user.mobile_buddy_checks_access?, contacts_export: user.can?("export_buddy_contacts"),
          reviewed_address_access: user.full_membership_access? }
      end
    end
  end
end
