require "test_helper"
require_relative "../../support/buddy_checks_helpers"

class BuddyChecksProvisioningTest < ActiveSupport::TestCase
  include BuddyChecksHelpers
  setup do
    setup_buddy_checks
    @other.permission_grants.where(capability: "use_mobile_buddy_checks").destroy_all
    @old_callback = ENV["MOBILE_BUDDY_CHECK_REDIRECT_URI"]
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = "https://members.example.test"
    ENV["MOBILE_BUDDY_CHECK_CLIENT_ID"] = "org.wipost165.buddychecks"
    ENV["MOBILE_BUDDY_CHECK_REDIRECT_URI"] = "org.wipost165.buddychecks:/oauth/callback"
  end
  teardown do
    restore_buddy_configuration
    @old_callback ? ENV["MOBILE_BUDDY_CHECK_REDIRECT_URI"] = @old_callback : ENV.delete("MOBILE_BUDDY_CHECK_REDIRECT_URI")
  end

  test "activation registers a secretless public client and only the requested export grant exactly once" do
    before_user = @other.attributes
    before_contacts = MembershipContact.count
    2.times { BuddyChecks::Provisioning.activate!(email: @other.email_address) }
    client = Doorkeeper::Application.find_by!(uid: "org.wipost165.buddychecks")
    assert_equal "org.wipost165.buddychecks:/oauth/callback", client.redirect_uri
    assert_equal "buddy_check", client.scopes.to_s
    assert_not client.confidential?
    assert_nil client.secret
    assert_equal %w[export_buddy_contacts use_mobile_buddy_checks], @other.permission_grants.order(:capability).pluck(:capability)
    assert_equal before_user, @other.reload.attributes
    assert_equal before_contacts, MembershipContact.count
    assert_not @other.full_membership_access?
    assert_not @volunteer.can?("export_buddy_contacts")
    assert_equal 0, Doorkeeper::AccessToken.count
    assert_equal 0, BuddyOperation.count
  end

  test "incompatible existing registration is preserved and no grant is created" do
    client = Doorkeeper::Application.create!(uid: ENV.fetch("MOBILE_BUDDY_CHECK_CLIENT_ID"),
      name: "Existing client", redirect_uri: "org.other:/callback", scopes: "buddy_check", confidential: false)
    before_client = client.attributes
    assert_raises(ArgumentError) { BuddyChecks::Provisioning.activate!(email: @other.email_address) }
    assert_equal before_client, client.reload.attributes
    assert_not @other.can?("export_buddy_contacts")
  end

  test "disabled user missing account insecure issuer and disabled feature leave registration untouched" do
    @other.update!(disabled_at: Time.current)
    assert_raises(ActiveRecord::RecordNotFound) { BuddyChecks::Provisioning.activate!(email: @other.email_address) }
    assert_raises(ActiveRecord::RecordNotFound) { BuddyChecks::Provisioning.activate!(email: "missing@example.test") }
    @other.update!(disabled_at: nil)
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = "http://members.example.test"
    assert_raises(ArgumentError) { BuddyChecks::Provisioning.activate!(email: @other.email_address) }
    ENV["MOBILE_BUDDY_CHECK_ISSUER"] = "https://members.example.test"
    ENV["MOBILE_CONTACT_EXPORT_ENABLED"] = "false"
    assert_raises(ArgumentError) { BuddyChecks::Provisioning.activate!(email: @other.email_address) }
    assert_nil Doorkeeper::Application.find_by(uid: "org.wipost165.buddychecks")
    assert_not @other.can?("export_buddy_contacts")
  end
end
