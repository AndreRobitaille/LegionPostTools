# Public officers page handoff

## Backend contract

LegionPostTools supplies current public officer names, office titles, approved role
responsibilities/examples and the Post's general email. The text is stored on Post
positions and is also used by the member Contact the Post page. Current assignments
supply names; personal contact details remain private. The exact contract and
synthetic example are in [PUBLIC_OFFICERS_API.md](PUBLIC_OFFICERS_API.md) and its
[OpenAPI 3.1 specification](api/public-officers.openapi.json).

No companion-repository changes are made by this backend task. Standard officer roles are selected for public listing
by migration/preset; custom roles start unlisted. Administrators can change the listing
choice and saved explanation in **Administration → Post Positions → Edit contact guidance**.

## Copy-paste implementation brief for the website agent

Build a public officers page in the `wipost165` project using LegionPostTools'
`GET /public/v1/officers`. Read that repository's current `AGENTS.md`, design and
publishing-client guidance. Do not deploy until explicitly requested; confirm the
backend route is deployed before enabling production requests.

Use the existing server-side publisher client and Post-owned website bearer token.
Keep the token out of HTML/browser JavaScript. Do not add another editing/login system;
administrators maintain names/assignments and role explanations in LegionPostTools.

The current consumer files are `app/services/publishing/client.rb` and
`app/services/publishing/contract.rb`. Add a client `officers` read and an explicit
`:officers` validation case. The existing contract validates only its known kinds;
do not silently accept a new kind without field validation. Reuse the existing HTTP
transport, credential-scoped private cache, error handling and ETag machinery.

The response has `schema_version: 1`, `complete: true`, `as_of` (Post-local ISO date),
`timezone`, `post: {name, email}` and `officers: [...]`. Post email may be null. Each
officer has exactly `name` (first-name then last-name display string), `office` (role-title string),
`responsibility` (string or null), `examples` (ordered array of zero to two strings),
`primary_contact` (boolean), and `display_order` (integer). Treat strings as text,
not HTML. Display the supplied name without parsing or rearranging it; the backend
places generational suffixes at the end, with a comma before Sr./Jr. and a space
before Roman numerals such as III, including Sr/Jr recorded before the given name.
It uses the current roster label when present,
falling back to split name fields, so later roster corrections reach the page.
Names are not
stable ids; retain separate rows for multiple offices or
people with identical display names. Keep configured array order, or deliberately
group current officers under their office without losing entries.

The page should answer who the officers are and what they handle. Show names and roles
clearly, followed by the responsibility and, if present, “Contact them when:” with the
examples. Assistants only have an assistance sentence and no examples. Commander and
Service Officer are the primary contacts. Direct general contact through the Post's
mailbox using a normal mailto link; this route does not supply individual phone/email,
member profiles or portraits. Respect the public site's audience and visual system.

Only active offices selected for public listing and assignments covering the Post's
local date appear. Both assignment date bounds are inclusive. Duplicate assignments
for the same person/office collapse to one row; multiple offices remain. Excluded or
removed directory people are absent. An empty complete array is valid. Absence does
not establish a vacancy, and this is not the whole private roster. Never use `/api`,
the member directory or inferred email addresses to fill missing information.

Reuse the current cache/failure contract: server-private, keyed by credential,
`Vary: Authorization`, ETag revalidation and at most 300 seconds total freshness.
Every request, including HEAD and conditional reads, needs the website token. A 401
invalidates access; upstream failure does not allow expired content. Replace complete
collections so ended, hidden and unlisted officers disappear after revalidation.
Officer names, text, listing changes, Post email and local-date turnover can change ETags.

Test synthetic responses for normal officers, primary contacts, assistants, null
explanations/email, multiple people/offices, same display names, empty collections,
escaped text, malformed responses, changed ETags, removals, revocation and upstream
failure. Inspect desktop and phone rendering. Report consumer verification separately
from backend deployment. No real member data is needed for development verification.
