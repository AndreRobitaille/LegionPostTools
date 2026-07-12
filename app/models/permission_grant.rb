class PermissionGrant < ApplicationRecord
  CAPABILITIES = %w[
    manage_settings
    manage_people
    manage_meeting_bodies
    manage_agendas
    manage_minutes
    approve_minutes
    attest_minutes
    record_acceptance_motions
    view_internal_records
  ].freeze

  GROUPS = [
    [ "Administration", %w[manage_settings manage_people] ],
    [ "Meetings", %w[manage_meeting_bodies manage_agendas manage_minutes] ],
    [ "Approvals", %w[approve_minutes attest_minutes record_acceptance_motions] ],
    [ "Records", %w[view_internal_records] ]
  ].freeze

  belongs_to :user

  validates :capability, presence: true, inclusion: { in: CAPABILITIES }, uniqueness: { scope: :user_id }
end
