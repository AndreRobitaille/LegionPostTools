class CalendarEvent < ApplicationRecord
  include WebsiteCalendarEntry
  VISIBILITIES = { "members" => "Members only", "public" => "Public" }.freeze

  normalizes :calendar_category, with: ->(value) { value.presence }
  validates :calendar_category, inclusion: { in: CalendarCategories::EDITABLE.keys + CalendarCategories::LEGACY_VALUES }, allow_nil: true

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

  attr_accessor :website_restriction_actor
  has_one :website_publication
  validates :website_designation, inclusion: { in: %w[unreviewed internal public_eligible] }
  before_validation :enforce_internal_website_category
  around_save :serialize_website_change
  around_destroy :serialize_website_change
  after_save :restrict_website_publication
  before_destroy :protect_meeting_entry
  before_destroy :withdraw_website_publication

  def calendar_deletable?
    !%w[member_meeting officer_meeting].include?(CalendarCategories.for(self))
  end

  def public? = visibility == "public"

  # Private calendar public-preview projection. Anonymous publication uses reviewed snapshots.
  def public_calendar_attributes
    return nil unless public?

    attributes.slice("id", "title", "description", "location", "starts_at", "ends_at", "all_day", "cancelled", "updated_at").merge("category" => CalendarCategories.for(self))
  end

  private

  def serialize_website_change(&block)
    WebsitePublishing::Boundary.synchronize(organization_id, &block)
  end

  def enforce_internal_website_category
    self.website_designation = "internal" if WebsitePublication::INTERNAL_CATEGORIES.include?(calendar_category)
  end

  def restrict_website_publication
    publication = WebsitePublication.find_by(calendar_event_id: id)
    return unless publication

    if (saved_change_to_visibility? && !public?) || (saved_change_to_website_designation? && website_designation != "public_eligible") || (saved_change_to_calendar_category? && WebsitePublication::INTERNAL_CATEGORIES.include?(calendar_category))
      publication.restrict!("source_restricted", updated_by, designation: website_designation, visibility: visibility)
    elsif saved_change_to_cancelled? && cancelled?
      publication.cancel_from_source!(updated_by)
    end
  end

  def withdraw_website_publication
    publication = WebsitePublication.find_by(calendar_event_id: id)
    return unless publication

    publication.restrict!("source_deleted", website_restriction_actor || updated_by)
    publication.update!(calendar_event: nil)
  end

  def protect_meeting_entry
    return if calendar_deletable?

    errors.add(:base, "Member and officer meeting entries cannot be deleted from the calendar.")
    throw :abort
  end

  def end_follows_start
    errors.add(:ends_at, "must be on or after the start") if ends_at && starts_at && ends_at < starts_at
  end

  def endeavor_belongs_to_organization
    if endeavor && endeavor.organization_id != organization_id
      errors.add(:endeavor, "must belong to the same organization")
    end
  end
end
