# Test-only server and offline mailbox for goal-based browser role exercises.
require_relative "../config/environment"
require "fileutils"
require "rackup"

raise "Isolated role walkthrough database required" unless Rails.env.test? &&
  ActiveRecord::Base.connection_db_config.database == "legion_post_tools_role_walkthrough_test"
raise "Prepare the synthetic pilot first" unless Organization.first&.name == "Harbor Post 204 (synthetic walkthrough)"

class RoleWalkthroughMailQueue
  def enqueue(job)
    raise "This walkthrough executes only offline email jobs" unless job.is_a?(ActionMailer::MailDeliveryJob)

    job.perform_now
  end

  def enqueue_at(*)
    raise "Scheduled jobs are outside this walkthrough"
  end
end

class RoleWalkthroughMailbox
  def self.delivering_email(message)
    recipients = message.destinations
    raise "Only synthetic recipients allowed" unless recipients.any? && recipients.all? { |address| address.match?(/\A[a-z]+@example\.test\z/) }

    recipients.each do |address|
      body = message.text_part ? message.text_part.body.decoded : message.body.decoded
      File.write(File.join(ENV.fetch("ROLE_WALKTHROUGH_OUTPUT"), "mailbox", "#{address}.txt"), body, mode: "w", perm: 0o600)
    end
  end
end

ENV["ENDEAVOR_HISTORY_ENABLED"] = "0"
FileUtils.mkdir_p(File.join(ENV.fetch("ROLE_WALKTHROUGH_OUTPUT"), "mailbox"), mode: 0o700)
ActiveJob::Base.queue_adapter = RoleWalkthroughMailQueue.new
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.register_interceptor(RoleWalkthroughMailbox)
port = Integer(ENV.fetch("ROLE_WALKTHROUGH_PORT", "3095"))
ActionMailer::Base.default_url_options = { host: "localhost", port: }
if $PROGRAM_NAME == __FILE__
  Rackup::Handler.get("puma").run(Rails.application, Host: "0.0.0.0", Port: port, environment: "test")
end
