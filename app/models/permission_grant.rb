class PermissionGrant < ApplicationRecord
  CAPABILITIES = %w[
    manage_settings
    manage_people
    manage_meeting_bodies
    manage_agendas
    manage_minutes
    approve_minutes
    attest_minutes
    record_minutes_approval
    view_internal_records
  ].freeze

  GROUPS = [
    [ "Administration", %w[manage_settings manage_people] ],
    [ "Meetings", %w[manage_meeting_bodies manage_agendas manage_minutes] ],
    [ "Approvals", %w[approve_minutes attest_minutes record_minutes_approval] ],
    [ "Records", %w[view_internal_records] ]
  ].freeze

  LABELS = {
    "manage_settings" => "Manage app settings",
    "manage_people" => "Manage people and accounts",
    "manage_meeting_bodies" => "Manage meeting types",
    "manage_agendas" => "Prepare agendas",
    "manage_minutes" => "Draft minutes",
    "approve_minutes" => "Approve minutes as Commander",
    "attest_minutes" => "Attest minutes as Adjutant",
    "record_minutes_approval" => "Record membership approval of minutes",
    "view_internal_records" => "View internal meeting records"
  }.freeze

  # Capabilities a manage_settings admin implicitly holds so they can act as the
  # tool's tech support. Deliberately excludes the identity-bound official acts
  # (approve_minutes, attest_minutes, record_minutes_approval). Those require
  # either the configured current Post office or a deliberate personal grant.
  # See docs/superpowers/specs/2026-07-13-admin-hub-reorganization-design.md.
  IMPLIED_BY_MANAGE_SETTINGS = %w[
    manage_people
    manage_meeting_bodies
    manage_agendas
    manage_minutes
    view_internal_records
  ].freeze

  belongs_to :user

  validates :capability, presence: true, inclusion: { in: CAPABILITIES }, uniqueness: { scope: :user_id }
end
