# LiveOps v4

## Модель

LiveOps использует versioned shared manifest и ограниченный набор remote feature
flags. Встроенный manifest — безопасный evergreen fallback; production config может
быть включён staged-образом только после schema/QA review.

Текущий manifest version 2 проходит строгую проверку версии клиента, event window,
лимитов, district rotation и milestone scope:

```text
event: community_canvas_genesis
startsAt: 0 (evergreen)
endsAt: 0 (без искусственного дедлайна)
brief modifier: living_canvas
world modifier: chromatic_tide
contribution: 10 / completed round
personal daily cap: 150
```

Milestones заранее известны:

| ID | Personal contribution | GlowDust |
|---|---:|---:|
| `first_stroke` | 30 | 60 |
| `color_wave` | 100 | 140 |
| `living_canvas` | 250 | 300 |

Claim серверный и идемпотентный. Клиент не передаёт reward amount.

## Community Bloom pipeline

1. Только qualified Round result вызывает contribution с `roundId` как уникальным ID.
2. `LiveOpsService` применяет personal cap и записывает player ledger/profile.
3. `CommunityBloomService` добавляет только новый вклад в pending global total.
4. Каждые 20 секунд pending delta сохраняется через DataStore `UpdateAsync`.
5. MemoryStore HashMap служит кратким cache, MessagingService сообщает total другим серверам.
6. Shutdown пытается flush remaining deltas.

Если MemoryStore/Messaging недоступны, личная награда и раунд не должны ломаться.
Если durable global flush не прошёл, delta возвращается в pending и повторяется.

## Quests как retention layer

- 3 daily, детерминированные для player/day;
- 4 weekly;
- 1 free daily reroll;
- bank незавершённых daily до 5 дней с единым action budget — одно действие не
  копируется во все сохранённые daily;
- grace credit вместо punitive streak reset;
- 8-недельные/40-node параметры зарезервированы в Config, но полноценный season UI
  и content track не считаются завершёнными только из-за этих чисел.

## Feature flags

Remote allowlist: `FirstMiracle`, `AdaptiveRuns`, `Progression`, `LiveOps`, `Crews`,
`CommunityBloom`, `EditablePostcards`, `ModularAudio`, `ChallengeFramework2`,
`BloomComposer2`, `SpatialFirstMiracle`, `LivingCity`, `StyleOS`, `RemixCity`,
`StyleChemistry`, `GuardianFinales`, `ReplayGhosts`, `SeasonOne`, `CityPulse`.
Значения читаются из Experience Config snapshot, а при недоступности берутся из
локального Config.

Commerce flags не относятся к этому remote allowlist и остаются safe-off в коде.
`EditablePostcards = false`, потому что свободный пользовательский текст потребовал
бы отдельного filtering/moderation pipeline.

## Операционный чеклист события

1. Уникальный permanent event ID и manifest version.
2. Явные start/end UTC или честный evergreen status.
3. Детерминированные reward и milestone targets.
4. Idempotency namespace и дневной cap.
5. RU/EN localization keys.
6. Fallback при Config/DataStore/MemoryStore/Messaging failure.
7. Kill-switch и rollback plan.
8. Staged test: Studio → private server → малый production cohort → full rollout.
9. Analytics review без персональных или свободных text payloads.

## Чего LiveOps пока не обещает

- Cross-server leaderboard с точной real-time консистентностью.
- Полный season pass/40-node UI и production content calendar.
- Пользовательские надписи/изображения в Postcards.
- Проверенный production scale до нагрузочного и четырёхклиентного теста.
