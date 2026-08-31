module Api
  class UserAccountsController < BaseController
    before_action -> { require_capability("manage_settings") }
    before_action :set_person

    def show
      render json: { user_account: user_account_payload(@person) }
    end

    def create
      email_address = params[:email_address].presence || @person.roster_email_address
      if email_address.blank?
        return render_error("Enter a login email address before creating the account.", status: :unprocessable_entity)
      end

      user = @person.user
      if user
        user.update!(email_address: email_address)
      else
        user = User.create!(person: @person, email_address: email_address)
      end

      result = if user.roster_managed?
        user.return_to_roster_control!
      else
        user.set_login_access_override!(disabled: false)
        :enabled_manually
      end
      render_account_result(user, result, status: :created)
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "The login account could not be enabled.")
    end

    def destroy
      user = @person.user || raise(ActiveRecord::RecordNotFound)
      result = user.set_login_access_override!(disabled: true)
      if result == :skipped_last_admin
        return render_error("At least one enabled administrator account is required.", status: :unprocessable_entity)
      end

      render_account_result(user, :disabled_manually)
    end

    def roster_control
      user = @person.user || raise(ActiveRecord::RecordNotFound)
      result = user.return_to_roster_control!
      case result
      when :skipped_last_admin
        render_error("At least one enabled administrator account is required.", status: :unprocessable_entity)
      when :not_roster_managed
        render_error("This local account has no National roster record to follow.", status: :unprocessable_entity)
      else
        render_account_result(user, result)
      end
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end

    def render_account_result(user, result, status: :ok)
      render json: {
        user_account: user_account_payload(@person.reload),
        access_result: result
      }, status: status
    end
  end
end
