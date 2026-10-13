module Membership
  class DrivesController < BaseController
    before_action :require_membership_manager, only: %i[new create update]

    def index
      @purpose = params[:purpose].presence_in(MembershipDrive::PURPOSES.keys)
      @buddy_task = @purpose == "buddy_check"
      @drives = @access.drives.order(created_at: :desc)
      if @buddy_task
        @drives = @drives.where(purpose: "buddy_check")
      else
        @drives = @drives.where(membership_year: @membership_year).where.not(purpose: "buddy_check")
        @drives = @drives.where(purpose: @purpose) if @purpose
      end
    end

    def new
      @drive = @organization.membership_drives.new(membership_year: @membership_year, starts_on: Organization.current_local_date,
        ends_on: Organization.current_local_date + 30.days, purpose: params[:purpose].presence_in(MembershipDrive::PURPOSES.keys) || "renewal")
    end

    def create
      @drive = @organization.membership_drives.new(params.expect(membership_drive: [ :title, :purpose, :starts_on, :ends_on, :script ]))
      @drive.assign_attributes(created_by: current_user, membership_year: @membership_year)
      @drive.save!
      redirect_to membership_drive_path(@drive, membership_year: @drive.membership_year), notice: @drive.purpose == "buddy_check" ? "Buddy Check drive created." : "Membership drive created.", status: :see_other
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def show
      load_drive_context
    end

    def update
      @drive = @access.drives.find(params[:id])
      @drive.update!(closed_at: Time.current, lock_version: params.require(:lock_version))
      redirect_to membership_drive_path(@drive, membership_year: @drive.membership_year), notice: "Drive closed. Its records are preserved.", status: :see_other
    end

    def print
      @drive = permitted_drive
      pdf = MembershipPdf.render(organization: @organization, user: current_user, drive: @drive, caller_id: params[:caller_id])
      send_data pdf, filename: "membership-drive-#{@drive.id}-#{@drive.membership_year}.pdf", type: "application/pdf", disposition: "inline"
    rescue MembershipPdf::GenerationError
      redirect_to membership_drive_path(@drive, membership_year: @drive.membership_year), alert: "The call sheet PDF could not be created. Try again."
    end

    private

    def load_drive_context
      @drive = permitted_drive
      @workspace = MembershipWorkspace.new(user: current_user, organization: @organization, membership_year: @drive.membership_year)
      @access = @workspace.access
      @membership_year = @drive.membership_year
      @assignments = @access.drive_assignments(@drive)
      return unless @access.manager?

      @callers = User.where(disabled_at: nil).includes(:person).order(:email_address)
      assigned_ids = @drive.assignments.where(revoked_at: nil).pluck(:person_id)
      @candidates = @workspace.people.reject do |person|
        assigned_ids.include?(person.id) || !@workspace.eligible_for_drive?(person, @drive)
      end
    end

    def permitted_drive
      MembershipAccess.new(user: current_user, organization: @organization).drives.find(params[:id] || params[:drive_id])
    end
  end
end
