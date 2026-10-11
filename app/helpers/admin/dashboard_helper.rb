module Admin::DashboardHelper
  def admin_workspace_groups
    settings = current_user.can?("manage_settings")
    agendas = current_user.can?("manage_agendas")
    minutes = current_user.can?("manage_minutes")
    meeting_description = if agendas
      "Prepare agendas and continue meeting records."
    elsif minutes
      "Open meetings and continue their minutes."
    else
      "Read internal meeting records."
    end

    groups = [
      { key: "meeting-work", column: :work, label: "Meeting work", destinations: [
        { label: "Meetings", description: meeting_description, path: admin_meetings_path, visible: agendas || minutes || current_user.can?("view_internal_records") },
        { label: "Manage Endeavors", description: "Keep continuing Post work moving.", path: admin_endeavors_path, visible: agendas }
      ] },
      { key: "people-roster", column: :administration, label: "People and roster", destinations: [
        { label: "Import roster", description: @latest_roster_import ? "Last imported #{legion_date(@latest_roster_import.imported_at)}." : "No roster has been imported yet.", path: new_admin_roster_import_path, roster: true },
        { label: "Import history", description: "Review previous roster imports.", path: admin_roster_imports_path },
        { label: "Sync email audience", description: "Update the Post's email audience from the roster.", path: new_admin_loops_roster_sync_path },
        { label: "Post positions", description: "Manage the offices your Post fills.", path: admin_position_titles_path }
      ], visible: settings },
      { key: "agenda-setup", column: :work, label: "Agenda setup", destinations: [
        { label: "Agenda catalog", description: "Edit reusable agenda building blocks.", path: admin_agenda_item_catalog_entries_path },
        { label: "Meeting types", description: "Set up templates for your Post's meetings.", path: admin_meeting_types_path }
      ], visible: agendas },
      { key: "public-website", column: :administration, label: "Public website", destinations: [
        { label: "Publishing", description: "Review content before visitors see it.", path: admin_website_publications_path, visible: current_user.can?("publish_public_content") },
        { label: "Website connections", description: "Manage your public website's access.", path: admin_website_access_tokens_path, visible: settings }
      ] },
      { key: "operations", column: :work, label: "Operations", destinations: [
        { label: "Background Jobs", description: "Check processing progress and work needing attention.", path: admin_jobs_path }
      ], visible: settings || agendas || minutes },
      { key: "access", column: :administration, label: "Access", destinations: [
        { label: "Administrators", description: "Review who administers the application.", path: admin_administrators_path },
        { label: "Agent access", description: "Review and revoke personal agent tokens.", path: admin_agent_access_tokens_path }
      ], visible: settings }
    ]

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
