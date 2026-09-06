class EndeavorHistoryGuidance < ApplicationRecord
  include ImmutableEndeavorHistory
  belongs_to :endeavor
  belongs_to :author, class_name: "User"
  validates :body, length: { maximum: 4000 }
end
