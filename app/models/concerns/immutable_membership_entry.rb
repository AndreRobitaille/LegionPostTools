module ImmutableMembershipEntry
  extend ActiveSupport::Concern

  included do
    before_update :prevent_membership_entry_mutation
    before_destroy :prevent_membership_entry_mutation
  end

  private

  def prevent_membership_entry_mutation
    errors.add(:base, "Saved membership entries are preserved. Record a correction instead.")
    throw :abort
  end
end
