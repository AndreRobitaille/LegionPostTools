class EndeavorHistoryDiscovery < ApplicationRecord
  belongs_to :organization
  belongs_to :owner_run, class_name: "EndeavorHistoryRun", optional: true
  belongs_to :result, class_name: "EndeavorHistoryResult", optional: true
  validates :fingerprint, :input, presence: true
  validate :matching_provenance

  private

  def matching_provenance
    if owner_run && owner_run.endeavor.organization_id != organization_id
      errors.add(:owner_run, "must belong to this organization")
    end
    if result && (result.endeavor_history_run_id != owner_run_id || result.stage != "shared_discovery" || result.input != input)
      errors.add(:result, "must be the owner's shared discovery result")
    end
  end
end
