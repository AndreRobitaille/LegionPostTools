# Passkey enrollment and recent identity

Adding a sign-in factor requires the current session's existing ten-minute recent
identity proof at both challenge issuance and credential creation. Normal email,
existing-passkey sign-in, and initial installation setup establish that proof.
Enrollment itself never refreshes it.

Bind each registration challenge to the session ID and authenticated_at value that
issued it. Consume it on submission, and reject missing, expired or mismatched
ceremonies before parsing a credential. Clear pending challenges on stale identity.
A later reauthentication requires new enrollment options.

## Confirmation and return

When identity is stale, keep the member signed in and preserve their passkey name
in a short-lived session-bound enrollment intent. Show a dedicated “Confirm your
identity” page explaining that this protects the new sign-in method. Use the
existing session-bound, single-use email code/link mechanism with the distinct
`enroll_passkey` purpose, or verify an already registered passkey for that same user.
Sending an email or viewing its link does not confirm identity.

Successful confirmation returns to Profile's enrollment section with the name
preserved and a “Continue adding your passkey” button. Do not automatically invoke
the device prompt. Clear the intent after successful enrollment or cancellation;
expire it after 30 minutes, and never carry it into another login/session/account.
Neither return destinations nor identity are taken from client URL parameters.

## Visual direction

Keep The 1919 compact signed-in header, bounded Profile column, cream panels, navy
buttons and gold section dividers. Reuse the existing reauthentication controls.
Put the reason and next step in 16px panel-lead text, with labeled email-code input,
visible keyboard focus, and an explicit “Cancel and return to Profile” action.
Keep the saved name and continuation action together. Verify the full flow at
1400px, 390px and 320px, including keyboard access and failure/retry states.

Token issuance, official-action confirmation, passkey renaming/removal, and account
capabilities retain their own policies. This prevents stale session access from
manufacturing the new factor that could otherwise satisfy their identity checks.

## Database compatibility

The migration adds `enroll_passkey` to the existing purpose check constraint. Apply
it before running the new flow. The expanded constraint is compatible with older
application code, so an application rollback can retain it. Schema rollback stops
with an explicit error if enrollment links exist; it never deletes their records.
