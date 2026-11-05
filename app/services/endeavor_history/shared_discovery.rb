module EndeavorHistory
  class SharedDiscovery
    # Pending consumers do not own recovery authority or spend reservations.
    class Waiting < StandardError; end

    def self.targets(organization)
      organization.endeavors.where(history_withdrawn: false).order(:id).map do |endeavor|
        guidance = endeavor.history_guidances.order(id: :desc).first
        { "id" => endeavor.id, "title" => endeavor.title, "summary" => endeavor.summary,
          "guidance_id" => guidance&.id, "guidance" => guidance&.body.to_s, "generation" => endeavor.history_generation }
      end
    end

    def initialize(run, input)
      @run = run
      @input = input
      @organization = run.endeavor.organization
      @fingerprint = Sources.digest(input.merge("organization_id" => @organization.id,
        "normalization_version" => SourceDocument::VERSION, "quality_policy" => Sources::QUALITY_POLICY,
        "configuration" => %w[shared_discovery verify_shared_discovery].index_with { |stage| Config.stage_signature(stage) }))
    end

    def fetch
      # Session locks release on connection loss. No transaction/row lock spans AI calls.
      ApplicationRecord.connection_pool.with_connection do |connection|
        key = Digest::SHA256.hexdigest("endeavor-history:#{@fingerprint}")[0, 15].to_i(16)
        locked = ApplicationRecord.uncached { connection.select_value("SELECT pg_try_advisory_lock(#{key})") }
        raise Waiting unless locked
        begin
          discovery = EndeavorHistoryDiscovery.create_or_find_by!(organization: @organization, fingerprint: @fingerprint) do |record|
            record.input = @input
          end
          return discovery.result if discovery.result
          claim!(discovery)
          begin
            result = yield
            discovery.update!(owner_run: result.endeavor_history_run, result: result, error_category: nil)
            result
          rescue Error => error
            discovery.update!(error_category: error.category)
            raise
          end
        ensure
          connection.execute("SELECT pg_advisory_unlock(#{key})")
        end
      end
    end

    private

    def claim!(discovery)
      owner = discovery.owner_run
      if owner && owner.id != @run.id
        same_recovery = owner.endeavor_id == @run.endeavor_id && Requests.retry_root(owner) == Requests.retry_root(@run)
        unless same_recovery
          latest = Requests.latest_attempt(owner)
          raise Waiting if !latest.terminal? || Requests.recoverable?(latest)
          raise Error, "shared_discovery_failed"
        end
      end
      discovery.update!(owner_run: @run, error_category: nil)
    end
  end
end
