module Admin
  class LoopsRosterSyncsController < BaseController
    def new
      @roster_import = RosterImport.latest_successful
      @audience = Loops::RosterAudience.new
      @active_sync = LoopsRosterSync.active.recent.first
      @latest_sync = LoopsRosterSync.recent.first
      @loops_configured = Loops::Client.configured? && Organization.first!.minutes_distribution_setting&.groups_configured?
      @managed_removals = managed_removals
      @roster_stale = RosterImport.roster_stale?
    end

    def create
      roster_import = RosterImport.latest_successful
      unless roster_import
        redirect_to new_admin_roster_import_path, alert: "Import a roster before syncing the email audience."
        return
      end

      unless Loops::Client.configured? && Organization.first!.minutes_distribution_setting&.groups_configured?
        redirect_to new_admin_loops_roster_sync_path, alert: "Configure Loops and its two distinct email groups before syncing."
        return
      end

      if (active_sync = LoopsRosterSync.active.recent.first)
        redirect_to admin_loops_roster_sync_path(active_sync), alert: "A Loops roster sync is already in progress."
        return
      end

      unless params[:roster_import_id].to_s == roster_import.id.to_s
        redirect_to new_admin_loops_roster_sync_path, alert: "Review the latest roster preview before starting the sync."
        return
      end

      audience = Loops::RosterAudience.new
      if audience.eligible_count.zero? && managed_removals.zero?
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

    private

    def managed_removals
      settings = Organization.first!.minutes_distribution_setting
      return 0 unless settings&.groups_configured?

      Organization.first!.loops_roster_enrollments.where(list_id: settings.post_members_list_id, active: true)
        .where.not(email: Loops::RosterAudience.new.contacts.map(&:email)).count
    end
  end
end
