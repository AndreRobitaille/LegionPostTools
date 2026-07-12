module Admin
  class PermissionGrantsController < BaseController
    def update
      @user = User.find(params[:user_id])
      submitted_capabilities = Array(params.dig(:permission_grant, :capabilities)).map(&:to_s) & PermissionGrant::CAPABILITIES

      if removing_last_manage_settings_grant?(submitted_capabilities)
        redirect_to admin_person_path(@user.person), alert: "At least one enabled administrator account is required."
        return
      end

      PermissionGrant.transaction do
        @user.permission_grants.where.not(capability: submitted_capabilities).destroy_all
        submitted_capabilities.each do |capability|
          @user.permission_grants.find_or_create_by!(capability: capability)
        end
      end

      redirect_to admin_person_path(@user.person), notice: "Permissions updated."
    end

    private

    def removing_last_manage_settings_grant?(submitted_capabilities)
      return false unless @user.disabled_at.blank?
      return false unless @user.can?("manage_settings")
      return false if submitted_capabilities.include?("manage_settings")

      !User.where(disabled_at: nil)
        .where.not(id: @user.id)
        .joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" })
        .exists?
    end
  end
end
