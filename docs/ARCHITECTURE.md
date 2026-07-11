# Architecture

This document summarizes current architecture and durable product decisions.

## Stack

- Ruby on Rails 8.1.
- PostgreSQL.
- Hotwire/Turbo with importmap.
- Tailwind CSS.
- Action Text is installed and present for planned rich text workflows.
- Active Storage is installed and present for planned file and artifact workflows.
- Solid Queue for background jobs.
- Docker and Kamal for deployment.

## Installation Model

LegionPostTools is currently configured for one organization at a time. It is not a SaaS or multi-tenant platform today.

The schema leaves room for future configurable organizations or units so an American Legion Family deployment could eventually share one installation. Do not deeply model every legal relationship between Post, Auxiliary, Sons, and Riders yet.

## Runtime / Data Topology

Production uses a primary PostgreSQL database plus database-backed cache and queue storage. Rails defaults are used for Solid Queue and Solid Cache, and background jobs run against the database-backed Rails infrastructure.

## Identity Model

- `Person` is the real human being.
- `User` is login access for a person.
- `PositionTitle` defines configurable offices or roles.
- `PositionAssignment` records that a person held a position for a date range.
- `PermissionGrant` controls application capabilities separately from official Legion office.

People can hold multiple positions at once. Position assignments must be historical so old records can show who held an office at that time.

## Authentication

Authentication is passwordless.

- Passkeys are preferred.
- Magic links are the fallback.
- Passwords are intentionally not supported.

The flow is complete end-to-end (registration, sign-in, and passkey management). See
`docs/superpowers/specs/2026-07-11-authentication-flow-design.md`.

- Each user has a stable, opaque, base64url `webauthn_id` used as the WebAuthn user handle —
  never the sequential primary key (which is PII/enumerable and not valid base64url).
- Passkeys require a secure context (HTTPS or `localhost`); they are feature-detected and
  disabled otherwise, always leaving the magic-link fallback available.
- Email delivery is swappable behind the `MailDelivery` seam (`MAIL_PROVIDER`); the WebAuthn
  relying-party origin/id are environment-configured (`WEBAUTHN_*`).

Disabled users must not be able to create new sessions through magic links, passkeys, or existing session cookies.

## Setup

The first-run setup wizard creates the first organization, first person/user, management permissions, meeting bodies, and the American Legion Post preset.

Setup completion is persisted through `Installation`. Once setup is complete, anonymous setup must not reopen even if all admins are later disabled or permission grants are changed.

## Meeting Architecture Direction

Meeting records are the core product direction.

- `MeetingBody` represents recurring groups such as Post Executive Committee or Membership Meeting.
- Future agenda templates should contain structured sections.
- Future agenda items should be structured records, not one large freeform document.
- Rich text belongs inside structured records for notes, bullets, ceremony text, and printable context.
- Tracked items should capture long-lived business such as Car Show, Buddy Checks, elections, or ceremonies.

## Official Records

Accepted official minutes must be immutable. No administrator override should silently edit accepted minutes.

Corrections should appear as later amendments or later meeting records linked back to the original record.

## AI Boundary

AI may draft minutes, summarize transcripts, suggest tracked items, and help place discussion under the right agenda item.

AI output is never official. Humans review, approve, attest, distribute, and accept official records.

Provider-specific AI integration should stay behind replaceable service boundaries. OpenAI is expected first, but the domain should not depend directly on one provider.

## Deferred Architecture

Do not build these prematurely:

- Multi-tenant SaaS.
- Public API.
- Full accounting.
- Broad project management.
- Generic nonprofit feature set.
- Deep Legion Family legal relationship modeling.
