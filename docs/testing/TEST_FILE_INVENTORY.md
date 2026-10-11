# Test-file review inventory

Baseline: `5adda175d67e9603f58fdf8574ad6f7a0313d6b9`. Every entry is located, not yet reviewed.
Runner execution and assertion/fault review are separate evidence. No file is declared redundant.

| File | Level | Slice | Priority | Review status / reason |
| --- | --- | --- | --- | --- |
| `test/models/official_record_database_guards_test.rb` | models | Schema fidelity / #86 | P0 | Added direct SQL official-record variants; old-schema failures and fresh-load passes; Endeavor behavior deferred |
| `test/assets_test.rb` | assets_test.rb | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/config/database_configuration_test.rb` | config | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/config/filter_parameter_logging_test.rb` | config | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/config/time_zone_configuration_test.rb` | config | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/administrators_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/agenda_item_catalog_entries_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/agent_access_tokens_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/dashboard_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/dated_agenda_endeavors_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/dated_agenda_items_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/admin/dated_agenda_sections_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/admin/dated_agendas_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/admin/jobs_controller_test.rb` | controllers | Background / external boundaries | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/loops_roster_syncs_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/meeting_minutes_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/meeting_transcripts_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/meeting_type_agenda_items_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/meeting_type_agenda_sections_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/meeting_types_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/admin/meetings_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/minutes_corrections_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/minutes_draft_runs_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/minutes_editor_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/minutes_item_endeavors_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/permission_grants_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/position_assignments_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/position_titles_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/roster_imports_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/user_accounts_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/admin/website_access_tokens_controller_test.rb` | controllers | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/agent_access_reauthentications_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/agent_access_tokens_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/agenda_parity_api_test.rb` | controllers | Runner / component contracts | P2 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/api/calendar_activities_api_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/api/handbook_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/idempotency_concurrency_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/meetings_api_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/minutes_api_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/minutes_draft_api_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/minutes_item_endeavors_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/officer_api_test.rb` | controllers | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/controllers/api/people_api_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/api/token_management_boundary_test.rb` | controllers | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/controllers/api/user_accounts_api_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/api/website_publications_api_test.rb` | controllers | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/calendar_controller_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/calendar_event_deletion_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/calendar_pdf_sources_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/dashboard_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/dated_agenda_pdf_sources_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/dated_agendas_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/endeavor_histories_controller_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/endeavor_tasks_controller_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/endeavor_updates_controller_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/endeavors_controller_test.rb` | controllers | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/meeting_minutes_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/meeting_minutes_pdf_sources_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/meetings_controller_test.rb` | controllers | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/official_action_reauthentications_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/passkey_enrollment_reauthentications_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/passkey_enrollment_security_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/passkey_invitations_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/passkeys_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/people_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/people_show_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/profiles_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/public_publishing_test.rb` | controllers | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/roster_email_reviews_controller_test.rb` | controllers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/controllers/sessions_controller_test.rb` | controllers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/setup_controller_test.rb` | controllers | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/controllers/website_access_authentication_test.rb` | controllers | Publication / #60–#62, #81 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/controllers/website_calendar_test.rb` | controllers | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/controllers/website_publishing_admin_test.rb` | controllers | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/helpers/legion_format_helper_test.rb` | helpers | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/helpers/navigation_helper_test.rb` | helpers | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/helpers/status_display_helper_test.rb` | helpers | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/integration/direct_upload_security_test.rb` | integration | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/integration/login_page_test.rb` | integration | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/integration/primary_nav_test.rb` | integration | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/jobs/cleanup_agent_api_executions_job_test.rb` | jobs | Background / external boundaries | P1 | Deferred: awaiting bounded slice review |
| `test/jobs/minutes_draft_generation_job_test.rb` | jobs | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/mailers/magic_links_mailer_test.rb` | mailers | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/migrations/reinterpret_legacy_dated_agenda_times_test.rb` | migrations | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/agenda_item_catalog_entry_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/agent_access_token_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/calendar_event_test.rb` | models | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/models/dated_agenda_item_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/dated_agenda_roll_call_entry_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/dated_agenda_section_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/dated_agenda_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/endeavor_test.rb` | models | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/models/endeavor_update_test.rb` | models | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/models/magic_link_concurrency_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/magic_link_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_body_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_minutes_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_transcript_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_type_agenda_item_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_type_agenda_section_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/meeting_type_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/minutes_draft_run_test.rb` | models | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/models/organization_test.rb` | models | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/models/permission_grant_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/person_test.rb` | models | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/models/position_assignment_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/position_capability_grant_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/position_title_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/roster_import_test.rb` | models | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/models/session_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/user_test.rb` | models | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/website_access_token_test.rb` | models | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/website_calendar_test.rb` | models | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/website_publication_concurrency_test.rb` | models | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/models/website_publication_test.rb` | models | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/services/agenda_item_catalog_seeder_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/agent_operator_instructions_test.rb` | services | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/services/american_legion_post_preset_test.rb` | services | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/services/calendar_pdf_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/dated_agenda_pdf_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/endeavor_history/history_test.rb` | services | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/services/endeavor_history/provider_test.rb` | services | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/services/loops/client_test.rb` | services | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/services/loops/roster_audience_test.rb` | services | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/services/loops/roster_synchronizer_test.rb` | services | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/services/mail_delivery_test.rb` | services | Background / external boundaries | P1 | Deferred: awaiting bounded slice review |
| `test/services/meeting_minutes_pdf_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/meeting_type_template_seeder_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/membership_report_test.rb` | services | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/services/minutes_agenda_wording_backfill_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/minutes_draft_providers/openai_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/minutes_drafting/generate_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/minutes_drafting/prompt_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/minutes_drafting/source_document_test.rb` | services | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/services/openai_sdk_contract_test.rb` | services | Background / external boundaries | P1 | Deferred: awaiting bounded slice review |
| `test/services/roster_imports/csv_parser_test.rb` | services | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/services/roster_imports/importer_test.rb` | services | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/system/account_menu_test.rb` | system | Member / navigation / roster | P1 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/system/agenda_item_catalog_entries_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/system/agent_access_tokens_test.rb` | system | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/system/authentication_entry_test.rb` | system | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/system/calendar_event_deletion_test.rb` | system | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/system/calendar_mobile_schedule_test.rb` | system | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/system/calendar_print_test.rb` | system | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/system/calendar_refinements_test.rb` | system | Continuing Post work / calendar | P1 | Deferred: awaiting bounded slice review |
| `test/system/dashboard_activities_test.rb` | system | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/system/dated_agendas_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/system/meeting_documents_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/system/meeting_types_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Reviewed scoped variants in matrix; other variants deferred to #84 |
| `test/system/minutes_approval_flow_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/system/minutes_background_drafting_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/system/minutes_endeavor_confirmation_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/system/passkey_enrollment_security_test.rb` | system | Authentication / authority / #78, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/system/pdf_resource_security_test.rb` | system | Meeting / documents / #77, #79–#83 | P0 | Deferred: awaiting bounded slice review |
| `test/system/roster_import_results_test.rb` | system | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/system/website_access_tokens_test.rb` | system | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/system/website_calendar_test.rb` | system | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/system/website_publishing_test.rb` | system | Publication / #60–#62, #81 | P0 | Deferred: awaiting bounded slice review |
| `test/views/date_field_test.rb` | views | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/views/member_row_test.rb` | views | Member / navigation / roster | P1 | Deferred: awaiting bounded slice review |
| `test/views/section_header_test.rb` | views | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/views/section_panel_test.rb` | views | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/views/stat_tile_test.rb` | views | Runner / component contracts | P2 | Deferred: awaiting bounded slice review |
| `test/integration/protected_meeting_deletion_test.rb` | integration | #82 / #83 | P0 | Reviewed: source/state/denial matrix, original defect and detachment-fault evidence |
