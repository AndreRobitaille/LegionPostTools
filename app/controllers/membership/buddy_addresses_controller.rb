module Membership
  class BuddyAddressesController < BaseController
    before_action :require_membership_manager
    before_action -> { head :forbidden unless current_user.mobile_buddy_checks_access? }

    def show
      load_address
    end

    def create
      load_address
      @person.with_lock do
        raise MembershipWorkspace::Conflict, "The roster address changed. Reload and review it again." unless
          params[:source_digest] == BuddyAddressReview.source_digest(@person)
        BuddyAddressReview.create!(person: @person, reviewed_by: current_user, source_digest: params[:source_digest],
          source_note: params[:source_note], components: params.require(:components).permit(*BuddyAddressReview::FIELDS).to_h.reject { |_key, value| value.blank? })
      end
      redirect_to membership_buddy_address_path(@person), notice: "Reviewed address components saved.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @components = error.record.components
      @source_note = error.record.source_note
      flash.now[:alert] = error.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    private

    def load_address
      @person = Person.roster_backed.find(params[:id])
      @review = BuddyAddressReview.where(person: @person).order(id: :desc).first
      @components = @review&.current_source? ? @review.components : {}
    end
  end
end
