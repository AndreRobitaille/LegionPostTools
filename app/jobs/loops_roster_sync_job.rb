class LoopsRosterSyncJob < ApplicationJob
  queue_as :default

  def perform(loops_roster_sync)
    Loops::RosterSynchronizer.new(loops_roster_sync).call
  end
end
