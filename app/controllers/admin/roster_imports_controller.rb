module Admin
  class RosterImportsController < BaseController
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
      else
        redirect_to admin_roster_import_path(result.roster_import), alert: "Roster import could not be completed."
      end
    end

    def show
      @roster_import = RosterImport.find(params[:id])
      @problems = Array(@roster_import.summary&.fetch("problems", nil))
    end
  end
end
