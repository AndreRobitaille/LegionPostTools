class DatedAgenda < ApplicationRecord
  STATUSES = %w[draft approved published].freeze

  belongs_to :organization
  belongs_to :meeting
  belongs_to :meeting_body
  belongs_to :meeting_type
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :published_by, class_name: "User", optional: true
  belongs_to :reopened_by, class_name: "User", optional: true

  has_many :dated_agenda_items, dependent: :destroy
  has_many :dated_agenda_sections, -> { ordered }, dependent: :destroy
  has_many :endeavors, through: :dated_agenda_items

  after_create :create_default_agenda_section!

  validates :title, :starts_at, :status, :location_name, presence: true
  validates :meeting_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validate :associations_belong_to_same_organization

  scope :draft, -> { where(status: "draft") }
  scope :approved, -> { where(status: "approved") }
  scope :published, -> { where(status: "published") }

  def self.create_from_template!(meeting:)
    if meeting.meeting_type.blank?
      meeting.errors.add(:meeting_type, "must be chosen before preparing an agenda")
      raise ActiveRecord::RecordInvalid, meeting
    end

    transaction do
      agenda = create!(
        meeting: meeting,
        organization: meeting.organization,
        meeting_body: meeting.meeting_body,
        meeting_type: meeting.meeting_type,
        starts_at: meeting.starts_at,
        title: meeting.title,
        location_name: meeting.location_name,
        location_address: meeting.location_address,
        status: "draft"
      )
      agenda.copy_template_items!
      agenda
    end
  end

  def self.default_title(meeting_type:, starts_at:)
    # DD MMM YYYY uppercase, matching the house date format from LegionFormatHelper#legion_date.
    "#{meeting_type.name} — #{starts_at.in_time_zone.strftime('%d %b %Y').upcase}"
  end

  def draft? = status == "draft"
  def approved? = status == "approved"
  def published? = status == "published"
  def locked_for_editing? = approved? || published?

  def copy_template_items!
    template_sections = meeting_type.meeting_type_agenda_sections.ordered.includes(agenda_items: [ :agenda_item_catalog_entry, :rich_text_body ])
    return if template_sections.empty?

    dated_agenda_sections.delete_all
    template_sections.each do |template_section|
      dated_section = dated_agenda_sections.create!(
        meeting_type_agenda_section: template_section,
        title: template_section.title,
        position: template_section.position
      )
      template_section.agenda_items.select(&:active?).each do |template_item|
        attrs = DatedAgendaItem.attributes_from_template_item(
          template_item,
          position: template_item.position,
          dated_agenda: self,
          agenda_section: dated_section
        )
        DatedAgendaItem.create!(attrs)
      end
    end
  end

  def default_agenda_section
    dated_agenda_sections.ordered.first
  end

  def approve!(user)
    with_lock do
      reload
      unless draft?
        errors.add(:base, "Only draft agendas can be approved.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "approved", approved_by_id: user.id, approved_at: Time.current, published_by_id: nil, published_at: nil)
    end
  end

  def publish!(user)
    with_lock do
      reload
      unless approved?
        errors.add(:base, "Approve this agenda before publishing it.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "published", published_by_id: user.id, published_at: Time.current)
    end
  end

  def reopen!(user)
    with_lock do
      reload
      unless approved? || published?
        errors.add(:base, "Only approved or published agendas can be reopened.")
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: "draft", approved_by_id: nil, approved_at: nil, published_by_id: nil, published_at: nil, reopened_by_id: user.id, reopened_at: Time.current)
    end
  end

  private

  def create_default_agenda_section!
    section = dated_agenda_sections.new(title: "Order of Business", position: 1)
    # A directly imported historical agenda may already be locked at creation.
    # Its required initial structure is not a later edit, so bypass that guard.
    section.save!(validate: false)
  end

  def associations_belong_to_same_organization
    return if organization.blank? || meeting.blank? || meeting_body.blank? || meeting_type.blank?
    return if meeting.organization_id == organization_id &&
      meeting_body.organization_id == organization_id &&
      meeting_type.organization_id == organization_id &&
      meeting.meeting_body_id == meeting_body_id &&
      meeting.meeting_type_id == meeting_type_id

    errors.add(:base, "meeting, meeting body, and meeting type must describe the same organization and occurrence")
  end
end
