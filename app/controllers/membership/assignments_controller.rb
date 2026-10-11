module Membership
  class AssignmentsController < DrivesController
    before_action :require_membership_manager

    def create
      @drive = @organization.membership_drives.find(params[:drive_id])

      attributes = params.expect(assignment: [ :assigned_to_id, :expires_on, person_ids: [] ])
      ids = Array(attributes[:person_ids]).reject(&:blank?).uniq
      raise ArgumentError, "Choose at least one member." if ids.empty?

      @drive.with_lock do
        raise MembershipWorkspace::Conflict, "This drive is closed." if @drive.closed_at

        @workspace = MembershipWorkspace.new(user: current_user, organization: @organization, membership_year: @drive.membership_year)
        ids.each do |id|
          person = @workspace.person(id)
          unless @workspace.eligible_for_drive?(person, @drive)
            raise MembershipWorkspace::Conflict, "#{person.roster_display_name} no longer needs this drive's contact. Review the current list."
          end
          @drive.assignments.create!(person:, assigned_to: User.where(disabled_at: nil).find(attributes[:assigned_to_id]),
            assigned_by: current_user, expires_on: attributes[:expires_on])
        end
      end
      redirect_to membership_drive_path(@drive, membership_year: @drive.membership_year), notice: "Members assigned.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @assignment_errors = error.record.errors.full_messages
      load_drive_context
      render "membership/drives/show", status: :unprocessable_entity
    end

    def update
      assignment = @access.assignments.where(membership_drive_id: params[:drive_id]).find(params[:id])
      assignment.update!(revoked_at: Time.current, lock_version: params.require(:lock_version))
      redirect_to membership_drive_path(assignment.membership_drive, membership_year: assignment.membership_drive.membership_year), notice: "Assignment revoked.", status: :see_other
    end
  end
end
