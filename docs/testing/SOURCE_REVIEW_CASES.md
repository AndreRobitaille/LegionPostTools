# Pinned case index for whole-source reviews

Source: `15ce51b677a432275ce7e8d7e503fff36e4ace11`. Each exact test name below links its reviewed source line.
This index pairs with the directory/roster and privileged-confirmation review tables.
It records located assertions; execution and controlled-fault evidence remain separately
identified in those reviews and the overnight ledger. Every case remains.

## test/controllers/people_controller_test.rb

Reviewed file blob: `9fec7d72b16b012c5a0cc4231dd8f28b7f1048a3`.

- [officer index lists members with membership status column](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L34)
- [member index omits the membership status column](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L45)
- [officer index search filters by name](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L59)
- [plain member search does not match hidden member numbers](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L69)
- [plain member sort ignores officer-only membership fields](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L80)
- [plain member directory excludes expired deceased and removed people](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L95)
- [officer index sorts by member number when requested](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L111)
- [officer index sorts by paid-through year descending when requested](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L124)
- [officer index filters by member status, paid year, and sign-in](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L137)
- [index preserves sort when search and filters submit](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L154)
- [membership leader sees roster details but not login-account status](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_controller_test.rb#L165)

## test/controllers/people_show_test.rb

Reviewed file blob: `c5ecaf0e4d4a890427565150e1d3766bd15bff97`.

- [officer sees the full record with login and role controls](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L29)
- [officer login panel identifies admin override and revert action](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L46)
- [officer login panel shows roster-controlled state for a default account](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L60)
- [officer login panel explains why a roster-disabled account cannot sign in](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L73)
- [member sees contact, service, and roles but no record or controls](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L95)
- [member profile prefers local directory contact details](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L117)
- [manage_people officer sees officer view but not mutation forms](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L132)
- [current configured membership officer sees roster details without login details](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L147)
- [past membership officer has standard member access](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L168)
- [permission checkboxes reflect literal grants, not implied capabilities](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L190)
- [permission panel separates current role duties from manual grants](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L204)
- [officer show loads position titles for the current organization](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/people_show_test.rb#L222)

## test/controllers/api/people_api_test.rb

Reviewed file blob: `3007061d28cdf265bb909b45b2f7281ad8748ec3`.

- [unauthenticated directory request is private](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L27)
- [standard member receives a bulk directory without roster or login fields](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L34)
- [directory name search does not match hidden member numbers](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L65)
- [standard member cannot show an expired or removed person by id](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L79)
- [officer directory lists current assignments and filters exact role names](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L91)
- [standard member and past officer are forbidden from membership information](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L111)
- [current membership officer receives summary renewal worklist and full roster](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L127)
- [membership person never exposes login state grants or notes](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L165)
- [membership endpoints validate year state limit and offset](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L183)
- [bearer membership authority changes immediately when the assignment ends](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/api/people_api_test.rb#L203)

## test/models/person_test.rb

Reviewed file blob: `92e8a3341d0973d350043a7b116c6c0d60b8aaab`.

- [full_name joins first and last name](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L4)
- [roster display name uses imported roster name when present](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L10)
- [roster display name falls back to full name](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L16)
- [directory contact prefers local fields and falls back to roster fields](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L22)
- [directory visibility excludes removed expired and deceased people but keeps local people](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L39)
- [requires first_name and last_name](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L49)
- [blank member_number values are normalized to nil and do not violate uniqueness](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L57)
- [current_role_label returns the active title with the lowest display_order](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L65)
- [current_role_label is nil without an active assignment](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L76)
- [current_role_label ignores ended assignments](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L81)
- [active_role_labels lists active offices ordered by display_order then name](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L91)
- [service_summary joins branch and era, dropping blanks](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L105)
- [service_summary translates roster codes and suppresses missing sentinels](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L111)
- [roster_paid_through_display shows PUFL or the year](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L117)
- [initials take the first letter of the first two names, uppercased](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L123)
- [initials cope with middle names and a missing surname](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/person_test.rb#L128)

## test/controllers/profiles_controller_test.rb

Reviewed file blob: `6734817bcb3afb7b2af37ea8e64a16e1e6a41ebe`.

- [requires authentication](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/profiles_controller_test.rb#L11)
- [shows the member's own sign-in methods](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/profiles_controller_test.rb#L17)
- [invites a first passkey when the member has none](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/profiles_controller_test.rb#L29)
- [links across to the post's own record of the member](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/profiles_controller_test.rb#L39)
- [keeps personal agent access available to members](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/profiles_controller_test.rb#L47)
- [shows only the signed-in member's passkeys](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/profiles_controller_test.rb#L56)

## test/helpers/navigation_helper_test.rb

Reviewed file blob: `b38b53af44b49f55df3793b5e53a9679aa050efa`.

- [nav_section_for maps member meeting paths](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L4)
- [nav_section_for maps people paths](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L9)
- [nav_section_for maps admin paths that are not people](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L14)
- [nav_section_for maps settings paths](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L19)
- [nav_section_for defaults to dashboard](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L23)
- [nav_tab_class marks the active section](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L27)
- [nav_tab_attributes marks only the active link as current](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/navigation_helper_test.rb#L33)

## test/controllers/roster_email_reviews_controller_test.rb

Reviewed file blob: `06743ed4cbde9f0700bf519dab7456f37d312003`.

- [update_login changes login email to roster email](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/roster_email_reviews_controller_test.rb#L4)
- [keep_current keeps login email and stops prompting](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/roster_email_reviews_controller_test.rb#L25)
- [remind_later keeps prompting](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/roster_email_reviews_controller_test.rb#L46)
- [invalid decision redirects with alert](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/roster_email_reviews_controller_test.rb#L66)
- [unauthenticated update redirects to sign in](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/roster_email_reviews_controller_test.rb#L81)

## test/models/user_test.rb

Reviewed file blob: `d4a2fa585f2fb48dc3e0f9807063c2b4765e90c0`.

- [requires a unique person](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L4)
- [detects unresolved roster email mismatch](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L14)
- [does not prompt again after keeping current login email for same roster email](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L22)
- [prompts again after remind me later](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L38)
- [only_enabled_administrator? is true when this is the sole enabled admin](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L59)
- [only_enabled_administrator? is false when another enabled admin exists](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L64)
- [another_enabled_manage_settings_user_exists? ignores the given user and disabled users](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L70)
- [login access override defaults to false](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L78)
- [set_login_access_override! stores disabled true state](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L85)
- [set_login_access_override! stores disabled false state](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L98)
- [roster controlled access enables active and grace members](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L110)
- [roster controlled access disables expired deceased and removed members](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L122)
- [roster access replaces a legacy manual enable when member is no longer eligible](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L147)
- [roster access preserves a deliberate manual disable for an active member](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L162)
- [unsupported roster status disables sign-in with the status as reason](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L176)
- [last enabled administrator is not disabled by roster policy](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L189)
- [return_to_roster_control clears override and applies current roster policy](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L198)
- [return_to_roster_control skips when user is last enabled admin and override remains set](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L214)
- [return_to_roster_control replaces a manual disable with the ineligible roster status](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L226)
- [manage_settings implies the management capabilities](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L241)
- [manage_settings does not imply the identity-bound attestation acts](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L253)
- [a manage_agendas grant alone grants only manage_agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L263)
- [capabilities follow a current configured position assignment](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L273)
- [future and inactive positions do not grant capabilities](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L291)
- [manual permissions remain independent of position assignments](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L306)
- [private agenda notes access follows current Commander and Adjutant authority](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L315)
- [manual permissions do not grant private agenda notes access](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L332)
- [full membership access follows a current configured position assignment](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L342)
- [future and inactive positions do not grant full membership access](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L361)
- [manage_people grants full membership access without a Post office](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/user_test.rb#L378)

## test/system/dashboard_activities_test.rb

Reviewed file blob: `7750ebd66dfa4451b9fb279fbca8ecbc966c8734`.

- [meeting documents stay ahead of activities on desktop and phone](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/system/dashboard_activities_test.rb#L4)

## test/helpers/legion_format_helper_test.rb

Reviewed file blob: `d7683eb2fcb495ef73f626f9a66c2e389ddb8332`.

- [legion_date formats a date as DD MMM YYYY uppercase](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L4)
- [legion_date returns empty string for nil](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L9)
- [legion_time formats 24-hour HH:MM](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L13)
- [legion_datetime joins date and time with a diamond dot](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L18)
- [legion_date_parts returns calendar display parts](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L23)
- [parse_legion_date parses DD MMM YYYY case-insensitively](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L28)
- [parse_legion_date returns nil for blank or invalid input](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L33)
- [combine_legion_datetime parses a strict 24-hour time](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L40)
- [combines and renders installation-local times across daylight-saving offsets](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L44)
- [time entry accepts common shorthand and explicit AM PM](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L56)
- [combine_legion_datetime rejects missing malformed and out-of-range times](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/legion_format_helper_test.rb#L67)

## test/helpers/status_display_helper_test.rb

Reviewed file blob: `4168bcdc7e511a0d0e1ac87a47328cb26af4a798`.

- [active status renders the active class and label](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L4)
- [expired status renders the expired class](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L10)
- [unknown status renders the muted variant with its own label](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L15)
- [blank status renders nothing](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L20)
- [status matching is case insensitive](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L25)
- [status text is escaped](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L30)
- [dated agenda draft status renders the draft variant](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L35)
- [dated agenda approved status renders the approved variant](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L41)
- [dated agenda published status renders the published variant](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L46)
- [dated agenda unknown status falls back to the muted variant with a titleized label](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/helpers/status_display_helper_test.rb#L51)

## test/views/member_row_test.rb

Reviewed file blob: `5904960e3bca1e60cc5fbcdf2f3cc97f86b02fc4`.

- [renders name, office, and a status column with the gold edge for officers](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/member_row_test.rb#L6)
- [non-officer row has no gold edge and no office label](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/member_row_test.rb#L20)

## test/views/date_field_test.rb

Reviewed file blob: `ae60b34e765c293edf271ba221831f08d2cae779`.

- [renders a text input pre-filled in DD MMM YYYY and a native picker + button](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/date_field_test.rb#L4)
- [renders an empty text input when value is nil](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/date_field_test.rb#L13)

## test/views/section_header_test.rb

Reviewed file blob: `48cfe0ca9270ef0c9419683e52ba1310efdb61b6`.

- [renders the label and a rule](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/section_header_test.rb#L4)

## test/views/section_panel_test.rb

Reviewed file blob: `daedfcc95b25a8708a1317931ed44cf3764dafd8`.

- [renders the label, a body, and optional provenance](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/section_panel_test.rb#L4)
- [omits provenance when not given](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/section_panel_test.rb#L11)

## test/views/stat_tile_test.rb

Reviewed file blob: `0e699974da5b3de8d52bda66e5e31b893d23f84f`.

- [renders count, label, and variant class](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/views/stat_tile_test.rb#L4)

## test/services/roster_imports/csv_parser_test.rb

Reviewed file blob: `7858fec3ed658197fcaaa8887d9e4e4bb88f7989`.

- [parses valid fixture](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L6)
- [parses valid csv with utf-8 bom](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L27)
- [parses binary csv with utf-8 bom](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L35)
- [missing member id becomes a problem, not fatal; other rows still parse](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L43)
- [duplicate member id keeps the first row and problems the rest](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L54)
- [missing required headers is fatal](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L63)
- [malformed csv is fatal](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/csv_parser_test.rb#L72)

## test/services/roster_imports/importer_test.rb

Reviewed file blob: `bc1c7ad21f1bca70d1581a5d65948463a4404bb1`.

- [imports new people by member id and creates successful roster import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L4)
- [retains every new member and account name beyond ten records](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L19)
- [names an existing member receiving their first account and flags their deceased status reversal](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L37)
- [deceased status reversal preserves an administrator's deliberate sign-in disable](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L58)
- [reimport updates roster fields without changing user login email](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L78)
- [identical reimport counts existing row as unchanged](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L98)
- [reimport records aggregate field changes without retaining contact values](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L130)
- [row with missing member id is a problem but does not fail the whole import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L168)
- [row with missing member id is a problem but valid rows still import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L177)
- [member absent from a new import is marked removed and their sign-in disabled](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L192)
- [removed already-disabled member is not marked as newly disabled in removed_members](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L209)
- [the last enabled administrator is not disabled on removal; a problem is recorded](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L224)
- [unsupported roster status for a person with a user records a problem and disables sign-in](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L240)
- [last enabled administrator present in the CSV with expired status is not disabled and records a skipped last admin problem](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L257)
- [active and grace roster statuses re-enable roster-controlled existing accounts](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L274)
- [expired and deceased roster statuses disable roster-controlled existing accounts](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L293)
- [imports replace a legacy manual enable when roster status is expired](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L314)
- [imports create enabled roster-managed login accounts for active members](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L330)
- [active members without usable unique emails import but do not get login accounts](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L348)
- [active roster import leaves a deliberately disabled account off](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L373)
- [returning active member clears roster_removed_at and re-enables roster-controlled sign-in](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L390)
- [a file with zero valid rows never mass-removes](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L405)
- [more than ten removals creates pending confirmation without mutating people or users](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L417)
- [pending removal preview excludes the last enabled administrator from sign-in disable count](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L445)
- [pending removal preview reserves one removed admin when all enabled admins are being removed](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L468)
- [confirmed large removal applies the stored import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L495)
- [missing required headers creates failed roster import without persisting people](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L519)
- [shared roster emails do not prevent import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L534)
- [parser failure creates failed roster import without people](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L547)
- [person save failures roll back earlier roster updates and do not create completed import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/roster_imports/importer_test.rb#L559)

## test/models/roster_import_test.rb

Reviewed file blob: `7b1153021e15ed850a5711c23af167451f26245d`.

- [latest_successful returns newest successful import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L4)
- [stale when newest successful import is older than thirty days](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L13)
- [fresh when newest successful import is within thirty days](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L19)
- [problems and removed_members read from summary safely](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L25)
- [older imports retain deceased reversal warnings without inventing member identities](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L42)
- [history orders newest first](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L54)
- [pending confirmation requires an attached csv](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/models/roster_import_test.rb#L60)

## test/system/roster_import_results_test.rb

Reviewed file blob: `f5013563b9e83c35b1c6358472432e58e3f2b2e6`.

- [empty file upload preserves members and a later valid upload works](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/system/roster_import_results_test.rb#L4)
- [import results identify new accounts and warn about deceased status changes at desktop and narrow widths](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/system/roster_import_results_test.rb#L43)

## test/services/loops/roster_audience_test.rb

Reviewed file blob: `d6ce091b3304496f78d490da577f29b92272e3c5`.

- [selects present active and grace members with unique valid emails](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_audience_test.rb#L4)
- [counts and skips blank invalid and shared roster emails](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_audience_test.rb#L17)
- [contact payload uses stable member identity and never changes Loops audience choices](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_audience_test.rb#L31)

## test/services/loops/client_test.rb

Reviewed file blob: `962d0513fa38125af46e38c98074dbc707d79c2d`.

- [updates a contact with an authenticated JSON put request](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/client_test.rb#L17)
- [retries a rate limited contact update after Retry-After](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/client_test.rb#L32)
- [raises provider message for a rejected update](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/client_test.rb#L46)

## test/services/loops/roster_synchronizer_test.rb

Reviewed file blob: `4fa0e1dc2d50687a860529f05822444788dc32a2`.

- [completes an upsert run and records progress](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_synchronizer_test.rb#L39)
- [records a rejected contact without aborting the run](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_synchronizer_test.rb#L52)
- [a later contact is actually sent after the first contact is rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_synchronizer_test.rb#L65)
- [refuses to sync after a newer roster import](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_synchronizer_test.rb#L95)
- [marks a terminal connection failure](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_synchronizer_test.rb#L115)
- [marks missing job-time configuration as a failed sync](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/loops/roster_synchronizer_test.rb#L125)

## test/controllers/admin/loops_roster_syncs_controller_test.rb

Reviewed file blob: `a050efbf39ef46543f3e17532ffea3ce4e680cad`.

- [preview requires settings access](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L18)
- [preview explains selection and opt-out safety](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L26)
- [preview warns when the source roster is stale](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L39)
- [create records and enqueues a roster sync](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L51)
- [create reports missing Loops configuration](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L67)
- [create sends an administrator to an existing active sync](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L79)
- [show renders partial failures and safety note](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/loops_roster_syncs_controller_test.rb#L93)

## test/services/membership_report_test.rb

Reviewed file blob: `03c11c65b85c89d86061eee64df82d0782f4210a`.

- [classifies renewal states without claiming paid-ahead members are multiyear](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/membership_report_test.rb#L8)
- [summary counts roster records current members and disjoint renewal states](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/membership_report_test.rb#L20)
- [reports the latest completed roster import and staleness](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/membership_report_test.rb#L39)
- [requires a supported explicit membership year](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/services/membership_report_test.rb#L51)

## test/controllers/official_action_reauthentications_controller_test.rb

Reviewed file blob: `b3fbbd36abc3d675d30578211afb2f3865d6da77`.

- [email code confirms and completes the exact pending approval](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L28)
- [email link GET explains the action and only its confirmation POST completes it](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L48)
- [the confirmation page names the action that authentication will complete](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L68)
- [identity confirmation rejects changed minutes instead of completing a stale handoff](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L79)
- [passkey confirmation completes the exact handoff and returns its workspace](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L93)
- [Adjutant email confirmation attests a draft without Commander handoff or another click](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L111)
- [signing out with a pending official action clears authentication and preserves the confirmation](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L127)
- [disabled accounts with official action confirmations lose their session without an error](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L156)
- [inactive sessions with official action confirmations expire without an error](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/official_action_reauthentications_controller_test.rb#L169)

## test/controllers/passkey_invitations_controller_test.rb

Reviewed file blob: `e9d82f2c8aba99a230ead516c1417536d4d29f4b`.

- [dismiss requires authentication](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/passkey_invitations_controller_test.rb#L4)

## test/controllers/admin/roster_imports_controller_test.rb

Reviewed file blob: `b1263a876ca654ecba9785341448f839af9a78e6`.

- [new requires admin access and shows upload form](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L4)
- [new upload page states the removal consequence](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L26)
- [blank upload redirects back with alert](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L35)
- [empty uploaded CSV preserves people and sign in then a valid upload succeeds](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L45)
- [non-upload file param redirects back with alert](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L97)
- [malformed roster_import param redirects back with alert](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L107)
- [successful upload creates people and shows import summary](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L117)
- [large removal upload returns pending confirmation notice](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L141)
- [upload with a missing member id row completes with a problem shown, no person created](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L159)
- [index lists past imports newest first](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L182)
- [index renders a failed import whose problems are stored as plain strings](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L194)
- [show renders a failed import whose problems are stored as plain strings](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L208)
- [large removal upload shows pending confirmation and does not mutate records](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L222)
- [confirming pending import requires checkbox](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L246)
- [confirm rejects completed imports without failing](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L260)
- [confirm rejects failed imports without failing](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L271)
- [confirm rejects pending imports missing attachment without failing](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L282)
- [confirm rejects superseded pending imports and leaves them pending](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L294)
- [newer pending_confirmation import blocks old pending confirmation](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L315)
- [second confirm after success is rejected and leaves completed import unchanged](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L339)
- [pending show uses future tense for sign-in changes](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L361)
- [completed show uses past tense for sign-in changes](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L376)
- [show lists access effects and sign-in exceptions](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L390)
- [completed show explains created, returned, and field-level changes](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L415)
- [completed show warns about named deceased reversals and identifies new accounts](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L453)
- [older completed show warns from aggregate evidence and states missing names](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L476)
- [ordinary members cannot read named roster import results](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L493)
- [pending show does not render the completed-style change tiles and offers a discard](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L507)
- [discard turns a pending import inert without removing anyone](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L522)
- [discard leaves a completed import unchanged](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L546)
- [superseded pending show replaces the confirm form with a discard](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/admin/roster_imports_controller_test.rb#L556)

## test/controllers/dashboard_controller_test.rb

Reviewed file blob: `afaef3dff7e204571c64c9ecb3fb41fae74456cc`.

- [requires authentication after setup](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L4)
- [partial setup state still redirects to setup](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L16)
- [true first run root redirects to setup](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L24)
- [user only partial setup root redirects to setup](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L30)
- [recovery installed state unauthenticated root redirects to sign in](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L39)
- [authenticated user sees dashboard](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L49)
- [signed in user in recovery installed state can reach dashboard](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L66)
- [stale sessions older than 180 days are expired](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L82)
- [active resumed sessions update last seen periodically](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L101)
- [shows the passkey invite when the user has no passkeys](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L124)
- [shows the next and most recent meetings with direct document actions](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L135)
- [keeps member meetings separate and shows only the next three eligible activities](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L158)
- [activities use the Post date and retain ongoing events without a month cutoff](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L197)
- [hides the activities section when there are no eligible events](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L216)
- [hides the passkey invite when the user already has a passkey](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L227)
- [shows roster email review prompt when needed](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L235)
- [remind later does not show the roster email review prompt again in the same session](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L246)
- [remind later shows the roster email review prompt again in a new signed-in session](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L261)
- [does not show roster email review prompt when roster and login emails match](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L279)
- [invite stays hidden after dismissal within the session](https://github.com/AndreRobitaille/LegionPostTools/blob/15ce51b677a432275ce7e8d7e503fff36e4ace11/test/controllers/dashboard_controller_test.rb#L289)
