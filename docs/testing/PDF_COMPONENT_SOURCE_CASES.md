# Exact PDF component source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, seven fully read files / 40 exact cases.
Source review is separate from recorded execution and representative fault evidence.

## test/services/calendar_pdf_test.rb

Reviewed file blob: `cf31f57557c36c4e32e238e03b87d897c97eb027`.

- [filename identifies the selected month and view](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/calendar_pdf_test.rb#L9)
- [signed token binds the organization month view and categories](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/calendar_pdf_test.rb#L13)
- [render uses the bounded browser renderer and a signed loopback source](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/calendar_pdf_test.rb#L18)
- [tokens expire after one minute](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/calendar_pdf_test.rb#L36)
- [signed but invalid selections fail closed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/calendar_pdf_test.rb#L43)

## test/services/dated_agenda_pdf_test.rb

Reviewed file blob: `38e1b5f1db663795fc8b03fb2f7f909c73af3881`.

- [builds descriptive filenames for both document variants](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/dated_agenda_pdf_test.rb#L17)
- [filenames use the saved agenda title after the template is renamed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/dated_agenda_pdf_test.rb#L22)
- [signed source token fixes the organization agenda and variant](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/dated_agenda_pdf_test.rb#L30)
- [rejects unknown document variants](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/dated_agenda_pdf_test.rb#L43)

## test/services/meeting_minutes_pdf_test.rb

Reviewed file blob: `ba9c60d6f89266028ea8509bf2d39b800a299c86`.

- [builds a descriptive draft filename](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_minutes_pdf_test.rb#L26)
- [filename identifies attested minutes without calling them official](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_minutes_pdf_test.rb#L33)
- [draft filename uses the saved minutes title after the template is renamed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_minutes_pdf_test.rb#L42)
- [attested filename uses the immutable revision title](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_minutes_pdf_test.rb#L49)
- [signed source token fixes the organization and minutes record](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_minutes_pdf_test.rb#L61)

## test/controllers/calendar_pdf_sources_controller_test.rb

Reviewed file blob: `c1e3f32a050a18889e15fb9038eaf5b487ba352d`.

- [source renders both layouts without a member session or officer controls](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L18)
- [source keeps the signed filters despite unsigned query overrides](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L34)
- [empty category selection hides all events without reverting to defaults](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L44)
- [public preview excludes member events meetings and private endeavor context](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L50)
- [source uses the organization in the signature](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L59)
- [source limits resources to allowed print assets](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L69)
- [source rejects missing invalid expired and non-local tokens](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L80)
- [source rejects a missing organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/calendar_pdf_sources_controller_test.rb#L94)

## test/controllers/dated_agenda_pdf_sources_controller_test.rb

Reviewed file blob: `8fe9e67119cf5d0d61045d35f515818d00a02ba1`.

- [member source is a chrome-free print document without officer content](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agenda_pdf_sources_controller_test.rb#L54)
- [officer source includes private cues and roll call](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agenda_pdf_sources_controller_test.rb#L72)
- [both PDF variants retain the saved title after the template is renamed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agenda_pdf_sources_controller_test.rb#L82)
- [source restricts resource requests and marks embedded images without editing their source](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agenda_pdf_sources_controller_test.rb#L94)
- [source rejects invalid tokens](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agenda_pdf_sources_controller_test.rb#L124)
- [source rejects non-loopback requests](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agenda_pdf_sources_controller_test.rb#L130)

## test/controllers/meeting_minutes_pdf_sources_controller_test.rb

Reviewed file blob: `086574699349ea977b688c938b64c2aa7167441d`.

- [source is a chrome-free draft document with minutes content](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L43)
- [immutable minutes use the same resource policy and preserve the stored revision](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L77)
- [attested source renders the immutable revision with truthful authority on every page](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L95)
- [membership-approved source renders the exact revision as official](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L115)
- [direct Adjutant attestation has no Commander endorsement and pending corrections are labeled truthfully](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L160)
- [member source prints the immutable snapshot while officer corrections remain private](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L192)
- [member source rejects handed-off or superseded revisions even with a valid signature](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L225)
- [member source rejects unrelated revisions non-loopback access and expired tokens](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L250)
- [source rejects invalid tokens](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L266)
- [source rejects non-loopback requests](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/meeting_minutes_pdf_sources_controller_test.rb#L271)

## test/system/pdf_resource_security_test.rb

Reviewed file blob: `06bab4b9052c081b159933bc2c36948013d4348f`.

- [PDF sources preserve document design and block resources before any request](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/pdf_resource_security_test.rb#L48)
- [native Chromium produces agendas notes and minutes without contacting embedded media](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/pdf_resource_security_test.rb#L87)
