# Exact remaining delegated API component source cases

Source `95a38a373154c1905f7de6726e96bccb41c4120c`, four fully read files /82 cases. All fixture/helper/assertion source was read; execution and representative faults remain separate.

## test/controllers/api/officer_api_test.rb

Reviewed file blob: `4b24857772212b4417ba4f1f7b30388fe77cec92`.

- [unauthenticated JSON list is 401](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L29)
- [member is forbidden from meeting catalogs and draft agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L36)
- [commander lists meeting bodies and types for matching names](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L46)
- [Endeavor index is small enough to match Car Show without search](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L63)
- [Endeavor show includes details as plain text](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L93)
- [dated agendas list upcoming first and include drafts for managers](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L104)
- [creating a dated agenda from a template starts as draft](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L126)
- [dated agenda detail includes document controls Commander notes and officer roll call](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L149)
- [member cannot create a dated agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L184)
- [adding Endeavor to a draft agenda snapshots it](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L197)
- [adding Endeavor to a locked agenda is 422](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L215)
- [adding the same Endeavor twice is 422](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L232)
- [commander creates Endeavor then appends an update](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L248)
- [overall due date uses new API name and takes precedence over legacy field](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L271)
- [malformed Endeavor date is 422 JSON and creates nothing](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L279)
- [missing CSRF token is 422 JSON when forgery protection is enabled](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L296)
- [complete and reopen Endeavor](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L312)
- [approve publish and reopen are available but not required for drafts](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L324)
- [missing records are 404 JSON](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L346)
- [bearer token reads with current grants and permission removal is immediate](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L355)
- [invalid bearer never falls back to a valid session cookie](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L366)
- [revoked expired and disabled bearer tokens return unauthorized](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L386)
- [bearer mutation requires idempotency key and does not require CSRF](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L402)
- [exact bearer retry preserves its original mutation until receipt cleanup](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L419)
- [altered input under an existing key is conflict](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L484)
- [altered sensitive input under an existing key is still a conflict](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L497)
- [a matching execution still marked processing fails safely](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L516)
- [session mutation remains compatible without idempotency key](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L532)
- [bearer retries are safe across every current API mutation family](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/officer_api_test.rb#L540)

## test/controllers/api/agenda_parity_api_test.rb

Reviewed file blob: `435c495288651e1d58da8f76b0b5885fab9d3dfa`.

- [catalog API lists reorders and soft-removes kept entries](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L26)
- [catalog API creates and edits reusable document controls](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L50)
- [plain member cannot manage the agenda catalog](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L81)
- [dated item API links standalone historical business to a Endeavor in place](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L89)
- [dated item API creates standalone and optionally linked historical rows without changing the catalog](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L120)
- [bearer discussion topic remains standalone and seeds independent minutes without private notes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L178)
- [standalone dated item creation requires a section and a draft agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L207)
- [standalone dated item creation rejects a Endeavor from another organization](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L232)
- [dated section reorder requires an exact permutation and returns contiguous order](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L256)
- [dated section reorder scopes the section and rejects locked or unauthorized agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L298)
- [standalone create requires manage agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L324)
- [bearer retry replays a dated section reorder without applying it twice](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L336)
- [Endeavor is added to the exact historical section id](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L358)
- [dated item API rejects a duplicate Endeavor and edits only drafts](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L373)
- [dated item API moves and removes draft snapshot rows](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L390)
- [whole-agenda API deletion removes a published snapshot but keeps Endeavors](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L408)
- [roll-call API lists office ids and replaces the historical snapshot with vacancies](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L423)
- [roll-call refresh uses assignments active on the meeting date](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L451)
- [roll-call API rejects cross-installation office ids](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L474)
- [roll-call API rejects malformed replacement entries](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/agenda_parity_api_test.rb#L490)

## test/controllers/api/calendar_activities_api_test.rb

Reviewed file blob: `3a00b4c4ae3f1b1f13e18bbcd415227d7c3e8f76`.

- [all calendar and task reads require authentication including public preview](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L16)
- [member calendar includes schedules and opt-in deadlines without internal meeting documents](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L23)
- [public projection hides private rows and internal fields in every route](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L42)
- [members cannot mutate and manual agenda grants do not confer calendar management](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L60)
- [current office-derived calendar authority expires in the Post zone across UTC midnight](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L80)
- [handbook documents activity fields and exposes exactly the callers write authority](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L107)
- [date-only input uses local inclusive dates across daylight saving changes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L124)
- [events support dates, omitted end, updates, cancellation and stale locks](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L137)
- [invalid dates, offsets, booleans, and end order are rejected without writes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L162)
- [event and task histories are paginated and include completed or cancelled records](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L176)
- [task creation and completion preserve dates and actor provenance with safe reopening](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L192)
- [organization and parent scoping prevent reads links and writes outside the scope](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L220)
- [project update supports canonical dates alias precedence and stale locks](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L236)
- [bearer mutations require idempotency and replay without duplicate creation](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L251)
- [session writes enforce csrf when protection is enabled](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L284)
- [authorized deletion retries return the original receipt after the target is gone](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L298)
- [calendar retries use the same Post date as the original authority check near midnight](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L319)
- [calendar filters categories and exposes Sunday bounds with safe public categories](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L348)
- [event category writes validate values and preserve omitted overrides](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/calendar_activities_api_test.rb#L366)

## test/controllers/api/website_publications_api_test.rb

Reviewed file blob: `997f0418f60dce9b2feec0e570d2ebfeb0ee8aee`.

- [every editorial route requires authentication and explicit publishing authority](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L16)
- [bearer story workflow prepares reviews publishes features and revokes with audit](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L35)
- [bearer idempotency replays identical images and rejects changed bytes or request payload](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L91)
- [event review source versions and restrictions match admin semantics](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L107)
- [private and stored internal events cannot be approved through editorial API](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L137)
- [draft and image changes invalidate current consent without replacing approved snapshot](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L149)
- [malformed JSON fields fail with structured 422 without mutations](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L165)
- [portrait input is bounded before decoding and source review versions are required](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L193)
- [featured replacement checks complete review and supports empty selection](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L211)
- [publication source and portraits are scoped to this installation](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L227)
- [lists and audit paginate including tombstones and reject invalid filters](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L241)
- [revoked permission and disabled token owner cannot replay an editorial mutation](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L265)
- [session writes require current handbook CSRF and have human-only audit](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L279)
- [handbook includes editorial routes fields and workflow only for publishers](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/website_publications_api_test.rb#L296)
