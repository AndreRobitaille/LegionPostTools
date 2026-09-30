# Meeting-specific discussion topics

## Purpose and behavior

A Post needs to put an early proposal or isolated matter before a meeting without
first creating a reusable catalogue entry or a continuing Endeavor. Each editable
agenda section offers **Add discussion topic** alongside **Add catalog item** and
**Add Endeavor**.

The form requires a title and offers optional rich-text discussion details and
Commander & Adjutant notes. The selected section is carried into the form and may
be changed before saving. Document visibility controls retain the existing agenda
and draft-minutes behavior; planned discussion wording is not evidence of a decision.

A topic is an ordinary, active `DatedAgendaItem` with `business_item` behavior and
no catalogue, template, or Endeavor link. Saving appends it to the selected section
under the agenda lock. Only users with `manage_agendas` may create it, and only on
a draft agenda. Sections are resolved through that agenda, and approval/publication
is checked again inside the lock. Validation errors keep the entered wording and
selected section available for correction.

Existing editing, ordering, removal, member agenda, PDF, and draft-minutes workflows
apply to these items. This feature does not introduce a new record type or migration.
If continuing work is later warranted, a human deliberately decides to create or
link an Endeavor; this feature does not automate that decision or add a promotion
workflow. The private API supports the same standalone agenda creation and subsequent
draft-minutes confirmation; see [API contract](DISCUSSION_TOPICS_API.md) for exact
fields, current-grant requirements, AI review, and safe retries.

## Visual direction before implementation

Follow The 1919 system: authority navy `#0A2240`, working navy `#0D2C54`, Legion gold
`#C6A15B`, ivory `#FCFAF1`, officer blue `#2F5F87`, and graphite `#303740`. Working
controls use system sans; rendered agenda content continues to use Georgia.

Use the existing bounded form panel, gold-ruled meeting destination, and separate
blue private-notes fieldset. The meeting and section selector anchor the form: an
officer sees exactly where the topic will appear before entering text. Add a quiet
text action to the existing section footer, with the same 44px target as the other actions.
Avoid a new card chooser or additional item-kind decision for this simple task.

```text
Draft agenda section
  ... current items ...
  + Add discussion topic    + Add catalog item    ◆ Add Endeavor

Add discussion topic
  A topic for this meeting. It does not create an Endeavor or catalogue item.
  | Meeting: Membership Meeting |
  Agenda section [New Business v]
  Topic title [                                             ]
  Member agenda and minutes
    Discussion details (optional) [rich-text editor]
    Existing wording visibility controls
  Commander & Adjutant notes [private rich-text editor]
  [Add discussion topic]  [Cancel]
```

The section actions wrap naturally at narrow widths. Text follows the established
16px interactive/body, 14px helper, and 13px label floors. Desktop and 390px rendered
review must check destination clarity, form hierarchy, focus, validation, and overflow.

The rendered critique retained the bounded form and private blue notes treatment.
The context badge identifies the meeting, while the selector identifies the section;
repeating the initial section in the badge would become misleading if it were changed.
At 390px the fieldset headings and section actions wrap without horizontal overflow,
and the rich-text toolbar keeps its overflow menu inside the form. Keyboard navigation
from the title reaches the discussion editor.

## Verification scope

Controller coverage checks permissions, selected-section scope, fixed standalone
identity, content and visibility controls, validation retention, and locked agendas,
while retaining catalogue insertion coverage. Browser coverage creates a topic from
its section, checks desktop/narrow layout, and follows it into member output and
draft minutes with private notes excluded. Relevant existing agenda, PDF, minutes,
and API tests protect downstream behavior.

Verified locally September 30, 2026:

- Application suite: 1,041 tests, 7,591 assertions, no failures/errors/skips.
- Final topic/controller checks: 36 tests, 251 assertions, no failures/errors/skips.
- Browser suite: 38 tests, 446 assertions, no failures/errors/skips; desktop and 390px
  screenshots reviewed, including the complete form and section actions.
- RuboCop: four Ruby files, no offenses. Brakeman: no warnings or errors.
- Bundler Audit: no vulnerabilities found. Diff whitespace and documentation references
  checked. Brakeman used a temporary writable gem cache under `/tmp`.
