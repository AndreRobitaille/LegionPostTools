module Admin
  class LoopsRosterSyncsController < BaseController
    def new
      @roster_import = RosterImport.latest_successful
      @audience = Loops::RosterAudience.new
      @active_sync = LoopsRosterSync.active.recent.first
      @latest_sync = LoopsRosterSync.recent.first
      @loops_configured = Loops::Client.configured?
      @roster_stale = RosterImport.roster_stale?
    end

    def create
      roster_import = RosterImport.latest_successful
      unless roster_import
        redirect_to new_admin_roster_import_path, alert: "Import a roster before syncing the email audience."
        return
      end

      unless Loops::Client.configured?
        redirect_to new_admin_loops_roster_sync_path, alert: "Loops is not configured for this installation."
        return
      end

      if (active_sync = LoopsRosterSync.active.recent.first)
        redirect_to admin_loops_roster_sync_path(active_sync), alert: "A Loops roster sync is already in progress."
        return
      end

      audience = Loops::RosterAudience.new
      if audience.eligible_count.zero?
        redirect_to new_admin_loops_roster_sync_path, alert: "No current members have a unique, usable roster email."
        return
      end

      roster_sync = LoopsRosterSync.create!(
        roster_import: roster_import,
        requested_by: current_user,
        **audience.counts
      )
      LoopsRosterSyncJob.perform_later(roster_sync)

      redirect_to admin_loops_roster_sync_path(roster_sync), notice: "Roster email sync started."
    rescue ActiveRecord::RecordNotUnique
      active_sync = LoopsRosterSync.active.recent.first
      redirect_to admin_loops_roster_sync_path(active_sync), alert: "A Loops roster sync is already in progress."
    end

    def show
      @roster_sync = LoopsRosterSync.find(params[:id])
    end
  end
end
