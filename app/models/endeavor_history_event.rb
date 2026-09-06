class EndeavorHistoryEvent < ApplicationRecord
  include ImmutableEndeavorHistory
  belongs_to :endeavor
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :endeavor_history_run, optional: true
  validates :action, presence: true
end
