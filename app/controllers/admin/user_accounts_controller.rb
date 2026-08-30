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
        user.update!(email_address: email_address)
      else
        user = User.create!(
          person: @person,
          email_address: email_address
        )
      end

      if user.roster_managed?
        redirect_after_roster_managed_enable(user)
      else
        user.set_login_access_override!(disabled: false)
        redirect_to person_path(@person), notice: "Sign-in is on. This local account is managed manually because it has no National roster record."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to person_path(@person), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      @person = Person.find(params[:person_id])
      user = @person.user

      result = user&.set_login_access_override!(disabled: true)

      if result == :skipped_last_admin
        redirect_to person_path(@person), alert: "At least one enabled administrator account is required."
        return
      end

      redirect_to person_path(@person), notice: "Sign-in is off. Roster imports will leave it off until an administrator enables it again."
    end

    def roster_control
      @person = Person.find(params[:person_id])
      user = @person.user

      if user.blank?
        redirect_to person_path(@person), alert: "There is no login account to switch to roster-controlled sign-in."
        return
      end

      result = user.return_to_roster_control!
      if result == :skipped_last_admin
        redirect_to person_path(@person), alert: "At least one enabled administrator account is required."
      elsif result == :not_roster_managed
        redirect_to person_path(@person), alert: "This local account has no National roster record to follow."
      elsif result == :disabled_by_roster_status
        redirect_to person_path(@person), notice: "Sign-in now follows the National roster and is off because the current status is not eligible."
      else
        redirect_to person_path(@person), notice: "Sign-in now follows the National roster."
      end
    end

    private

    def redirect_after_roster_managed_enable(user)
      result = user.return_to_roster_control!

      case result
      when :enabled_by_roster_status
        redirect_to person_path(@person), notice: "Sign-in is on and will follow the National roster."
      when :disabled_by_roster_status
        redirect_to person_path(@person), alert: "The login email was saved, but sign-in stays off because this member is not active on the National roster."
      when :skipped_last_admin
        redirect_to person_path(@person), alert: "At least one enabled administrator account is required."
      end
    end
  end
end
