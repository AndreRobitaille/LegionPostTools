module Admin
  class UserAccountsController < BaseController
    def create
      @person = Person.find(params[:person_id])
      email_address = params.dig(:user, :email_address).presence || @person.roster_email_address

      if email_address.blank?
        redirect_to person_path(@person), alert: "Enter a login email address before creating the account."
        return
      end

      if (user = @person.user)
        user.update!(email_address: email_address, disabled_at: nil)
      else
        User.create!(person: @person, email_address: email_address, email_verified_at: Time.current)
      end

      redirect_to person_path(@person), notice: "Login account is enabled."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to person_path(@person), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      @person = Person.find(params[:person_id])
      user = @person.user

      if user&.disabled_at.blank? && user.can?("manage_settings") && !another_enabled_manage_settings_user_exists?(user)
        redirect_to person_path(@person), alert: "At least one enabled administrator account is required."
        return
      end

      user&.update!(disabled_at: Time.current)

      redirect_to person_path(@person), notice: "Login account is disabled."
    end

    private

    def another_enabled_manage_settings_user_exists?(user)
      User.where(disabled_at: nil)
        .where.not(id: user.id)
        .joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" })
        .exists?
    end
  end
end
