module ImmutableEndeavorHistory
  extend ActiveSupport::Concern
  included do
    before_update :prevent_history_mutation
    before_destroy :prevent_history_mutation
  end

  private

  def prevent_history_mutation
    errors.add(:base, "History evidence is append-only")
    throw :abort
  end
end
