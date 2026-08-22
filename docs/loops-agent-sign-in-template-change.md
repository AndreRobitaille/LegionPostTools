# Required Loops authentication templates

Do not add a required `login_code` variable to the template used by the running
application. The prior revision does not send that variable. Clone the current
sign-in transactional email, make the change below in the clone, and publish the
clone without changing the running application's `LOOPS_MAGIC_LINK_TEMPLATE_ID`.

The transactional template selected by `LOOPS_MAGIC_LINK_TEMPLATE_ID` must continue
to use these existing data variables:

- `name`
- `login_url`

Add this required scalar data variable:

- `login_code` — the grouped eight-digit value, for example `1234 5678`

Place the code above the existing sign-in button. The exact plain-language content is:

> Enter this code in the browser where you requested the email:
>
> `{login_code}`
>
> The code and link each work once and expire after 15 minutes. Using either one
> invalidates the other.

Keep the existing button linked to `{{login_url}}` and keep the visible plain-URL
fallback. The code should be at least 28px, bold, centered, and spaced as supplied;
do not split it into separate template fields.

Before deployment, send a safe provider test with non-production values for all three
variables and confirm the rendered HTML and text show the code, button, URL fallback,
and 15-minute wording. Store the clone's transactional ID as
`loops.magic_link_template_id` only when preparing the application release. The old
container keeps its old ID; the new container receives the new ID. Preserve the prior
ID for rollback. If the provider templates cannot be published and tested, do not
deploy this application revision.

## Agent-access confirmation template

Create and publish a separate transactional email named `Agent access confirmation`.
Store its transactional ID as the Rails credential
`loops.agent_access_confirmation_template_id`, which Kamal exposes as
`LOOPS_AGENT_ACCESS_CONFIRMATION_TEMPLATE_ID`.

Use exactly these required scalar data variables:

- `name`
- `confirmation_code` — the grouped eight-digit value, for example `1234 5678`

Subject:

> Confirm agent access in LegionPostTools

Body (insert the named Loops data variables where shown):

> Hello `{name}`,
>
> Enter this code in the browser where you are creating an agent access token:
>
> `{confirmation_code}`
>
> This code works once and expires in 15 minutes. If you did not request it, you
> can ignore this email.

Do not add a sign-in button, magic link, or other URL. Apply the same code styling
as the sign-in template: at least 28px, bold, centered, and spaced as supplied.
Send a safe provider test with non-production values for both variables before
publishing it.

## Release order

1. Publish and safely test the cloned sign-in template and the new code-only
   agent-access confirmation template. Publishing them does not affect the running
   application because it still has the prior sign-in template ID.
2. Set `loops.magic_link_template_id` to the cloned sign-in template ID and
   `loops.agent_access_confirmation_template_id` to the new confirmation template ID
   in Rails credentials.
3. Deploy the application and additive database migrations together with those
   secrets.
4. If rollback is needed, restore the prior application revision and prior sign-in
   template ID. The old template remains compatible with the old revision.
