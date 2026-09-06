namespace :endeavor_history do
  desc "Read-only inventory of current member-visible minutes and Endeavor processing"
  task inventory: :environment do
    Organization.find_each do |organization|
      organization.endeavors.order(:id).each do |endeavor|
        manifest = EndeavorHistory::Sources.new(endeavor).manifest
        puts({ organization_id: organization.id, endeavor_id: endeavor.id, revisions: manifest["revisions"],
          withdrawn: endeavor.history_withdrawn?, fingerprint: EndeavorHistory::Sources.digest(manifest),
          latest_status: endeavor.history_runs.recent.first&.status }.to_json)
      end
    end
  end

  desc "Enqueue a bounded history backfill after operator activation (AFTER_ID=0 LIMIT=10)"
  task backfill: :environment do
    limit = Integer(ENV.fetch("LIMIT", "10"))
    after = Integer(ENV.fetch("AFTER_ID", "0"))
    abort "LIMIT must be 1..25 and AFTER_ID nonnegative" unless limit.between?(1, 25) && after >= 0
    abort "Set ENDEAVOR_HISTORY_ENABLED=1 only after evaluating the pipeline and its budget" unless EndeavorHistory::Config.enabled?
    Endeavor.where("id > ?", after).order(:id).limit(limit).each do |endeavor|
      next if endeavor.history_withdrawn?
      begin
        run = EndeavorHistory::Processing.request(endeavor)
        puts({ endeavor_id: endeavor.id, run_id: run.id, status: run.status, next_after_id: endeavor.id }.to_json)
      rescue EndeavorHistory::Error => error
        puts({ endeavor_id: endeavor.id, error: error.category, next_after_id: endeavor.id }.to_json)
      end
    end
  end
end
