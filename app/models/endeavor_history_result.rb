class EndeavorHistoryResult < ApplicationRecord
  include ImmutableEndeavorHistory
  belongs_to :endeavor
  belongs_to :endeavor_history_run
  validates :stage, inclusion: { in: %w[discovery summary] }
  validates :fingerprint, :input, :candidate, :verification, :configuration, presence: true
  validate :same_endeavor

  private

  def same_endeavor
    errors.add(:endeavor_history_run, "must belong to this Endeavor") if endeavor_history_run && endeavor_history_run.endeavor_id != endeavor_id
  end
end
