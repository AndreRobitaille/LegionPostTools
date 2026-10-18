# Contact the Post

## Member job and scope

An enabled signed-in member can find the Post's general email and contact its current
officers without searching the full People directory. The combined **Contact the Post**
page helps members choose whom to contact, with the Commander for Post matters and the
Service Officer for veterans' and families' needs. It is a primary destination on desktop
and in the phone Menu. People remains a separate
directory, linked from the contact page. Shared contact links return here after sign-in.

Use the organization's existing `public_email` and optional `mailing_address`. Do not
invent a Post phone number, mailbox recipient, or response-time promise. Andre selected
`wipost165@gmail.com` for Post 165 on October 18, 2026; save it in the organization's
existing email setting rather than hard-coding it into application behavior.
Email and Call actions open the member's email/telephone application; there is no message
form, delivery queue, or automatic sending. Show the addresses/numbers as readable text too.

Current officers come from active Post positions with assignments covering the Post's
local date (inclusive start/end). Lead with Commander and Service Officer, then list
other officers in configured position order. Exclude future/ended
assignments, inactive positions, other organizations' positions, and people hidden from
the member directory. Show each distinct person/position once, retaining multiple current
offices held by the same person. This uses the existing Post-position model; it does not
infer officer/committee/honorary categories from display names, which have no separate
classification in that model. Historical titles never imply a current assignment.
The two standard office names select presentation guidance only; they never confer
authority. Unrecognized/custom positions retain their ordinary contact listing rather
than receiving guessed responsibilities.

Each primary contact has a one-sentence responsibility and two short examples of member
questions. Commander: Post business, concerns, and participation. Service Officer:
connecting veterans and families with benefits guidance and local support. Do not claim
the Post Service Officer is an accredited representative, provides legal/medical advice,
or can promise benefits. If either current officeholder or their direct contact details
are missing, provide a clearly labelled route through the Post email instead.

Other standard Post offices also receive a short responsibility sentence and two examples.
The Assistant Chaplain wording describes assisting the Chaplain, as implied by that preset
title; it makes no independent promise of services.

These are member-facing summaries informed by the [2026 American Legion Officer's Guide](https://www.legion.org/getmedia/9886852f-7570-4d04-85e8-2832116fdb63/27ia0226-post-officers-guide.pdf),
printed pages 19–20 and 26–29. The guide supplies general role context; Andre's instruction
establishes the two main contacts on this page.

Use `directory_email_address` and `directory_phone_number`, including their existing
roster fallback, without revealing login email, private membership fields, or account
state. An officer does not need a login account to be listed. All readers, including
administrators, see this same member contact projection. Changes appear on the next
request, and private contact pages are not cached by HTTP or Turbo snapshots.

When Post email is missing, direct members to officers below. When an officer has no
contact details, explain that directly and refer to the Post contact above. When no
current assignments are recorded, explain the absence without implying offices are vacant.

## Visual direction

Follow The 1919: authority navy `#0A2240`, service gold `#C6A15B`, cream `#F4EEDD`,
paper `#FBF7EC`, and ink `#1B222B`. Use existing system sans, 16px body/actions,
14px secondary details, and at least 13px labels. Reuse the bounded main column,
card, section header, and member-row vocabulary. No new hero or portraits.

The signature is two plain choices based on the member's need, each containing the office,
responsibility, two examples, current officeholder, and direct contact actions. Use the
existing paper cards and gold section rules, with the choices alongside one another on
desktop and stacked below 900px. Follow with the Post email for uncertain questions, then
the other current officers and directory link. Keep the individual contact information
and actions together on both widths.
Keep long names/emails wrapping, visible keyboard focus, and tap targets at least 44px.

```text
Contact the Post
You do not need to know every officer's title to ask for help.

[ Post questions and getting involved ] [ Veteran benefits and support ]
[ Commander                            ] [ Service Officer              ]
[ One sentence + two example questions in each card                       ]
[ Current officer name, contact details, and Call / Email buttons         ]

[ Not sure where to start?                               ]
[ post@example.test                     [Email the Post]  ]
[ Mailing address, when recorded                         ]

◆ Other current officers ─────────────────────────────────
Office
Officer name                                  [Call] [Email]
Phone number · email address

Looking for another member?  View member directory →
```

## Verification

Exercise member navigation, signed-out return after sign-in, account disabling,
directory privacy, inclusive local-date boundaries, officer turnover on later requests,
multiple offices, inactive/foreign positions, and missing contact data with synthetic
records. Check actual mailto/tel destinations without sending mail or placing calls.
Render desktop, tablet, 390px and 320px layouts; inspect screenshots, focus, readability,
and horizontal overflow. Use only the test database for browser fixtures.

### Initial implementation verification — October 18, 2026

- `bin/rails test`: 1,518 tests, 15,774 assertions, zero failures/errors/skips.
- `bin/rails test test/system/post_contacts_test.rb test/system/workspace_navigation_test.rb`:
  7 browser tests, 164 assertions, zero failures/errors/skips. After final page spacing
  refinement, the two contact browser tests passed again with 59 assertions.
- Focused RuboCop: all 11 changed Ruby files passed. Brakeman: zero errors or security
  warnings. `git diff --check` passed.
- Inspected synthetic screenshots at desktop and phone widths, including long contact
  details and keyboard focus. Browser assertions checked 1400px, 900px, 390px, and 320px
  layouts, 44px contact buttons, text sizing, and no horizontal overflow. Captures are
  under `tmp/contact-the-post/screenshots/`.

These checks exercise the Rails page and rendered link destinations. They do not send
email, place calls, verify an external email/phone application, or establish production
deployment. No real member records were used for the preview.

### Member guidance revision — October 18, 2026

- Saved `wipost165@gmail.com` in the local development organization's `public_email`
  setting and verified the persisted value. No production connection was used.
- Contact, primary navigation, and shared-link sign-in tests: 30 tests, 333 assertions,
  zero failures/errors/skips. They include primary-contact guidance and ordering,
  missing-officer/contact fallback, and preserving the configured order for other uses.
- The two contact browser workflows passed with 84 assertions after the layout and
  wording changes, including desktop, tablet, 390px, and 320px layouts. Refreshed synthetic
  screenshots show the two main contacts and the chosen Post email.
- Focused RuboCop passed for the four changed Ruby files; `git diff --check` passed.
  The earlier full-suite and Brakeman results above describe the initial implementation,
  not a repeat of those checks after this revision.

### Release verification — October 18, 2026

- Final application suite: 1,520 tests, 15,811 assertions, zero failures/errors/skips.
- Full browser suite: 110 tests, 5,904 assertions, zero failures/errors/skips.
- RuboCop: 648 files, no offenses. Brakeman: zero errors or security warnings.
- Bundler Audit and Importmap Audit found no vulnerable dependencies.
- Release transport preflight passed using one retained SSH control master. The live
  revision was confirmed to be an ancestor of the release base before deployment.

These are local checks and transport evidence; production deployment and the saved
production email require separate verification after the release.
