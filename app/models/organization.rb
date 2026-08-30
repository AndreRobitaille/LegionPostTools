class Organization < ApplicationRecord
  has_many :dated_agendas, dependent: :restrict_with_exception
  has_many :position_titles, dependent: :destroy
  has_many :meeting_bodies, dependent: :destroy
  has_many :agenda_item_catalog_entries, dependent: :destroy
  has_many :meeting_types, dependent: :destroy
  has_many :tracked_items, dependent: :restrict_with_exception

  normalizes :public_email, with: ->(value) { value.strip.downcase }

  validates :name, :unit_type, :timezone, presence: true
  validates :public_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :mailing_address_fits_print_footer

  def mailing_address_lines
    mailing_address.to_s.lines.map(&:strip).reject(&:blank?)
  end

  private

  def mailing_address_fits_print_footer
    return if mailing_address_lines.length <= 2

    errors.add(:mailing_address, "must fit on no more than two lines")
  end
end
