# Admin and Roster Import Design

## Purpose

The next product slice should establish a small Administration area before Structured Agendas. The app already has people, users, position titles, position assignments, permission grants, organizations, and meeting bodies. What is missing is the workflow that lets a real American Legion post keep those records current after first setup.

The National American Legion roster export should be the source for the post's member list. The app should not become a second editable membership database. Administration should import that roster, show when it is fresh or stale, and let app administrators connect roster people to local login accounts and post responsibilities.

## Roadmap Placement

This work comes before Structured Agendas.

Structured Agendas need real people in the system: adjutants, commanders, officers, committee leads, and other meeting participants. Manual people entry would create avoidable duplicate/conflict risk because the National roster export already contains the base member records. The roster-backed admin foundation should therefore precede agenda templates and agenda item workflows.

This is not the full member directory or committee-management product. It is the minimum administration foundation needed for real post operation and officer continuity.

## Core Concepts

- **Person**: the app's local representation of a human being.
- **Roster/member data**: imported read-only data from the National roster export, keyed by Member ID.
- **User**: a login account tied to a person.
- **Post position or committee role**: assigned to a person, with effective dates and history.
- **App permission/admin capability**: granted to a user account because permissions control signed-in app behavior.

Post roles belong to people, not login accounts. App permissions belong to users, not imported roster rows.

## Roster Import

Admins upload the National roster CSV export. The known columns in the current export are:

- Member ID
- Name
- Post/Squadron Number
- Type
- Address
- Undeliverable
- Email
- PhoneNumber
- Branch
- Conflict/War Era
- Continuous Years
- Paid Through Year
- Member Status

The import matches rows by **Member ID**. Member ID is the stable identifier for imported roster data. Name, email, phone, and address are not identity keys.

Import behavior:

1. Parse the uploaded CSV using the known column names.
2. Match each row to an existing imported member/person record by Member ID.
3. Create a new person/member record when no matching Member ID exists.
4. Overwrite imported roster fields for matched members with the newest import values.
5. Preserve local-only records and relationships, including user links, login email, permission grants, passkeys, sessions, position assignments, and local app state.
6. Record when the import happened.
7. Present a summary of created, updated, unchanged, and problematic rows.

Imported roster fields are not locally editable. Corrections to membership information should happen through the National Legion system and enter this app through a later import.

## Roster Freshness

The Administration area shows the date of the latest successful roster import.

If the latest successful import is more than 30 days old, admin screens should show a clear prompt to upload a fresh export. Stale roster data should not block normal meeting work. It is an administrative warning so officers understand that membership data may be aged.

Person/member detail screens should make imported data age visible enough that an admin can tell whether they are looking at fresh or stale roster information.

## Email Policy

Roster email and login email are separate fields.

- **Roster email** is imported from the National roster and cannot be locally edited.
- **Login email** belongs to the user account and controls magic-link sign-in.

When an admin creates or enables a user account for a person, the app should default the login email to the roster email when one is present.

If a later roster import changes the roster email and the person has a user account whose login email differs, the app records an email mismatch. The import must not silently change the login email because login email is an account credential and National roster emails can be shared, stale, or mistaken.

After a successful login, if the signed-in user has an unresolved roster/login email mismatch, ask once:

- update login email to match the roster email,
- keep the current login email,
- remind me later.

If the user chooses to keep the current login email, do not keep prompting for that same mismatch. If a future roster import changes the roster email again, that is a new mismatch and may be prompted again.

If the user chooses remind me later, prompt again on the next successful login.

Admins should also be able to see email mismatch status in the Administration area so they can help members resolve account/contact confusion.

## Administration Area

The initial admin section should include:

1. **Roster import page**
   - Upload National roster CSV.
   - Show latest successful import date.
   - Warn when the latest roster import is older than 30 days.
   - Show import result summary.

2. **People/member list**
   - Populated primarily from roster imports.
   - Search or filter by name, member status, paid-through year, branch, and login/account status as needed for basic administration.
   - Avoid making this a polished public directory in the first slice.

3. **Person/member detail**
   - Show read-only imported roster fields.
   - Show roster freshness.
   - Show associated user account, if any.
   - Show current and historical post position assignments.

4. **User account controls**
   - Create or enable login for a person.
   - Disable login for a person.
   - Show login email separately from roster email.
   - Show email mismatch state.
   - Do not automatically create accounts for all imported members.

5. **App permissions**
   - Allow authorized admins to grant or remove app-level capabilities, including app administration.
   - App admin is a user/account permission, not a roster field and not an automatically imported status.

6. **Post positions and committee leads**
   - Assign post offices, officer roles, and committee-lead-style roles to people.
   - Use effective dates and preserve assignment history instead of overwriting past office holders.

## Permissions and Safety

Only users with the appropriate administration permission may access roster import, user management, permission grants, and position assignment management.

The setup-created first user already receives all initial permission grants. This admin slice should provide the ongoing UI needed to delegate and maintain those capabilities without returning to setup mode.

Roster import must never grant app permissions automatically. A member being active, paid through, or an officer in imported data does not by itself make them an app administrator.

## Error Handling and Conflicts

The first implementation should keep conflict handling boring and explicit.

- Missing Member ID: reject the row and show it in the import summary.
- Duplicate Member ID within one upload: do not guess; flag the duplicate in the summary.
- Unknown columns: ignore only if required columns are present; otherwise fail with a clear message.
- Malformed CSV: fail the import with a clear message and do not partially update roster data.
- Shared emails: allow them in roster data; do not use email as a unique identity key.
- Name changes: update the imported roster name for the Member ID; preserve user links and local assignments.

Apply each import atomically. If the upload has blocking errors, do not update roster data from that upload.

## Out of Scope for This Slice

- Full editable member directory.
- Local edits to imported roster fields.
- Automatic creation of user accounts for all members.
- Automatic app-admin grants from roster data.
- Sophisticated merge/split tooling.
- AI-assisted conflict resolution.
- Public directory or public member search.
- Full committee management beyond assigning existing-style position titles or committee lead roles to people.
- Blocking meeting workflows when roster data is stale.

## Testing and Verification

Implementation should include tests for:

- Successful roster import creates people/member records.
- Re-import by Member ID updates imported fields without breaking user links or local assignments.
- Roster fields are not locally editable through admin forms.
- Latest import timestamp drives the 30-day stale warning.
- Login email and roster email are stored separately.
- Roster/login email mismatch prompt appears once, respects "keep current," and repeats only after "remind me later" or a later changed roster email.
- Shared roster emails do not prevent import.
- Duplicate or missing Member IDs are reported safely.
- Only authorized admins can reach admin workflows.

Relevant checks before completion should include `bin/rails test`. If controllers/views are added, run the focused tests first and then the full suite when practical.
