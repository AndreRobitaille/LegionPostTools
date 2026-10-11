# Exact installation and offline adapter source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, eight fully read files / 39 exact cases.
Source review is separate from execution, external acceptance and production state.

## test/controllers/setup_controller_test.rb

Reviewed file blob: `2eb0f596dafb66479d6a6d0095185708073677cd`.

- [shows setup when app has no organization or user](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L4)
- [creates organization first person user permissions and preset data](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L12)
- [rejects invalid setup params](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L53)
- [setup cannot be reopened after setup exists](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L81)
- [organization only still shows setup](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L93)
- [user without organization still shows setup](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L103)
- [both organization and user without setup completion redirects new setup to session sign in](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L115)
- [both organization and user without setup completion blocks setup post](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L126)
- [disabled admin after setup does not reopen setup](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L155)
- [repeated setup post after completion does not create duplicates](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L169)
- [partial organization only post reuses organization and creates first user](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L198)
- [partial user only post reuses user and creates organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L233)
- [partial organization only state can still be repaired before completion](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/setup_controller_test.rb#L268)

## test/controllers/admin/dashboard_controller_test.rb

Reviewed file blob: `b4650e1e96abb7ee04e730f7943e44a17933d65a`.

- [unauthenticated admin root redirects to sign in](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L4)
- [member with no admin capability is denied](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L10)
- [full admin sees all administration groups and their links](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L22)
- [agenda-only manager reaches the hub and sees the agenda tiles](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L47)
- [scoped officer pages return to officer tools](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L70)
- [minutes manager reaches the hub and sees meeting records and background jobs](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L81)
- [roster tile reads current when a recent import exists](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L95)
- [roster tile turns due and flags an overdue import](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L108)
- [roster tile flags when no roster has been imported](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dashboard_controller_test.rb#L120)

## test/integration/direct_upload_security_test.rb

Reviewed file blob: `093fb21dc7142f588acabf6bc569b598de0e92cb`.

- [anonymous clients cannot create blobs even with their own valid CSRF token](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/integration/direct_upload_security_test.rb#L5)
- [signed-in users cannot issue upload capabilities with alternate content types](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/integration/direct_upload_security_test.rb#L25)

## test/models/organization_test.rb

Reviewed file blob: `cf4b2b3d1ae9523a59ffeb4a6781088b0ebfc72e`.

- [normalizes and validates the public document email](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/organization_test.rb#L4)
- [limits the printed mailing address to two nonblank lines](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/organization_test.rb#L21)

## test/services/american_legion_post_preset_test.rb

Reviewed file blob: `7bdc1638394f58ecf8921b41fb61ad8c7ecf2b33`.

- [creates standard post titles and meeting bodies](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/american_legion_post_preset_test.rb#L4)
- [can be applied more than once without duplicates](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/american_legion_post_preset_test.rb#L42)
- [restores preset values without creating duplicates](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/american_legion_post_preset_test.rb#L55)

## test/services/mail_delivery_test.rb

Reviewed file blob: `31c6bceca465e858672d82c0529e7a3177f556eb`.

- [delegates to the configured backend](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/mail_delivery_test.rb#L11)
- [action mailer backend enqueues the magic-link email](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/mail_delivery_test.rb#L31)
- [loops backend posts email, template id, and data variables](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/mail_delivery_test.rb#L39)
- [loops backend raises a diagnosable error when the provider rejects delivery](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/mail_delivery_test.rb#L59)

## test/services/openai_sdk_contract_test.rb

Reviewed file blob: `7461e19f84c02155cfa3bf8b2dd3b67b66523538`.

- [minutes creation polling and cancellation use the SDK Responses contract](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/openai_sdk_contract_test.rb#L24)
- [invalid output preserves identifiers from SDK response models](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/openai_sdk_contract_test.rb#L47)
- [Endeavor accounting reads usage from SDK response models](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/openai_sdk_contract_test.rb#L58)

## test/services/endeavor_history/provider_test.rb

Reviewed file blob: `46a537a68fb0bb609b3ebf33eb710db832579657`.

- [Astra requests use stage reasoning strict structured output and no sampling parameters](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/endeavor_history/provider_test.rb#L4)
- [refused and incomplete responses never become a parsed result](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/endeavor_history/provider_test.rb#L32)
- [Sol writes and checks summaries at high effort while Astra checks full source discovery](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/endeavor_history/provider_test.rb#L41)
