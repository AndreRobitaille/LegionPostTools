# Calendar component source and assertion review

Bounded #84 source review at b965cf76, October 11, 2026. CALENDAR.md and CALENDAR_API.md
keep the member calendar, optional task deadlines, actual occurrences and private event
management distinct. Post-local calendar dates and fixed meeting snapshots are established
calendar contracts; this slice does not decide #93's general officer-authority date.
Printing preserves chosen filters and screen view, complete plain descriptions and saved
meeting addresses, readable low-ink landscape month / portrait schedule and quarter-inch
insets on continuation pages. Public preview excludes private meeting details.

Read all seven complete files /52 cases, fixtures, helpers and assertions. Exact case
names/lines and blobs in [CALENDAR_COMPONENT_SOURCE_CASES.md](CALENDAR_COMPONENT_SOURCE_CASES.md).
Recorded b965cf76 actual-main all-four CI38122975568 passes ordinary1297/11980 then
system74/1598, zero failures/errors/skips. Source reading adds no new execution or
universal fault proof. No application or test edits belong to this slice.

| Exact file / cases | Starting state, action, saved/visible/subsequent outcome and limits |
| --- | --- |
| `test/controllers/calendar_controller_test.rb` /21 | Authenticated nonempty member month/navigation without controls, selected/explicit-empty PDF filters with restored fake renderer, controlled rendering error guidance and invalid dates. Real denied member/delegate writes keep title/count; fixed Post-zone office expiry around UTC midnight; actual public linked create/edit/cancel provenance, inclusive all-day dates, invalid/stale/cross-Post refusals. Screen/print filters, escaped descriptions, saved address exclusion from public preview, optional deadlines, Sunday navigation, forgiving time parsing and fixed winter/summer UTC conversions remain distinct. Fake PDF is wiring, not rendered bytes; invalid-render-before case has no invocation assertion, and many refusal graphs are partial. |
| `test/controllers/calendar_event_deletion_test.rb` /5 | Actual HTML member/current-lock/stale refusal and deletion preserve linked Endeavor attributes; real bearer API scopes foreign events, retains foreign/linked records and replays deletion without a second write. Fixed membership/PEC titles/categories refuse model/HTML/API deletion; a real Meeting survives the event-route action; handbook advertises explicit deletion only to managers. Some preservation fixtures have no nonempty Meeting/minutes graph, and coinciding route IDs do not prove every separate CalendarEvent is protected. Original protected deletion and API guards remain independent. |
| `test/models/calendar_event_test.rb` /8 | Fixed public allowlist excludes private Endeavor/ownership data and restores privacy after visibility changes; actual overlap excludes out-of-month/foreign-Post events; unsaved missing parent/end/visibility validation; completed tasks/Endeavors omit deadlines; fixed Post meeting/service categories and explicit overrides; public/planning/volunteer/Honor Guard distinctions and outside-request Post-midnight/deadline dates. These are component projections/classification, separate from routed authorization, actual publication and #93's governing date decision. |
| `test/system/calendar_event_deletion_test.rb` /1 | Real magic-link manager at1280/390 sees current event, cancels native confirmation without deleting, then confirms removal; protected PEC has no delete control and useful text; viewport restores. This remains distinct from bearer replay/foreign/stale and nonempty saved-graph tests. |
| `test/system/calendar_mobile_schedule_test.rb` /1 | Real member at390/320/1400 reads nonempty long-place/cancelled/planning/Honor Guard/public day groups; narrow overflow and desktop schedule, keyboard focus and subsequent own-event navigation. It does not assert all body type floors or publication/management writes. |
| `test/system/calendar_refinements_test.rb` /3 | Real manager desktop/narrow filters survive navigation, shorthand800 becomes08:00 and actual saved event appears. Real member omits manager/developer controls, discovers nonempty events, switches print/screen, keeps empty selection after refresh and restores Honor Guard keyboard focus/URL; fixed details/colors/timezone distinguish timed/all-day records at desktop/narrow widths. Current print media resets occur after assertions; teardown resizes only. Potential failure-path media leakage is a candidate for bounded reproduction, not an established application bug or new runtime result. |
| `test/system/calendar_print_test.rb` /13 | Nonempty17-event synthetic month covers actual screen/print styling, full titles/readable sizes/cancellation/location/paragraphs, selected filters and unchanged Month/Schedule state. Real authenticated phone PDF response has private inline/no-store metadata, exact filter/view query and parsed saved title/final instruction; actual server renderer and native CDP printing distinguish transport from paper. Five/six-week page sizes, phone320/390 two-layout print, cancellation, no today marker, zero-margin override, empty selection, crowded continuation, saved meeting address and long paragraphs remain unique. Poppler bbox helpers require every page nonempty and every extracted word inside independent17.5-point bounds; orientations use fixed792x612/612x792 dimensions. Optional saved PDFs/screens are not automatic visual inspection; MediaBox regex is not a general PDF parser, and selected font assertions do not prove every glyph. Teardown restores screen media and viewport even after failed assertions. |

Retain every meaningful component and browser assertion. Parsed every-page geometry,
actual server PDF delivery, native print/cancel state, routed refusals and saved event
semantics detect different failures. No safe consolidation/deletion is established.
Source reading does not certify Safari, physical printers, live publication, every
permission race, real member data or production state. #79/#93 remain separate decisions.
