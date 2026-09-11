# METRICS

## Главный продуктовый вопрос

Доходит ли новый игрок самостоятельно до первого World Bloom, понимает ли свой
вклад и осознанно выбирает следующий забег или социальное действие?

## Metric tree

```text
First Bloom → Intentional next action
├─ Acquisition quality: join → client ready → first world reaction
├─ Activation: First Miracle start → input → complete → first run
├─ Core health: act 1/2/3 → Mix ready → Guardian → Results
├─ Return value: requeue / encore / next-day return
├─ Social value: City Pulse / nomination / postcard / Atelier
└─ Guardrails: save errors / FPS / memory / exploit rejects / economy balance
```

## Instrumented events

| Событие | Вопрос | Source of truth |
|---|---|---|
| `onboarding_start` | профиль загрузился? | server после Data load |
| onboarding step 1–4 | где теряется первый опыт? | server state transitions |
| `first_input`, `first_movement`, `first_world_reaction` | как быстро игрок действует и видит ответ? | accepted server action |
| round funnel phases | где распадается основной цикл? | `RoundService` |
| `round_unqualified` / failure reasons | почему reward не выдан? | server result |
| `city_pulse_impression/first_pad/step/complete/next_run` | idle social loop ведёт в run? | `CityPulseService` |
| `secret_frame_discovered` | exploration используется? | validated `SecretFrameService` grant |
| economy source/sink | есть ли inflation/dead currency? | после server mutation |
| season/quest claims | видна ли следующая цель? | idempotent server grant |
| postcard/nomination/atelier/encore | создаётся ли social value? | validated server action |

`secret_frame_discovered` допускает только три low-cardinality поля: `frameId`,
`worldId`, `readOnly`. Повторная активация и rejected distance не логируются как
успешное discovery. Collection bonus имеет отдельный economy source.

## Пороговые цели до закрытого запуска

| Метрика | Цель | Сейчас |
|---|---:|---|
| Контролируемый кадр после join | без пустого окна | реализовано, нужен real Player proof |
| First world reaction | ≤15 s | контракт есть, live baseline отсутствует |
| First Miracle Bloom | ≤30 s | server contract и tests PASS |
| First Miracle completion | ≥75% | неизвестно |
| Первый run start после Miracle | ≥65% | неизвестно |
| Первый World Bloom | ≥45% новых игроков | неизвестно |
| Requeue/encore после первого результата | ≥20% | неизвестно |
| Secret Frame discovery/session | 0.3–1.5 | неизвестно; выше может означать слишком явные рамки |
| Secret collection completion | 5–20% активных игроков | неизвестно |
| Negative currency balance | 0 | contracts PASS |
| Duplicate paid/earnable grant | 0 | contracts PASS |
| `ServerBoot.WorldBuild` | baseline first, then set device/server budget | metric exposed; private baseline absent |
| Low-end mobile FPS | ≥30 target | физический профиль отсутствует |

Цели — стартовые гипотезы для закрытого теста, не выдуманный baseline.

## Startup measurement gap

Client bootstrap записывает локальный `AuraRushBootDurationMs` в `PlayerGui`, что
помогает Play Solo diagnostics, но не отправляет недоверенное значение в продуктовую
аналитику. Для production click-to-controllable нужен отдельный low-cardinality
telemetry contract с server receive time и client bucket; до его появления нельзя
заявлять join-time percentile.

Server world construction теперь замеряется под `ServerBoot.WorldBuild`;
результат виден в server log и в атрибуте
`AuraRushWorld.ServerBootWorldBuildMilliseconds`. Это инструмент для baseline,
но не его замена.

## Dashboard guardrails

- Не отправлять DisplayName, look name, free text, user/party IDs, receipt IDs,
  `roundId` или `sessionId` в custom dimensions.
- Считать reward/purchase только после server mutation.
- Разделять read-only и writable sessions.
- Сегменты: input class, quality tier, locale, new/returning, party/solo — только
  низкая кардинальность.
- Не принимать локальный Studio count за retention evidence.
- Менять одну продуктовую переменную за эксперимент и заранее фиксировать guardrails.
