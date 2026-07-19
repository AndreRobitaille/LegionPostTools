class DatedAgenda < ApplicationRecord
  STATUSES = %w[draft approved published].freeze

  belongs_to :organization
  belongs_to :meeting_body
  belongs_to :meeting_type
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :published_by, class_name: "User", optional: true
  belongs_to :reopened_by, class_name: "User", optional: true

  has_many :dated_agenda_items, dependent: :destroy

  validates :title, :starts_at, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :associations_belong_to_same_organization

  scope :ordered, -> { order(starts_at: :desc, title: :asc) }
  scope :upcoming, -> { where("starts_at >= ?", Time.zone.today.beginning_of_day).order(:starts_at, :title) }
  scope :draft, -> { where(status: "draft") }
  scope :approved, -> { where(status: "approved") }
  scope :published, -> { where(status: "published") }

  def self.create_from_template!(organization:, meeting_body:, meeting_type:, starts_at:, title: nil)
    agenda_title = title.to_s.strip.presence || default_title(meeting_type:, starts_at:)
    transaction do
      agenda = create!(organization:, meeting_body:, meeting_type:, starts_at:, title: agenda_title, status: "draft")
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
    meeting_type.meeting_type_agenda_items.active.ordered.each_with_index do |template_item, index|
      attrs = DatedAgendaItem.attributes_from_template_item(template_item, position: template_item.position.presence || index + 1, dated_agenda: self)
      DatedAgendaItem.create!(attrs)
    end
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

  def associations_belong_to_same_organization
    return if organization.blank? || meeting_body.blank? || meeting_type.blank?
    return if meeting_body.organization_id == organization_id && meeting_type.organization_id == organization_id

    errors.add(:base, "meeting body and meeting type must belong to the same organization")
  end
end
