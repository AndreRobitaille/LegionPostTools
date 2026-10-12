require_relative "membership_workspace_helpers"

module BuddyChecksHelpers
  include MembershipWorkspaceHelpers

  def setup_buddy_checks
    setup_membership_workspace
    @old_mobile_env = ENV.to_h.slice("MOBILE_BUDDY_CHECK_ENABLED", "MOBILE_BUDDY_CHECK_ISSUER", "MOBILE_BUDDY_CHECK_CLIENT_ID", "MOBILE_CONTACT_EXPORT_ENABLED")
    @mobile_client = Doorkeeper::Application.create!(name: "Synthetic Buddy Checks", redirect_uri: "org.example.buddy:/callback", scopes: "buddy_check", confidential: false)
    ENV["MOBILE_BUDDY_CHECK_ENABLED"] = "true"
    ENV["MOBILE_CONTACT_EXPORT_ENABLED"] = "true"
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = "http://www.example.com"
    ENV["MOBILE_BUDDY_CHECK_CLIENT_ID"] = @mobile_client.uid
    [ @officer, @other, @volunteer ].each { |user| user.permission_grants.create!(capability: "use_mobile_buddy_checks") }
  end

  def restore_buddy_configuration
    %w[MOBILE_BUDDY_CHECK_ENABLED MOBILE_BUDDY_CHECK_ISSUER MOBILE_BUDDY_CHECK_CLIENT_ID MOBILE_CONTACT_EXPORT_ENABLED].each do |key|
      @old_mobile_env&.key?(key) ? ENV[key] = @old_mobile_env[key] : ENV.delete(key)
    end
  end

  def mobile_access(user = @other)
    BuddyChecks::Access.new(user:, organization: @organization)
  end

  def operations(user = @other)
    BuddyChecks::Operations.new(mobile_access(user))
  end

  def mobile_headers(user = @other)
    @mobile_tokens ||= {}
    @mobile_tokens[user.id] ||= Doorkeeper::AccessToken.create!(application: @mobile_client, resource_owner_id: user.id, scopes: "buddy_check", expires_in: 900)
    { "Authorization" => "Bearer #{@mobile_tokens[user.id].plaintext_token}" }
  end

  def buddy_facts(**changes)
    { channel: "phone", outcome: "reached", occurred_at: 1.minute.ago.iso8601(6), entry_zone: "America/Chicago" }.merge(changes)
  end

  def buddy_payload(**changes)
    { operation_id: SecureRandom.uuid, person_id: @member.id, facts: buddy_facts }.merge(changes)
  end

  def buddy_meeting(days_ago: 5)
    body = @organization.meeting_bodies.find_or_create_by!(slug: "membership") { |record| record.name = "Membership Meeting" }
    create_meeting!(organization: @organization, meeting_body: body, starts_at: days_ago.days.ago)
  end
end
