module Admin
  class PermissionGrantsController < BaseController
    def update
      @user = User.find(params[:user_id])
      result = @user.replace_manual_permissions!(params.dig(:permission_grant, :capabilities))
      if result == :skipped_last_admin
        redirect_to person_path(@user.person), alert: "At least one enabled administrator account is required."
        return
      end

      redirect_to person_path(@user.person), notice: "Permissions updated."
    end
  end
end
