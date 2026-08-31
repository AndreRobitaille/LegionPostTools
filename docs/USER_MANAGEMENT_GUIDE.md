# Commander and Adjutant Guide to User Management

This guide explains how to help members sign in, keep login access current with the
National roster, record Post officers, and grant application permissions.

The screens described here are available only to someone with the **Manage settings**
permission. A Commander or Adjutant who does not see these controls should ask an
existing LegionPostTools administrator for that permission. Holding a Post office and
administering the application are intentionally separate responsibilities.

## The Four Records to Keep Straight

LegionPostTools keeps four related but different things:

1. **National roster record** — imported membership information, including the roster
   email and member status. These fields cannot be edited in LegionPostTools.
2. **Login account** — whether this person can sign in and which email receives sign-in
   messages.
3. **Post role** — a dated office or responsibility, such as Commander, Adjutant, or
   Chaplain.
4. **Application permissions** — what the person may see or change in LegionPostTools.

Changing one does not automatically change all the others. For example, making someone
Commander does not create a login account or make that person a technical administrator.

## Are Members Enabled or Disabled by Default?

A roster import creates or updates the person record and automatically creates an enabled
login account for every Active or Grace member who has a usable, unique roster email.
Current members therefore do not need to be turned on one at a time.

| Account state | What happens |
| --- | --- |
| Active or Grace with a usable unique email | Account is created if needed and sign-in is enabled. |
| Active or Grace after an earlier roster disable | Sign-in is enabled again automatically. |
| Administrator selected **Disable sign-in** | Sign-in stays off until an administrator enables it again. |
| Expired or Deceased | Sign-in is disabled with the roster status recorded as the reason. |
| Missing from the newest roster | Sign-in is disabled with removal from the roster recorded as the reason. |
| Any other or unrecognized status | Sign-in is disabled with the status recorded, and the import reports the problem. |

The application will not disable the last enabled administrator, even if a roster change
would normally do so.

Automatic account creation is skipped when an Active or Grace member has a blank,
invalid, shared, or already-used email. The roster import completes, but its result lists
the member under problems that need review. Imports never replace an existing login
email, even when the roster email later changes.

## Find a Member

1. Sign in and open **People**.
2. Search by name or Member ID.
3. Select the member's name.

Administrators can also use the **Can sign in?** filter on the People page:

- **Yes** — has an enabled account;
- **No** — has an account, but it is disabled; or
- **No account** — needs email or roster-status review before an account can be created.

## Review Automatically Created Accounts

After every roster import, review **Sign-in access** and any row or account problems on
the result page. It reports:

- new accounts created and enabled;
- accounts enabled again by an Active or Grace status;
- accounts disabled by roster status or removal;
- accounts left off because an administrator disabled them; and
- current members whose missing, invalid, shared, or already-used email prevented account
  creation.

For an Active or Grace member with **No account**:

1. Correct the email at National Headquarters whenever the roster record is wrong.
2. Import the corrected roster.
3. If access is urgent, verify the member and the address independently, enter a unique
   **Login email** on the person's page, and select **Create login account**.

The new account follows National roster eligibility immediately. Creating an account does
not assign a Post role or grant administrative powers.

## Correct a Wrong Email Address

The roster email and login email are separate fields. A roster import updates the roster
email, but it never silently changes the address used to sign in.

### What to Tell the Member

> Your Post website uses the email address connected to your American Legion membership
> record. The Commander or Adjutant can help correct that National record. After the
> correction reaches our next roster import, we will make sure your login uses the new
> address and tell you when to try again.

Do not edit around an incorrect National record and treat the local workaround as the
permanent answer. Correct the source record first so future rosters, renewals, and Post
communications use the right address.

### Correction Procedure

1. Confirm the member's identity and the correct email address.
2. Have the Commander or Adjutant correct the email in the American Legion membership
   record at National Headquarters.
3. Import the updated National roster through **Admin → Import roster**.
4. Open **People**, find the member, and confirm that **Roster email** now shows the
   corrected address.
5. Reconcile the login email:
   - If the member can still sign in, the website can show them that the two addresses
     differ. They may select **Use roster email for login**.
   - If the member cannot receive mail at the old login address, select **Disable
     sign-in**, enter the corrected address, then select **Save email and enable
     sign-in**.
6. Ask the member to request a fresh sign-in email and confirm that it arrives.

If access is urgent before a roster import can occur, an administrator may enter a
verified address while creating or re-enabling the account. The account still follows
roster eligibility; correct the National record and reconcile the email afterward.

## Disable or Re-enable Sign-in

### Disable

1. Open **People** and select the member.
2. In **Login Account**, select **Disable sign-in**.

This keeps the person's roster record, role history, permissions, and account. It records
**disabled by an administrator** as the reason. A later Active or Grace roster import
will not turn the account back on.

Use manual disabling only when access must remain off regardless of the current roster.
Ordinary membership changes need no manual action; the next roster import handles them.

### Re-enable

1. Open the disabled member's **Login Account** section.
2. Confirm or correct the **Login email**.
3. If the member is Active or Grace, select **Save email and enable sign-in**.

For Expired, Deceased, removed, or other ineligible roster states, the email can be saved
but sign-in stays off. The panel states the reason. If National later returns the member to
Active or Grace, sign-in returns automatically unless an administrator disabled it.

The application blocks disabling the last enabled administrator. Keep at least two
trusted administrators when practical so officer turnover or a lost email account does
not create an avoidable lockout.

## Make Someone a Post Officer

Post roles are dated records. Keep their history instead of overwriting one officer with
another.

1. Open **People** and select the person.
2. Find **Post Roles**.
3. Under the existing roles, choose the new **Role**.
4. Enter the date the term **Starts on**.
5. Select **Assign role**.

To end a current role, select **End role** or enter the correct **Ended** date and select
**Save dates**. An assignment is active through its end date. A future start date does
not make the role current until that date arrives.

If the needed title is missing, go to **Admin → Post Positions** and add or activate the
position before assigning it. Do not create a second spelling of an existing office.

### Membership Access Supplied by a Position

In the standard American Legion Post setup, current assignments as Commander, 1st Vice
Commander, and Adjutant are configured to provide full membership and renewal access.
Other positions begin with ordinary member directory access.

Under **Admin → Post Positions**, a gold key marks any title that grants full membership
access. Change this only as a deliberate Post policy decision. This access begins and
ends with the dated assignment, but it still requires the person to have an enabled login
account before they can sign in and use it.

## Grant Application Permissions

A Post role describes what the person does for the Post. Application permissions control
what the person can do in LegionPostTools. Grant only what the person actually needs.

1. Make sure the person has a login account.
2. Open the person's page and find **Login Account → Permissions**.
3. Select the needed permissions.
4. Select **Save permissions**.

Important distinctions:

- **Manage settings** makes the person an application administrator who can manage
  accounts, roles, settings, and most operational areas. Reserve it for trusted people
  who actually administer the application.
- **Manage people** grants full membership access without making the person a technical
  administrator.
- Meeting and records permissions should match the person's real duties.
- Approval, attestation, and acceptance permissions are personal official-record powers.
  Administrator status does not supply them automatically.

At least one enabled person must retain **Manage settings**. The application prevents an
administrator from removing or disabling the last such account.

## Delegating Account Work to an Agent

The private API is intended to let a bot or agent perform ordinary administrator work for
the signed-in person, not merely report what the website contains. With that person's
current **Manage settings** permission, the agent may inspect an exact person's account,
create or enable it, disable sign-in, or return a roster-managed account to automatic
roster control. The same last-administrator protection, roster eligibility rules, email
validation, and separation between account, Post role, and app permissions still apply.

Account disable and return-to-roster-control actions appear under **Only when asked** in
the live `GET /api` handbook. A personal agent token is delegated access and must be kept
in secure credential storage; it never grants authority the person does not currently
hold and is not proof of fresh intent for an official minutes act.

## Officer Turnover Checklist

When an office changes hands:

1. Confirm the successor has the correct National roster email.
2. Confirm the successor's automatically created login is enabled; resolve any email
   exception shown by the latest roster import.
3. Assign the successor's Post role with the correct start date.
4. End the former officer's role with the correct end date; do not erase it.
5. Review both people's application permissions separately.
6. Remove administrator or other explicit permissions that no longer match the former
   officer's duties.
7. Disable the former officer's login only if that person should no longer have ordinary
   member access. Ending an office does not normally mean deleting member access.
8. Confirm that another enabled administrator remains before changing an administrator's
   access.

## Troubleshooting

### The member sees “Check your email,” but nothing arrives

That message intentionally does not reveal whether an account exists. Check the member's
page for **No account**, disabled sign-in, the wrong login email, or a missing roster
email. Also ask the member to check Spam or Junk.

### The email is correct, but an old code does not work

The code must be entered in the same browser that requested it. A code or link works once
and expires after 15 minutes. Ask the member to request a new email and use only the new
message.

### The correct email is already in use

Each login email may belong to only one account. Do not work around the error with a fake
address. Identify the existing account and resolve whether the records represent the
same person or two people who share an address.

### The management controls are missing

The signed-in person needs **Manage settings**. Commander, Adjutant, full roster access,
and **Manage people** do not by themselves provide account-management controls.

### A roster import did not change access

Open the member's **Login Account** section. It states whether an administrator disabled
the account, National status made the member ineligible, or the member was absent from
the newest roster. A deliberate administrator disable stays off; roster-disabled access
returns automatically with a later Active or Grace status.

After each roster import, review its sign-in access summary and any unsupported member
status warnings before considering the import complete.

## How to Explain the Passkey Message

After a member's first email sign-in, a box at the top of the page offers to set up a
passkey. Use this explanation:

> A passkey is not another password. There is no new word to create, type, or remember.
> Your phone, computer, browser, or password manager stores a safe sign-in key and asks
> for the same fingerprint, face, or device PIN you already use. It is optional, and
> email sign-in will keep working if you select Not now.

Most current phones and browsers have a built-in passkey manager. A member who already
uses 1Password may save the passkey there and use it across devices, but 1Password is a
paid optional choice—not a requirement. Advise members to create a passkey only on a
personal or trusted device.
