class CalendarEvent < ApplicationRecord
  VISIBILITIES = { "members" => "Members only", "public" => "Public" }.freeze

  belongs_to :organization
  belongs_to :endeavor, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  validates :endeavor, presence: true, if: -> { endeavor_id.present? }
  validates :title, :starts_at, presence: true
  validates :title, length: { maximum: 200 }
  validates :location, length: { maximum: 500 }
  validates :description, length: { maximum: 10_000 }
  validates :visibility, inclusion: { in: VISIBILITIES.keys }
  validate :end_follows_start
  validate :endeavor_belongs_to_organization

  scope :overlapping, ->(from, to) { where("starts_at < ? AND COALESCE(ends_at, starts_at) >= ?", to, from) }
  scope :publicly_visible, -> { where(visibility: "public") }

  def public? = visibility == "public"

  # A future public feed must use this allowlist, never serialize the parent record.
  def public_calendar_attributes
    return nil unless public?

    attributes.slice("id", "title", "description", "location", "starts_at", "ends_at", "all_day", "cancelled", "updated_at")
  end

  private

  def end_follows_start
    errors.add(:ends_at, "must be on or after the start") if ends_at && starts_at && ends_at < starts_at
  end

  def endeavor_belongs_to_organization
    if endeavor && endeavor.organization_id != organization_id
      errors.add(:endeavor, "must belong to the same organization")
    end
  end
end
