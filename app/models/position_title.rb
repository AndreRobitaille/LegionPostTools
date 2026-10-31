class PositionTitle < ApplicationRecord
  belongs_to :organization
  has_many :position_assignments, dependent: :destroy
  has_many :position_capability_grants, dependent: :destroy
  has_many :minutes_attendance_entries, dependent: :nullify

  before_validation :seed_contact_guidance, on: :create
  before_validation :set_assistant_contact_guidance

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :display_order, numericality: { only_integer: true }
  validates :grants_full_membership_access, inclusion: { in: [ true, false ] }
  validates :website_officer_listing, inclusion: { in: [ true, false ] }
  validates :contact_description, length: { maximum: 1_000 }
  validate :valid_contact_examples

  def assistant_role?
    name.to_s.start_with?("Assistant ") && name.delete_prefix("Assistant ").strip.present?
  end

  def contact_guidance
    return if contact_description.blank?

    { responsibility: contact_description, examples: contact_examples }
  end

  def contact_examples_text
    contact_examples.join("\n")
  end

  def contact_examples_text=(text)
    self.contact_examples = text.to_s.lines.map(&:strip).reject(&:blank?)
  end

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

  private

  def seed_contact_guidance
    return unless contact_description.nil? && contact_examples == []
    return unless (guidance = PostContactGuidance.defaults_for(name.to_s))

    self.contact_description = guidance.fetch(:responsibility)
    self.contact_examples = guidance.fetch(:examples).dup
  end

  def set_assistant_contact_guidance
    return unless assistant_role?

    self.contact_description = "Assists the #{name.delete_prefix('Assistant ').strip}."
    self.contact_examples = []
  end

  def valid_contact_examples
    unless contact_examples.is_a?(Array) && contact_examples.size <= 2 &&
        contact_examples.all? { |example| example.is_a?(String) && example.present? && example.length <= 300 }
      errors.add(:contact_examples, "must contain up to two examples, each at most 300 characters")
      return
    end
    errors.add(:contact_description, "is required when examples are provided") if contact_examples.any? && contact_description.blank?
  end
end
