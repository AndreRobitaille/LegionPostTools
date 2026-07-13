module Admin
  class AdministratorsController < BaseController
    def index
      @administrators = User.where(disabled_at: nil).joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" }).includes(:person).distinct
    end
  end
end
