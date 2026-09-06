class EndeavorHistoryEdition < ApplicationRecord
  include ImmutableEndeavorHistory
  belongs_to :endeavor
  belongs_to :endeavor_history_run
  has_many :source_links, class_name: "EndeavorSourceLink", dependent: :restrict_with_exception
  validates :payload, :manifest, :sha256, presence: true
  validate do
    errors.add(:endeavor_history_run, "must describe this Endeavor") if endeavor_history_run&.endeavor_id != endeavor_id
  end
end
