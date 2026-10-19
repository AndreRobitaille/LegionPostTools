module Admin::DashboardHelper
  def admin_workspace_groups
    [
      { key: "people-roster", column: :people, label: "People and roster", destinations: [
        { label: "Import roster", description: @latest_roster_import ? "Last imported #{legion_date(@latest_roster_import.imported_at)}." : "No roster has been imported yet.", path: new_admin_roster_import_path, roster: true },
        { label: "Import history", description: "Review previous roster imports.", path: admin_roster_imports_path },
        { label: "Sync email audience", description: "Update the Post's email audience from the roster.", path: new_admin_loops_roster_sync_path },
        { label: "Post positions", description: "Manage the offices your Post fills.", path: admin_position_titles_path }
      ] },
      { key: "access", column: :settings, label: "Access", destinations: [
        { label: "Administrators", description: "Review who administers the application.", path: admin_administrators_path },
        { label: "Agent access", description: "Review and revoke personal agent tokens.", path: admin_agent_access_tokens_path }
      ] },
      { key: "public-website", column: :settings, label: "Public website", destinations: [
        { label: "Website connections", description: "Manage your public website's access.", path: admin_website_access_tokens_path }
      ] },
      { key: "operations", column: :settings, label: "Operations", destinations: [
        { label: "Minutes distribution", description: "Manage outside minutes recipients and automatic delivery.", path: minutes_distribution_path },
        { label: "Background Jobs", description: "Check processing progress and work needing attention.", path: admin_jobs_path }
      ] }
    ]
  end

  def officer_workspace_groups
    groups = [
      { key: "meeting-work", column: :work, label: "Meeting work", destinations: [
        officer_meeting_destination,
        { label: "Minutes distribution", description: "Send attested PEC and monthly minutes to designated outside offices.", path: minutes_distribution_path, visible: current_user.can_manage_minutes_distribution? },
        { label: "Manage Endeavors", description: "Keep continuing Post work moving.", path: admin_endeavors_path, visible: current_user.can?("manage_agendas") }
      ] },
      { key: "membership", column: :post, label: "Membership", destinations: [
        { label: "Membership", description: "Renewal follow-up, caller coordination, payments, and meeting reports.", path: membership_root_path }
      ], visible: current_user.full_membership_access? },
      { key: "buddy-checks", column: :post, label: "Buddy Checks", destinations: [
        { label: "Buddy Checks", description: "Review check-ins, care coverage, and the separate monthly county report.", path: buddy_checks_activity_path }
      ], visible: current_user.buddy_check_coordination_access? },
      { key: "agenda-setup", column: :work, label: "Agenda setup", destinations: [
        { label: "Agenda catalog", description: "Edit reusable agenda building blocks.", path: admin_agenda_item_catalog_entries_path },
        { label: "Meeting types", description: "Set up templates for your Post's meetings.", path: admin_meeting_types_path }
      ], visible: current_user.can?("manage_agendas") },
      { key: "public-website", column: :post, label: "Public website", destinations: [
        { label: "Publishing", description: "Review content before visitors see it.", path: admin_website_publications_path }
      ], visible: current_user.can?("publish_public_content") },
      { key: "operations", column: :work, label: "Processing", destinations: [
        { label: "Background Jobs", description: "Check agenda and minutes processing and work needing attention.", path: admin_jobs_path }
      ], visible: current_user.can_any?("manage_agendas", "manage_minutes") }
    ]
    select_workspace_groups(groups)
  end

  def officer_meeting_destination
    internal = current_user.can_any?("manage_agendas", "manage_minutes", "view_internal_records")
    description = if current_user.can?("manage_agendas")
      "Prepare agendas and continue meeting records."
    elsif current_user.can?("manage_minutes")
      "Open meetings and continue their minutes."
    elsif internal
      "Read internal meeting records."
    else
      "View shared meeting records and the actions available to you."
    end
    { label: "Meetings", description: description, path: internal ? admin_meetings_path : meetings_path,
      visible: internal || current_user.can_any?("approve_minutes", "attest_minutes", "record_minutes_approval") }
  end

  def select_workspace_groups(groups)
    groups.filter_map do |group|
      next unless group.fetch(:visible, true)

      destinations = group[:destinations].select { |destination| destination.fetch(:visible, true) }
      group.merge(destinations:) if destinations.any?
    end
  end

  def admin_workspace_roster_status
    return "Current" unless @roster_stale
    return "Not imported" unless @latest_roster_import

    "Import due"
  end
end
