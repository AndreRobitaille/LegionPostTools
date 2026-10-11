# Exact continuing Post work source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, six fully read files / 37 exact cases.
Source review is separate from execution, paid processing and production state.

## test/controllers/endeavor_tasks_controller_test.rb

Reviewed file blob: `9371829fff2de8e8a3686da8b10017b0cbcf3156`.

- [members can read next steps but cannot create or change them](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L14)
- [manager creates dated and undated steps without creating calendar events](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L31)
- [completion and reopening preserve the next step and record provenance](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L46)
- [invalid date remains in the form and does not save](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L62)
- [stale completion cannot overwrite an edited step](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L71)
- [task lookup is scoped to its Endeavor](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L81)
- [overall due date supports new terminology and preserves legacy storage](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_tasks_controller_test.rb#L89)

## test/controllers/endeavor_updates_controller_test.rb

Reviewed file blob: `7ce04438dcdadc1ca04eb4e85e2a3044367061a2`.

- [manager adds an append-only update](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_updates_controller_test.rb#L12)
- [blank update gives plain guidance](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_updates_controller_test.rb#L25)
- [plain member cannot add an update](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_updates_controller_test.rb#L36)

## test/controllers/endeavors_controller_test.rb

Reviewed file blob: `4853f89dff0bc7b1573176285e462e5d2a708a51`.

- [signed out users are redirected](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L21)
- [signed in members can read Endeavor and continuity](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L27)
- [completed Endeavor shows completion instead of overdue planning language](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L44)
- [continuity promotes an attested meeting from agenda to minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L61)
- [manager creates Endeavor](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L90)
- [plain member cannot create or edit Endeavor](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L112)
- [create rejects another organization's meeting body](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L123)
- [manager updates and completes then reopens an item](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L134)
- [stale edit redirects with a useful conflict message](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavors_controller_test.rb#L151)

## test/models/endeavor_test.rb

Reviewed file blob: `ba2b18fe854ef2e8d44a210195766f72beed053c`.

- [priority bucket combines importance and a thirty day urgency window](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/endeavor_test.rb#L10)
- [meeting body must belong to the same organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/endeavor_test.rb#L24)
- [complete and reopen record a human-controlled lifecycle](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/endeavor_test.rb#L34)
- [completion and reopen reject invalid transitions](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/endeavor_test.rb#L51)

## test/models/endeavor_update_test.rb

Reviewed file blob: `b5793943cbe9819b2b23482962971792f002907a`.

- [requires meaningful update text](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/endeavor_update_test.rb#L10)
- [updates cannot be edited or deleted](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/endeavor_update_test.rb#L17)

## test/controllers/endeavor_histories_controller_test.rb

Reviewed file blob: `26941187f78d4bb1af5ee2c1425828406ca80148`.

- [member sees history but no management controls and cannot access or mutate AI history](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L12)
- [manager can inspect history and save guidance with optimistic locking](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L26)
- [history manager gets Jobs without gaining minutes-run access](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L41)
- [history management reports reused work separately from paid attempts](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L52)
- [unpublished agenda metadata does not appear in member history or API](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L66)
- [other organizations history is not accessible](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L96)
- [source reader returns only the requested current related passage or outcome](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L106)
- [source reader rejects signed out cross organization and draft sources](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L125)
- [page navigation is public while all officer controls remain capability gated](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L146)
- [management overview is scoped and capability gated without starting processing](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L164)
- [overview detects changed inputs and preserves published date across failure and withdrawal](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L190)
- [overview distinguishes not generated and newly available minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/endeavor_histories_controller_test.rb#L215)
