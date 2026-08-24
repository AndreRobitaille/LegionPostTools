module Loops
  class RosterSynchronizer
    REQUEST_INTERVAL = 0.12

    def initialize(roster_sync, client: nil, sleeper: ->(seconds) { sleep(seconds) })
      @roster_sync = roster_sync
      @client = client
      @sleeper = sleeper
    end

    def call
      return unless start!

      audience = RosterAudience.new
      @roster_sync.update!(audience.counts)
      failures = []
      synced_count = 0
      client = @client || Client.new

      client.open do |session|
        audience.contacts.each_with_index do |contact, index|
          @sleeper.call(REQUEST_INTERVAL) if index.positive?

          begin
            session.update_contact(contact.payload)
            synced_count += 1
          rescue Client::RequestError => error
            failures << failure_for(contact, error)
          ensure
            @roster_sync.update_columns(
              synced_count: synced_count,
              failed_count: failures.size,
              failures: failures,
              updated_at: Time.current
            )
          end
        end
      end

      @roster_sync.update!(
        status: "completed",
        synced_count: synced_count,
        failed_count: failures.size,
        failures: failures,
        finished_at: Time.current
      )
    rescue StandardError => error
      fail_sync!(error)
    end

    private

    def start!
      started = false
      @roster_sync.with_lock do
        next unless @roster_sync.status == "queued"

        latest_import = RosterImport.latest_successful
        if latest_import != @roster_sync.roster_import
          @roster_sync.update!(
            status: "failed",
            error_message: "A newer roster import is available. Review it before starting another Loops sync.",
            finished_at: Time.current
          )
        else
          @roster_sync.update!(status: "running", started_at: Time.current)
          started = true
        end
      end
      started
    end

    def failure_for(contact, error)
      {
        "name" => contact.person.roster_display_name,
        "member_number" => contact.person.member_number,
        "email" => contact.email,
        "message" => error.message,
        "status" => error.status
      }
    end

    def fail_sync!(error)
      return unless @roster_sync.persisted? && @roster_sync.status.in?(%w[queued running])

      @roster_sync.update!(
        status: "failed",
        error_message: error.message,
        finished_at: Time.current
      )
    end
  end
end
