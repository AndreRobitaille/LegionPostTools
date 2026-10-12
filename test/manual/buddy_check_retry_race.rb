raise "Synthetic isolated test database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "legion_buddy_race_test"
raise "Use an empty synthetic database" if User.exists? || Organization.exists?
organization = Organization.create!(name: "Synthetic race Post", unit_type: "american_legion_post", timezone: "America/Chicago")
user = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Caller"), email_address: "race@example.com")
person = Person.create!(first_name: "Synthetic", last_name: "Recipient")
payload = { operation_id: SecureRandom.uuid, person_id: person.id,
  facts: { channel: "phone", outcome: "reached", occurred_at: 1.minute.ago.iso8601(6), entry_zone: "America/Chicago" } }
ready, release, pid = Queue.new, Queue.new, Queue.new
first = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do
    owner = User.find(user.id)
    owner.with_lock do
      ready << true
      raise "Timeout waiting to release first writer" unless release.pop(timeout: 15)
      BuddyChecks::Operations.new(BuddyChecks::Access.new(user: owner, organization:)).record(**payload)
    end
  end
end
second = nil
begin
  raise "First writer did not acquire lock" unless ready.pop(timeout: 15)
  second = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("SET lock_timeout = '15s'")
      pid << connection.select_value("SELECT pg_backend_pid()")
      BuddyChecks::Operations.new(BuddyChecks::Access.new(user: User.find(user.id), organization:)).record(**payload)
    end
  end
  backend_pid = pid.pop(timeout: 15) || raise("Second writer did not start")
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
  waiting = false
  until Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    waiting = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}") } == "Lock"
    break if waiting || !second.alive?
    sleep 0.01
  end
  raise "Second writer did not wait on the real database lock" unless waiting
ensure
  release << true
  raise "First writer did not finish" unless first.join(20)
  raise "Second writer did not finish" if second && !second.join(20)
end
raise "Receipts differ" unless first.value == second.value
raise "Duplicate accepted work" unless MembershipContact.count == 1 && BuddyOperation.count == 1
operations = BuddyChecks::Operations.new(BuddyChecks::Access.new(user: User.find(user.id), organization:))
begin
  operations.record(**payload.deep_merge(facts: { outcome: "wrong_number" }))
  raise "Changed payload reused an accepted operation"
rescue BuddyChecks::Conflict => error
  raise unless error.message == "operation_payload_conflict"
end
raise "Changed-payload conflict mutated history" unless MembershipContact.count == 1 && MembershipContact.sole.outcome == "reached"
puts "PASS: second PostgreSQL writer waited for the first; both returned the identical receipt; one contact and operation survived; changed payload conflicted without mutation."
