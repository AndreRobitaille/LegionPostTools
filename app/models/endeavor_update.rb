class EndeavorUpdate < ApplicationRecord
  belongs_to :endeavor, inverse_of: :updates
  belongs_to :author, class_name: "User"
  has_rich_text :body

  validates :body, presence: true

  before_update :prevent_changes
  before_destroy :prevent_changes

  private

  def prevent_changes
    errors.add(:base, "Endeavor updates are append-only")
    throw(:abort)
  end
end
