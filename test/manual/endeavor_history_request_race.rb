raise "Empty isolated synthetic database required" unless Rails.env.test? &&
  ActiveRecord::Base.connection_db_config.database == "legion_history_request_race_test" && !Organization.exists? && !User.exists?
require Rails.root.join("test/support/endeavor_history_provider")
ActiveJob::Base.queue_adapter = :test
ENV["ENDEAVOR_HISTORY_ENABLED"] = "1"
provider = EndeavorHistoryTestProvider.new
EndeavorHistory::Provider.define_singleton_method(:new) { provider }
organization = Organization.create!(name: "Synthetic concurrency Post", unit_type: "american_legion_post", timezone: "America/Chicago")
body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
officer = User.create!(person: Person.create!(first_name: "Synthetic", last_name: "Adjutant"), email_address: "history-race@example.test", email_verified_at: Time.current)
%w[attest_minutes manage_agendas].each { |capability| officer.permission_grants.create!(capability:) }
endeavor = organization.endeavors.create!(title: "Car Show", created_by: officer)
make_minutes = lambda do |number|
  meeting = organization.meetings.create!(meeting_body: body, starts_at: number.hours.ago, title: "Synthetic meeting #{number}", location_name: "Test Hall")
  minutes = MeetingMinutes.create_from_meeting!(meeting: meeting)
  minutes.sections.first.items.create!(title: "Car Show", behavior_type: "report_slot", position: 1, body: "Volunteers for plan #{number}.")
  minutes
end
attest = lambda do |minutes|
  confirmation = OfficialActionConfirmation.record_external!(minutes: minutes, user: officer, action: "attest", evidence_note: "Synthetic concurrency check.")
  minutes.attest_with_confirmation!(confirmation: confirmation)
end
minutes = make_minutes.call(3)
attest.call(minutes)
request = EndeavorHistory::Requests.latest(endeavor)
ready, release, pid = Queue.new, Queue.new, Queue.new
first = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do
    Endeavor.find(endeavor.id).with_lock do
      ready << true
      raise "First writer release timed out" unless release.pop(timeout: 15)
      EndeavorHistoryRefreshJob.perform_now(endeavor.id, request.id)
    end
  end
end
raise "First writer did not lock" unless ready.pop(timeout: 15)
second = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    connection.execute("SET lock_timeout = '15s'")
    pid << connection.select_value("SELECT pg_backend_pid()")
    EndeavorHistoryRefreshJob.perform_now(endeavor.id, request.id)
  end
end
begin
  backend_pid = pid.pop(timeout: 15) || raise("Second writer did not start")
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
  waiting = false
  until Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    waiting = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value("SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}") } == "Lock"
    break if waiting || !second.alive?
    sleep 0.01
  end
  raise "Second request did not wait on the PostgreSQL lock" unless waiting
ensure
  release << true
  raise "First request hung" unless first.join(20)
  raise "Second request hung" unless second.join(20)
end
first.value
second.value
raise "Duplicate runs created" unless endeavor.history_runs.count == 1
run = endeavor.history_runs.sole
provider.alter = lambda do |stage, _input, _data|
  if stage == "discovery"
    ready << true
    raise "Worker release timed out" unless release.pop(timeout: 15)
  end
end
worker = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection { EndeavorHistoryJob.perform_now(run.id) }
end
raise "Worker did not reach provider" unless ready.pop(timeout: 15)
EndeavorHistoryJob.perform_now(run.id)
release << true
raise "Worker hung" unless worker.join(20)
worker.value
provider.alter = nil
raise "Duplicate paid stages or editions" unless provider.calls.length == 4 && endeavor.history_editions.count == 1 && run.reload.status == "succeeded"
puts "PASS: concurrent requests waited on PostgreSQL, created one run, and two workers made four offline calls and one edition."

# Both attestations deliberately capture manifests before either transaction commits.
later_minutes = [ make_minutes.call(2), make_minutes.call(1) ]
record_attestation = EndeavorHistory::Requests.method(:record_attestation)
EndeavorHistory::Requests.define_singleton_method(:record_attestation) do |record|
  record_attestation.call(record)
  ready << true
  raise "Attestation release timed out" unless release.pop(timeout: 15)
end
threads = later_minutes.map do |record|
  Thread.new do
    ActiveRecord::Base.connection_pool.with_connection { attest.call(MeetingMinutes.find(record.id)) }
  end
end
begin
  2.times { raise "Attestations did not overlap" unless ready.pop(timeout: 15) }
ensure
  2.times { release << true }
  threads.each { |thread| raise "Attestation hung" unless thread.join(20) }
  EndeavorHistory::Requests.define_singleton_method(:record_attestation, record_attestation)
end
threads.each(&:value)
provider.calls.clear
3.times do
  EndeavorHistoryReconcileJob.perform_now(organization.id)
  ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job[:job] == EndeavorHistoryRefreshJob }.each do |job|
    EndeavorHistoryRefreshJob.perform_now(*job[:args])
  end
  endeavor.history_runs.where(status: "pending").each { |pending| EndeavorHistoryJob.perform_now(pending.id) }
end
latest = endeavor.history_runs.recent.first
expected = later_minutes.map { |record| record.reload.member_revision.id }
raise "Overlapping sources lost" unless (expected - latest.manifest.fetch("revisions").pluck("id")).empty?
raise "Overlapping work duplicated or not published" unless latest.status == "succeeded" && endeavor.history_runs.count == 2 && endeavor.history_editions.count == 2 && provider.calls.length == 6
raise "Outstanding request lost" if EndeavorHistory::Requests.pending(endeavor)
puts "PASS: overlapping committed attestations with partial snapshots produced one current replacement, reused old evidence, and resolved both requests without extra paid stages."
