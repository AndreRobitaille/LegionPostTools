namespace :buddy_checks do
  desc "Register the configured public iPhone client and explicitly grant one user's pilot and Contacts export"
  task :activate, [ :email ] => :environment do |_task, arguments|
    email = arguments[:email].presence || raise(ArgumentError, "An existing enabled user's email is required")
    puts BuddyChecks::Provisioning.activate!(email:).to_json
  end
end
