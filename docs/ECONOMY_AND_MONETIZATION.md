# Экономика и монетизация v3

## Экономические контуры

`GlowDust` — косметическая валюта. Она не повышает скорость, challenge score,
team target или XP multiplier. Creative XP и Aura Atlas XP зарабатываются только
через участие/мастерство и не продаются.

Источники earnable GlowDust:

- завершение и результаты раунда;
- challenge actions в пределах server caps;
- daily/weekly quests;
- Community Canvas milestones.

Списания:

- только catalog-defined GlowDust cosmetics;
- никакого скрытого roll, gacha или неизвестного содержимого.

## Progression

- Creative Rank: 1–100, общий total XP; стоимость следующего ранга возрастает
  детерминированно.
- Aura Atlas: Color, Texture, Motion, Camera, SetDesign, уровень 1–20.
- Category→school: palette→Color, material→Texture, aura→Motion, pose→Camera,
  accent→SetDesign.
- Mastery cosmetics проверяются по school level и выдаются автоматически один раз.
- Late join получает proportional participation base; выполненные действия всё ещё
  учитываются в пределах server caps.

## Quest economy

Каждый UTC-день генерируются три детерминированных задания из набора round/thread/
beat/perfect/prism/style. Есть один бесплатный reroll, банк незавершённых daily на
пять дней и grace credit для мягкого streak. Weekly содержит четыре задания.
Quest reward выдаётся сразу при completion через отдельный idempotency key.

## Ledger model

| Ledger | Назначение | Пример ключа |
|---|---|---|
| `paidReceipts` | Roblox developer product receipt | purchase ID |
| `grants.rounds` | итог одного раунда | `roundId` |
| `grants.events` | вклад/milestone | event + contribution/milestone ID |
| `grants.quests` | progress/reward задания | quest event/reward ID |
| `grants.mastery` | permanent mastery unlock | `item:<catalogId>` |
| `grants.system` | безопасные system grants | namespaced ID |
| `spends` | currency spends | уникальный spend ID |

Compatibility-поля v1 не используются как общий ledger. Лимиты и timestamp trim
не позволяют профилю расти бесконечно.

## Paid catalog

| SKU | Grant | Gameplay power |
|---|---|---|
| GlowDust Pocket | 250 GlowDust | нет |
| GlowDust Bundle | 900 GlowDust | нет |
| GlowDust Vault | 3000 GlowDust | нет |
| Glowstorm | 1 `glowstorm` activation token | нет; server event + client-local visual |
| Signature Prism Collection | Solar Flare palette + Glitch Halo aura + Editorial Turn pose | нет; точный список |

Signature collection не содержит mastery items. Glowstorm сначала сохраняется как
token: prompt и effect разделены, поэтому игрок не теряет покупку при переходе между
серверами. При activation сервер проверяет balance/cooldown и реплицирует marker;
каждый клиент строит доступный локальный visual. Если launch не удался, token возвращается.

Pass definitions `director_pack`, `atelier_pro`, `prism_patron` и subscription
`aura_club` — только заготовки каталога. Нельзя включать их до реализации и
серверного теста каждой заявленной benefit.

## Store и receipts

- Robux prices не хранятся в коде; UI запрашивает персональную региональную цену.
- ID `0`/`""`, unpublished/read-only session и выключенный feature flag блокируют prompt.
- Store не открывает prompt автоматически.
- `ProcessReceipt` остаётся способным обработать повторную доставку.
- Entitlement подтверждается только после durable save.
- Duplicate receipt возвращает уже применённый результат без повторного grant.
- Unknown product не выдаёт ничего.

## Feature rollout

Текущее состояние RC:

```text
Purchases = false
Passes = false
Subscriptions = false
all product/pass IDs = 0
subscription ID = ""
```

Порядок включения: закрытый product test → telemetry review → `Purchases`; затем
отдельные benefit implementation/test → `Passes`; subscription lifecycle/reconnect/
renewal test → `Subscriptions`. Одновременное включение всех флагов запрещено
операционным планом.

## Запрещённые практики

- pay-to-win, XP/mastery boost, priority challenge target;
- loot boxes, скрытые odds или замаскированная цена;
- auto-prompt, искусственный дефицит без даты, таймер давления;
- продажа item, который заявлен как mastery-only;
- выдача подарка без заранее сохранённого recipient intent.

Опубликованные SKU и реальные Robux-тесты не выполнены самим кодом и остаются
release gate.
