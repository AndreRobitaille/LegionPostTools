# Consolidated Loops code-and-link template

LegionPostTools uses one Loops transactional email for ordinary sign-in and recent
human confirmation before agent-token creation. Both paths send the same three required
scalar data variables:

- `name`
- `login_url`
- `login_code` — the grouped eight-digit value, for example `1234 5678`

The email subject is:

> Your LegionPostTools code and link

The message must present the code first, followed by one continuation button linked to
`{data.login_url}` and a visible URL fallback. Its plain-language content is:

> Hello `{data.name}`,
>
> Enter this code in the browser where you requested the email:
>
> `{data.login_code}`
>
> Or use the button below. If you are already signed in and confirming a change,
> open it in that same browser.
>
> **Continue to LegionPostTools**
>
> The code and link each work once and expire in 15 minutes. Using either one
> invalidates the other.

The grouped code should be at least 28px, bold, centered, and visually separate from
the body copy. Keep the existing American Legion sender identity and a visible
plain-URL fallback beneath the button.

The consolidated template was published and tested on August 22, 2026:

- transactional ID: `cmt4vltqz02590jzx7wv82a1w`
- Guardian: zero errors and zero warnings
- provider preview and transactional delivery: accepted with safe non-production data
- required variables read back as exactly `login_code`, `login_url`, and `name`

The encrypted Rails credential `LOOPS_MAGIC_LINK_TEMPLATE_ID` selects this template,
and production was switched to it with the consolidated sign-in release on August 22,
2026. Preserve the prior template ID, `cmriet2vp0coo0j3q3vtgwtbz`, for application
rollback.
