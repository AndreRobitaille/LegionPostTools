module Admin
  class RosterImportsController < BaseController
    # Notices about sign-in access, shown apart from row-level CSV problems on the result page.
    ACCESS_NOTICE_KINDS = %w[last_admin unsupported_member_status].freeze

    def index
      @roster_imports = RosterImport.history
    end

    def new
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end

    def create
      roster_import_params = params[:roster_import]
      uploaded_file = roster_import_params.is_a?(ActionController::Parameters) ? roster_import_params[:file] : nil

      unless uploaded_file.respond_to?(:read) && uploaded_file.respond_to?(:original_filename)
        redirect_to new_admin_roster_import_path, alert: "Choose a roster CSV file to upload."
        return
      end

      result = RosterImports::Importer.new(
        csv_text: uploaded_file.read,
        filename: uploaded_file.original_filename
      ).import

      if result.success?
        redirect_to admin_roster_import_path(result.roster_import), notice: "Roster import completed."
      elsif result.roster_import&.status == "pending_confirmation"
        redirect_to admin_roster_import_path(result.roster_import), alert: "Roster import requires confirmation before continuing."
      else
        redirect_to admin_roster_import_path(result.roster_import), alert: "Roster import could not be completed."
      end
    end

    def show
      @roster_import = RosterImport.find(params[:id])
      @problems = @roster_import.normalized_problems
      @removed_members = @roster_import.removed_members
      @superseded = @roster_import.status == "pending_confirmation" && @roster_import.superseded?
      # Governance notices (last-admin protection, unsupported status) are shown apart from
      # row-level CSV problems so an important account notice isn't buried among data-entry typos.
      @access_notices, @row_problems = @problems.partition { |p| ACCESS_NOTICE_KINDS.include?(p["kind"]) }
    end

    def confirm
      roster_import = RosterImport.find(params[:id])

      result = nil
      alert = nil

      roster_import.with_lock do
        unless roster_import.status == "pending_confirmation" && roster_import.pending_csv.attached? && !roster_import.superseded?
          alert = "That roster import can no longer be confirmed."
          next
        end

        unless params[:confirm_large_removal] == "1"
          alert = "Confirm the large removal before applying this import."
          next
        end

        result = RosterImports::Importer.new(
          csv_text: roster_import.pending_csv.download,
          filename: roster_import.uploaded_filename,
          roster_import: roster_import,
          confirm_large_removal: true
        ).import
      end

      if alert.present?
        redirect_to admin_roster_import_path(roster_import), alert: alert
        return
      end

      if result.success?
        redirect_to admin_roster_import_path(result.roster_import), notice: "Roster import completed."
      else
        redirect_to admin_roster_import_path(result.roster_import), alert: "Roster import could not be completed."
      end
    end

    def discard
      roster_import = RosterImport.find(params[:id])

      roster_import.with_lock do
        next unless roster_import.status == "pending_confirmation"

        roster_import.pending_csv.purge_later
        roster_import.update!(status: "discarded")
      end

      redirect_to admin_roster_import_path(roster_import), notice: "Import discarded. No members were removed."
    end
  end
end
