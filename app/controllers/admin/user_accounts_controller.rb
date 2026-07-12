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
        user.set_login_access_override!(disabled: false)
      else
        User.create!(
          person: @person,
          email_address: email_address,
          email_verified_at: Time.current,
          login_access_override: true,
          login_access_override_at: Time.current
        )
      end

      redirect_to person_path(@person), notice: "Login account is enabled as an admin exception."
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

      redirect_to person_path(@person), notice: "Login account is disabled as an admin exception."
    end

    def roster_control
      @person = Person.find(params[:person_id])
      user = @person.user

      if user.blank?
        redirect_to person_path(@person), alert: "There is no login account to return to roster control."
        return
      end

      result = user.return_to_roster_control!
      if result == :skipped_last_admin
        redirect_to person_path(@person), alert: "At least one enabled administrator account is required."
      elsif result == :unsupported_status
        redirect_to person_path(@person), alert: "Roster status cannot be applied automatically."
      else
        redirect_to person_path(@person), notice: "Login account now follows roster status."
      end
    end
  end
end
