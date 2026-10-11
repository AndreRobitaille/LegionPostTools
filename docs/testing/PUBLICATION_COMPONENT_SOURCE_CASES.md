# Exact publication component source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, five fully read files / 26 exact cases.
Source review is separate from execution, fault evidence and production publishing.

## test/controllers/public_publishing_test.rb

Reviewed file blob: `fe4bdff934a4446e8f73b5f8a9000febe70786ca`.

- [empty collections are complete authenticated and conditional metadata is current](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L13)
- [rotation edits replacement withdrawal and consent are reflected even on conditional requests](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L35)
- [events use exact overlap boundaries point ends all day DST and stable ordering](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L70)
- [moves cancellation removals invalidate validators and never leak private parents](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L92)
- [invalid bounds methods unknown identities and outage have safe no-store errors](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L114)
- [throttled requests return a no-store 429 with retry advice](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L137)
- [93 day interval is complete and spring DST uses local midnight](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/public_publishing_test.rb#L147)

## test/controllers/website_publishing_admin_test.rb

Reviewed file blob: `ba3146f17c778c25eb5468b4df95ce817c916d78`.

- [workspace requires explicit permission and stale review is rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/website_publishing_admin_test.rb#L14)
- [draft consent and feature HTML forms publish and rotate synthetic content](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/website_publishing_admin_test.rb#L35)
- [HTML calendar edits cancel restrict and delete public snapshots](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/website_publishing_admin_test.rb#L50)
- [bearer API applies the same restrictions and cannot approve eligibility](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/website_publishing_admin_test.rb#L73)

## test/models/website_publication_test.rb

Reviewed file blob: `01aa6a6ca88fe7dfc5267827ebd402584b47e1a9`.

- [technical admin is not a publisher and office grants work without calendar authority](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L9)
- [draft changes leave snapshot unchanged and need renewed consent](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L23)
- [stale reviews cannot undo consent revocation or withdrawal and republishing never restores selection](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L37)
- [featured order is limited and rotating preserves detail](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L51)
- [calendar changes are pending cancellation is sticky and old reviews conflict](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L61)
- [private internal and deletion restrictions retain tombstones and history](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L80)
- [title warning survives other override and internal stored categories block eligibility](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L103)
- [source deletion protection and permanent identity are preserved](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L113)
- [portraits are fixed size metadata stripped and invalid content rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L121)
- [legacy visibility alone never publishes and eligibility needs a reviewed source version](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_test.rb#L131)

## test/models/website_publication_concurrency_test.rb

Reviewed file blob: `448af1236ceaeee98e8a3ae0e091ce30bee25a47`.

- [automatic calendar activation serializes with listing restrictions in both commit orders](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_concurrency_test.rb#L23)
- [both real commit orders serialize publication against every source restriction and edit](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_concurrency_test.rb#L42)
- [both commit orders serialize publication against withdrawal consent revocation and draft edits](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_concurrency_test.rb#L78)
- [HTML and bearer API source restrictions race safely with publish in either commit order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/website_publication_concurrency_test.rb#L102)

## test/system/website_publishing_test.rb

Reviewed file blob: `26eaf6ec2de9377640b6869e89f8fc02be0ccec2`.

- [publisher reviews both portrait sizes consents publishes rotates and withdraws at phone width](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/website_publishing_test.rb#L12)
