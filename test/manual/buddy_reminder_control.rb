require_relative "buddy_reminder_fixture"

control = BuddyReminderFixture.new
result = case ARGV.shift
when "setup" then control.setup!
when "status" then control.status
when "advance" then control.advance!(ARGV.shift, checkpoint: ARGV.shift)
else abort "Usage: ruby test/manual/buddy_authority.rb reminder setup|status|advance ACTION CHECKPOINT"
end
puts JSON.pretty_generate(result)
