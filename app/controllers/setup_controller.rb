class SetupController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  before_action :redirect_if_already_configured

  def new
  end

  def create
    ApplicationRecord.transaction do
      organization = Organization.create!(organization_params.merge(unit_type: "american_legion_post"))
      AmericanLegionPostPreset.apply_to(organization) if params[:preset] == "american_legion_post"

      person = Person.create!(normalized_person_params)
      user = User.create!(person: person, email_address: person.email_address, email_verified_at: Time.current)

      PermissionGrant::CAPABILITIES.each do |capability|
        PermissionGrant.create!(user: user, capability: capability)
      end

      start_new_session_for(user)
    end

    redirect_to root_path, notice: "LegionPostTools is ready."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  def redirect_if_already_configured
    return unless Organization.exists? || User.exists?

    redirect_to root_path
  end

  def organization_params
    params.require(:organization).permit(:name, :unit_number, :timezone, :default_location_name, :default_location_address)
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :email_address)
  end

  def normalized_person_params
    attrs = person_params.to_h
    attrs[:email_address] = attrs[:email_address].to_s.strip.downcase
    attrs
  end
end
