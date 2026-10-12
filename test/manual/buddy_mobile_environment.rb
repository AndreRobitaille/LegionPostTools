require "uri"

buddy_databases = %w[legion_buddy_mobile_test legion_buddy_authority_test legion_buddy_authority_verify_test legion_buddy_remembered_test]
raise "Synthetic test database required" unless Rails.env.test? && buddy_databases.map { |name| "postgresql:///#{name}" }.include?(ENV["DATABASE_URL"])
buddy_origin = URI.parse(ENV.fetch("MOBILE_BUDDY_CHECK_ISSUER"))
raise "An exact HTTPS origin is required" unless buddy_origin.scheme == "https" && buddy_origin.host.present? &&
  buddy_origin.path.empty? && buddy_origin.query.nil? && buddy_origin.fragment.nil? && buddy_origin.userinfo.nil?
ENV["MAIL_PROVIDER"] = "action_mailer"

# Replace only the delivery transport: the normal email/code sign-in still runs.
# This private synthetic inbox also works with an ephemeral iOS browser session.
class BuddyMobileFileMail
  def deliver_magic_link(user:, login_url:, login_code:)
    raise MailDelivery::DeliveryError, "Synthetic account required" unless %w[jamie@example.test riley@example.test].include?(user.email_address)
    directory = File.join(File.dirname(ENV.fetch("BUDDY_MOBILE_FIXTURE_FILE")), "mail")
    FileUtils.mkdir_p(directory, mode: 0o700)
    File.write(File.join(directory, "#{user.id}.json"), JSON.pretty_generate({ email: user.email_address,
      login_url:, login_code:, expires_at: MagicLink::TOKEN_TTL.from_now.iso8601 }), perm: 0o600)
  end
end

Rails.application.configure do
  config.action_controller.allow_forgery_protection = true
  config.consider_all_requests_local = false
  config.action_dispatch.show_exceptions = :all
  config.force_ssl = true
  config.ssl_options = { hsts: false }
  config.hosts = [ buddy_origin.host ]
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: buddy_origin.host, port: buddy_origin.port, protocol: "https" }
  config.active_job.queue_adapter = :test
  config.log_level = :warn
  config.log_file_size = 10.megabytes
  config.after_initialize { MailDelivery.backend = BuddyMobileFileMail.new }
end
