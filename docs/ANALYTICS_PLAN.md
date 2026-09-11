# Analytics plan v6

## Цель

Аналитика отвечает на четыре вопроса: проходит ли игрок первый опыт, где выпадает
из раунда, понимает ли метапрогрессию и остаётся ли экономика честной. События не
должны содержать свободный пользовательский текст, DisplayName или приватный party
состав.

## Реализованные каналы

`AnalyticsService` централизует безопасные вызовы Roblox AnalyticsService:

- generic custom events через `LogCustomEvent`;
- onboarding steps через `LogOnboardingFunnelStepEvent`;
- funnel steps через `LogFunnelStepEvent`;
- economy movements через `LogEconomyEvent`;
- progression completion через `LogProgressionCompleteEvent`.

В Studio события считаются локально для smoke visibility; platform failures не
ломают gameplay.

## Cardinality contract

Dashboard dimensions должны быть только низкой кардинальности: allowlist ID
palette/action/reaction, phase, route family, modifier, device class, locale,
quality tier, read-only boolean и заранее заданные reason/status buckets.

`sessionId`, `roundId`, `userId`, target user ID, receipt ID, postcard ID и Atelier
ID запрещены в `customFields`/custom dimensions. Если Roblox funnel API требует
occurrence ID для дедупликации, `roundId` передаётся только в специальный аргумент
`funnelSessionId`, не копируется в metadata и не строит dashboard dimension.
Идемпотентные receipt/grant IDs остаются в серверных ledger, а не в аналитике.

## Funnel taxonomy

### Onboarding / First Miracle

| Step | Имя | Success signal |
|---:|---|---|
| 1 | Joined Game | profile loaded, schema metadata sent |
| 2 | First Miracle Bloom | сервер перевёл onboarding в Bloom после 3 действий, timeout или skip |
| 3 | First Run Started | новый игрок вошёл в первый игровой run |
| 4 | First Bloom Completed | первый полноценный World Bloom дошёл до Results |

Дополнительные low-cardinality custom events: `first_miracle_started`,
`first_input`, `first_movement`, `first_world_reaction`, `first_miracle_palette`,
`first_miracle_action`, `first_miracle_complete`, `pre_act_join` и
`backstage_apprentice_join`. Разрешённые
dimensions — allowlist `paletteId`, `actionId`, порядковый action bucket, completion
reason, entry phase/choice и read-only boolean. Session/user ID не передаются. Config гарантирует переход
в First Miracle Bloom не позднее 30 секунд, однако KPI измеряет фактическое время и
отдельно различает normal, timeout и skip completion.

`first_input` означает принятый ручной выбор палитры или первое подтверждённое
действие в мире после автоподбора. Timeout/resume, skip, невалидные запросы и
повторный snapshot не считаются игровым вводом. Событие дедуплицируется на сервере
для активного игрока и onboarding-сессии; безопасный `input` bucket — `palette`
или `world_action`. Это не межсерверный durable ledger и не подтверждение
уникальности события после reconnect: dashboard считает конверсию по игрокам.

### Round funnel

Рекомендуемые шаги: Intermission joined → brief vote → route vote → act 1 complete →
act 2 complete → act 3 complete → MixLab ready → World Bloom → Results → Requeue.
`roundId` используется только как funnel occurrence ID для дедупликации; повторный
snapshot не создаёт новый run, а ID не становится custom dimension.

### Social creation

- Postcard Created — step 1, metadata только world ID.
- Postcard Remixed — step 2, metadata только missing item count.
- Positive reaction — custom event с reaction allowlist ID.
- Atelier created/joined — custom event без названий/текста.

### Premium hub / City Pulse

- `city_pulse_impression`: allowlist event ID, один раз на событие для присутствующего игрока.
- `city_pulse_first_pad`: allowlist event ID и pad ID, один раз за событие/игрока.
- `city_pulse_step`: allowlist event ID, pad ID и progress quartile.
- `city_pulse_complete`: allowlist event ID и число участников только для внесших вклад.
- `city_pulse_next_run`: allowlist event ID, когда взаимодействовавший игрок входит
  в следующий `BriefChoice`.
- Один физический контакт не должен создавать больше одного вклада за cooldown;
  прогресс считается сервером, а world/UI replication coalesced до 12 обновлений/с.
- Воронка impression → first pad → complete → next run реализована без player/round
  ID в custom dimensions. Dashboard conversion строится только после закрытого запуска.

### Economy

Для каждой movement фиксируются flow type, currency `GlowDust`, amount, balance,
source/sink ID и безопасные catalog metadata. Paid receipt и earnable reward нельзя
склеивать в один source.

### Progression

Creative Rank и пять Aura Atlas schools логируются при level completion. Для
late join полезны `participationRole`, bucketed ratio, acts joined/completed — без
персональных данных других участников.

## Core metrics

- First world reaction ≤ 15 s, First Miracle completion ≤ 30 s и median completion time.
- First Miracle completion → participant handoff: BriefChoice/active act conversion без ожидания следующего раунда.
- Brief vote, route vote, act completion, Mix ready, Finale и Results conversion.
- Late-join acceptance → Finale conversion относительно full runners.
- Requeue rate после первого и последующих раундов.
- Daily/weekly quest completion, reroll use и bank recovery.
- Creative Rank / school level velocity и mastery unlock rate.
- GlowDust earned/spent/paid ratio, sink coverage и отрицательный balance count (должен быть 0).
- Postcard create→remix, positive reaction, Atelier participation.
- Community contribution/claim conversion.
- City Pulse first interaction, completion, contributors bucket и переход в следующий забег.
- D1/D7/D30 retention, play days и intentional co-play cohorts после накопления
  достаточного объёма; локальный Studio run не является retention evidence.
- Error/save/read-only/duplicate receipt counts.

## Guardrails

- Не использовать аналитику для body/beauty scoring.
- Не отправлять custom look names, postcard content, DisplayName, free text или party member IDs.
- Никогда не помещать `sessionId`, `roundId`, `userId`, target user ID, receipt ID
  или content-instance ID в custom dimensions; occurrence/idempotency обрабатываются
  отдельным funnel API и серверными ledger.
- Все суммы и balance логировать после server mutation.
- Событие не является источником истины для entitlement.
- При выключенном `Analytics` gameplay и persistence продолжают работать.

## Release dashboard checklist

1. Проверить event names и funnel step ordering в закрытом universe.
2. Убедиться, что retry/snapshot не дублируют шаги.
3. Разделить desktop/touch/gamepad, locale и quality tier безопасными dimensions.
4. Добавить alert на save failures, round recovery, receipt retry и negative balance.
5. Сравнивать cohorts только после достаточного объёма; не объявлять retention успехом
   по локальному Studio smoke.
