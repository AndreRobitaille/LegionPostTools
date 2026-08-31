# People, Roles, and Delegated Access

This is a living product reference for how LegionPostTools should understand people,
Post roles, application authority, and agents acting for people. Future feature design
should expand this document as the responsibilities of officers, committees, and other
participants become better defined.

This document states durable product policy. It does not imply that every access level,
screen, or API described here has already been implemented.

## The Person Is the Authority

A bot or other software agent is an agent of a person. It is not a separate class of
Post participant and does not receive an independent role or permission policy.

Whether an agent authenticates with the person's browser session, a personal agent
token, or a future supported credential, it acts with that person's current authority.
Changing or revoking the person's access must also change or revoke what the agent can
do. Using an agent never expands the person's authority.

This delegated access still does not prove fresh human intent for identity-bound official
acts. Approval, attestation, acceptance, signing, or amendment of official records may
require a separate trusted confirmation even when the person otherwise has permission.

## Distinct Kinds of Role

Do not collapse these concepts:

- A `Person` is the human being.
- A Post position is an American Legion office, committee responsibility, honorary
  status, or other organizational role held by a person, normally for a dated term.
- An application permission is authority to see or change a particular kind of data or
  workflow.
- A `User` is a person's ability to sign in. Not every person must have a login.
- An agent is a delegated execution channel for a signed-in person.

Holding a Post position may supply appropriate default application authority, but titles
alone must not become a blanket definition of access. A technical helper may administer
the application without holding Legion office. An officer or Past Post Commander may
have social and institutional standing without needing broad membership data.

## People and Membership Access

### Standard Post Member

A standard signed-in Post member may use LegionPostTools as a Post phonebook. Members
may reasonably want to call or email one another for Post business, volunteer work, or
social reasons.

Standard directory access may include bulk retrieval of:

- names;
- current Post roles;
- directory email addresses; and
- directory phone numbers.

Making the same directory available to the person's agent is not a separate disclosure.
The agent receives the information as the person's delegate. The application should not
force an agent to reconstruct an otherwise permitted directory through many individual
lookups.

Standard directory access does not include National roster membership details, renewal
status, member numbers, mailing addresses, login state, application grants, or internal
administrative notes.

### Commander, Adjutant, and 1st Vice Commander

The current Commander, Adjutant, and 1st Vice Commander have general operational
responsibility for the Post's membership. They need complete and efficient access to
membership information, including bulk access.

Their membership access may include:

- complete National roster records;
- current and historical membership counts with clearly stated definitions;
- membership status and paid-through year;
- renewal status for an explicitly identified membership year;
- Paid Up For Life and paid-ahead identification;
- complete renewal and outreach worklists;
- mailing addresses and undeliverable status;
- roster import freshness and recent roster changes; and
- bulk JSON, screen, print, or export workflows appropriate to the task.

This membership authority does not by itself grant technical administration. Seeing the
full roster must not silently permit someone to create or disable login accounts, change
application permissions, or perform unrelated system administration.

The authority belongs to the person while they hold the applicable current assignment.
It also belongs to any agent acting for that person. When the assignment ends, authority
derived from that assignment should end without relying on someone to remember a second,
unrelated cleanup step.

### Other Officers, Committees, and Subcommittees

Other officers, committee members, subcommittee members, and volunteers begin with the
same directory access as a standard Post member. Officer status alone does not confer
complete membership access.

Apply least privilege to additional duties. Grant the smallest useful slice for a real
responsibility, for example:

- aggregate membership information without individual roster records;
- a renewal outreach worklist containing names, contact details, and renewal state;
- service-related information needed for a particular responsibility; or
- access limited to the people participating in a particular committee or activity.

Task-specific access should be explainable, reviewable, and, where the duty is temporary,
time-limited. Do not expose member numbers, addresses, dues history, login state, or other
unrelated fields merely because a person needs one membership-related report.

Do not invent broad access categories in anticipation of hypothetical needs. Add a
narrow capability when a concrete officer or committee workflow establishes what data is
actually necessary.

### Past Post Commanders

Past Post Commanders have meaningful status and privilege within The American Legion and
within their Post. That status should be represented respectfully in appropriate product
features.

For people and membership information, however, a Past Post Commander receives the
standard Post member baseline. A historical Commander assignment or a current honorary
Past Post Commander designation does not confer general membership or renewal access.
They receive additional access only through another current assignment or an explicit,
appropriately scoped grant.

## Authorization Principles

Effective access is the combination of:

1. the baseline available to every signed-in Post member;
2. authority supplied by the person's current, dated assignments; and
3. explicit, scoped application grants for additional responsibilities.

Authorization must not depend on brittle presentation strings such as checking whether a
display label exactly equals `Commander`. Configurable Post positions need durable
semantics that survive harmless renaming and remain portable to other American Legion
installations. Post 165 grounds the first implementation but must not be hard-coded into
the policy.

Historical assignments remain part of the record, but an ended assignment does not keep
granting current access. Honorary status and operational authority must remain distinct.

Application capabilities should describe what a person can do or see, not whether the
person is generically an "officer." As the product grows, prefer questions such as:

- May this person use the Post directory?
- May this person see membership summaries?
- May this person receive a renewal worklist?
- May this person view complete roster records?
- May this person manage login accounts or application grants?

## Website and API Must Agree

The website and private API are two interfaces to the same application authority. They
must use the same policy and return the same class of information for the same person.

- A standard member and that member's agent may access the Post directory.
- A current core membership officer and that officer's agent may access complete
  membership and renewal information.
- A person with a scoped duty and that person's agent may access only the granted slice.
- A Past Post Commander and that person's agent receive the standard member baseline
  unless another current source of authority applies.
- A person with `manage_minutes` and that person's agent may perform ordinary structured
  draft-minutes work, including restricted transcript work and human review of AI
  suggestions. `view_internal_records` supplies corresponding read-only evidence access.
- A person with `manage_settings` and that person's agent may inspect and manage login
  account state through the same last-administrator and roster-control protections as the
  website.

Do not create bot-only shortcuts, bot-only restrictions, or a second set of authorization
rules. API serializers must still select fields deliberately; they must not dump complete
database records simply because the caller is authenticated.

The exception is not a weaker bot role but a stronger proof requirement for an official
act. A session or bearer token delegates the person's routine authority; it does not prove
fresh intent to approve, attest, accept, or amend exact minutes. Those actions remain
unavailable to the API until the one-use record/action/version-bound human confirmation
described in `docs/MINUTES_LIFECYCLE.md` exists.

Bulk access is a usability requirement where the person is authorized to work with the
whole set. It must not be simulated through repeated single-person lookups. Conversely,
bulk retrieval must not turn a narrow capability into an accidental full-roster export.

## Renewal and Count Semantics

Membership questions must state what is being counted. A stored person row, a person on
the latest imported roster, a member in good standing, a member needing outreach, and a
member paid for a particular year are not interchangeable concepts.

Renewal questions should identify the membership year rather than relying on an ambiguous
phrase such as "this year." Results should distinguish Paid Up For Life, paid through the
requested year, paid ahead, needs renewal, lapsed, deceased or removed, and unknown data
where the imported roster supports those distinctions.

Membership answers should include the date or time of the roster source. Stale roster data
must not be presented as if it were a current fact.

## Future Role Enrichment

Future feature work should expand this document with grounded descriptions of what Post
officers and recurring committees actually do. That context should inform workflows,
default access, review responsibilities, handoffs, and agent guidance.

Likely subjects include:

- Commander responsibilities and continuity across a term;
- Adjutant records, correspondence, agendas, and minutes responsibilities;
- 1st and 2nd Vice Commander responsibilities;
- Finance Officer and financial-review boundaries;
- Service Officer work and sensitive veteran information;
- Sergeant-at-Arms, Chaplain, Historian, Judge Advocate, and other Post offices;
- membership, house, events, honor guard, and other committees;
- temporary projects and subcommittees;
- Past Post Commander status and appropriate participation; and
- officer turnover, vacancies, acting appointments, and overlapping assignments.

When adding those descriptions, distinguish established American Legion responsibilities,
the practices of the particular Post, and application-specific authority. One must not be
silently inferred from another.
