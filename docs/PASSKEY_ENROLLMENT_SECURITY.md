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

Profile and the optional dashboard invitation share an **Add a passkey** card.
A recent sign-in goes straight to **Create passkey**. Otherwise show **Email me
a code**, and offer **Use an existing passkey** to members who have one. Each
method starts from this card. The email code and link are single use, bound to
the current browser session and enrollment attempt, and use the `enroll_passkey`
purpose. The email link has a deliberate **Continue setup** action.

Keep the optional name and originating screen in a session-bound attempt for
up to 30 minutes. Return to that screen after confirmation and focus **Create
passkey**. Only that click opens device setup. Show **Passkey added** with the
saved name after registration succeeds. Device cancellation offers **Try again**.
Explicit cancellation, expiry and a new login discard the pending attempt.

## Visual direction

Use one 1919 paper panel. Group the title, current instruction and key or mail
icon in a cream header. Align the labeled field and its actions on one baseline
in the paper body. In the dashboard rail and on phones, give the field and
primary action the same width and center the quieter actions underneath. Keep email available and offer
**Not now** on the optional invitation. Use a navy primary action, quiet
alternatives, a live status, and visible keyboard focus. Review at 1400px, 390px
and 320px.

Token issuance, official-action confirmation, passkey renaming/removal, and account
capabilities retain their own policies. This prevents stale session access from
manufacturing the new factor that could otherwise satisfy their identity checks.

## Database compatibility

The migration adds `enroll_passkey` to the existing purpose check constraint. Apply
it before running the new flow. The expanded constraint is compatible with older
application code, so an application rollback can retain it. Schema rollback stops
with an explicit error if enrollment links exist; it never deletes their records.
