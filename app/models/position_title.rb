class PositionTitle < ApplicationRecord
  belongs_to :organization
  has_many :position_assignments, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :display_order, numericality: { only_integer: true }

  # Rewrites display_order to a contiguous 1-based sequence matching ordered_ids.
  # Raises ActiveRecord::RecordNotFound if any id is not one of the organization's
  # position titles, or if ordered_ids contains duplicates. Atomic.
  def self.reorder!(organization, ordered_ids)
    ids = Array(ordered_ids).map(&:to_i)
    titles = organization.position_titles.where(id: ids).index_by(&:id)
    raise ActiveRecord::RecordNotFound unless titles.length == ids.length

    transaction do
      ids.each_with_index do |id, index|
        titles.fetch(id).update!(display_order: index + 1)
      end
    end
  end
end
