class PositionCapabilityGrant < ApplicationRecord
  CAPABILITIES = (PermissionGrant::CAPABILITIES - [ "manage_settings" ]).freeze

  belongs_to :position_title

  validates :capability,
    presence: true,
    inclusion: { in: CAPABILITIES },
    uniqueness: { scope: :position_title_id }
end
