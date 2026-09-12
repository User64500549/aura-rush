# QA matrix — Secret Frames v7

## Обозначения

- `Auto` — покрывается скриптом/статической проверкой и должен быть повторён на
  каждом release build.
- `Studio RunScript` — headless Roblox Studio runtime без запуска интерактивного
  клиента; это не `Play Solo`.
- `Play Solo Manual` — ручной запуск одного сервера/клиента с визуальной проверкой
  UI, ввода и Output.
- `Manual` — требует наблюдения, нескольких клиентов, устройства или commerce sandbox.
- `OPEN GATE` — нельзя считать закрытым только по наличию кода.

## Build и modules

| Проверка | Метод | Критерий |
|---|---|---|
| Formatting | Auto | `stylua --check src tests` без diff |
| Static analysis | Auto | Selene: 0 errors, 0 warnings |
| Rojo build | Auto | `AuraRush.rbxlx` создаётся без ошибки |
| Module load | Studio RunScript | Все shared/server modules require без ошибок |
| Contract versions | Auto/Studio RunScript | schema 5, client 6, remotes v2 (35) |
| Content counts | Auto/Studio RunScript | briefs 192, worlds 6, catalog IDs unique |
| Director space | Studio RunScript | 18 432 theoretical и 1 536 empirical signatures |
| Procedural world | Studio RunScript | Hub + 6 Finale roots + all challenge scenes/cameras |

Команды:

```powershell
powershell -ExecutionPolicy Bypass -File tests/check-project.ps1
powershell -ExecutionPolicy Bypass -File tests/verify-repository-contracts.ps1
powershell -ExecutionPolicy Bypass -File tests/run-studio-smoke.ps1
```

Общий Studio RunScript runner содержит 17 независимых PASS-marker:

- `AURA_RUSH_SMOKE_PASS (171 checks)`;
- `AURA_RUSH_SERVER_INTEGRATION_PASS (55 checks)`;
- `AURA_RUSH_LOADING_SHELL_PASS (18 checks)`;
- `AURA_RUSH_CLIENT_LIFECYCLE_PASS (6 checks)`;
- `AURA_RUSH_NETWORK_SECURITY_PASS`;
- `AURA_RUSH_NETWORK_READINESS_PASS`;
- `AURA_RUSH_ANALYTICS_LIFECYCLE_PASS`;
- `AURA_RUSH_DATA_RESILIENCE_PASS (36 checks)`;
- `AURA_RUSH_GAMEPLAY_DIRECTOR_SMOKE_PASS` с 18 432/1 536 signatures;
- `AURA_RUSH_FIRST_MIRACLE_SMOKE_PASS`;
- `AURA_RUSH_LOCALIZATION_CONTRACT_PASS`;
- `AURA_RUSH_PRESENTATION_UPGRADE_PASS`;
- `AURA_RUSH_ECONOMY_LIVEOPS_SOCIAL_PASS (26 checks)`;
- `AURA_RUSH_LIVING_CITY_V4_PASS`;
- `AURA_RUSH_REMIX_CITY_V5_PASS`;
- `AURA_RUSH_PREMIUM_CITY_V6_PASS`;
- `AURA_RUSH_SECRET_FRAMES_V7_PASS (133 checks)`.

Runner отвергает устаревшую сборку, фиксирует SHA-256/размер и запускает каждый
suite на отдельной копии place. PASS считается только отдельной runtime-строкой;
напечатанный Studio исходник не считается результатом. Ошибки проверяются до
PASS и повторно после завершения процесса.

Последний полный автоматический проход: `2026-09-12T15:37:34.8248266Z`, 17/17
PASS, runner exit code `0`. Сборка: `1,119,604` байта,
`SHA256 BB134CD516B81031D4C4452F1242CB433880A5094098A3678A56C9EAB80CF8DC`.
Исходное доказательство — `studio-smoke.log`; не переносите этот hash в новый
release candidate без повторного прогона.

Эти проверки не запускают реальный LocalPlayer UI и не закрывают ручной
`Play Solo` gate.

## First Miracle

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| FM-01 | Normal path | Studio RunScript | Allowlist palette → 3 server-verified spatial actions → Bloom |
| FM-02 | Time guarantee | Studio RunScript | Bloom начинается не позднее 30 s |
| FM-03 | Reward/idempotency | Studio RunScript | +100 GlowDust, +80 Motion XP, milestone aura/equip только один раз |
| FM-04 | Skip/timeout/reconnect | Studio RunScript + Play Solo Manual | Все пути завершаются; состояние продолжается безопасно |
| FM-05 | Runtime flag/read-only | Studio RunScript | Kill-switch соблюдается; Studio demo не зависает |
| FM-06 | Честный first input | Studio RunScript | Timeout/resume/rejected не создают ввод; ручной выбор или принятое действие учитываются один раз на активную сессию |

## Core gameplay

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| RUN-01 | Full legacy route | Studio RunScript | Все phases, reward один раз, Cleanup |
| RUN-02 | Full new route | Studio RunScript | Material Surf + Light Loom + Bloom Rescue |
| RUN-03 | Route vote spoof | Studio RunScript | Unknown/non-option route отвергнут |
| RUN-04 | Director anti-repeat | Auto/Studio RunScript | Recent signature получает penalty, plan deterministic |
| RUN-05 | Invalid challenge payload | Studio RunScript | Нет progress/reward, сервер не падает |
| RUN-06 | Player leave mid-act | 4-client Manual | Team completion не блокируется |
| RUN-07 | All requeue | 4-client Manual | Results заканчиваются безопасно, новый round clean |
| RUN-08 | Round exception recovery | Studio RunScript | Cleanup, следующий round запускается |
| RUN-09 | Mechanic catalog | Studio RunScript | Ровно 18 implemented IDs и distinct verbs |
| RUN-10 | Shared repair/relay/eclipse | Studio RunScript | Два участника завершают общий authoritative sequence |
| RUN-11 | Living route geometry | Studio RunScript | Route pattern меняет geometry и spawn path |
| RUN-12 | Remix cells | Studio RunScript | Три cells физически соединены, cell mechanics активны |
| RUN-13 | Guardian finale | Studio + 4-client Manual | Distance/cooldown/role проверяются сервером |

## Late join и multiplayer

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| MP-01 | Join Thread/Beat/Prism/Mix/Finale | 4-client Manual | Backstage role, current spawn/state |
| MP-02 | <12 s remaining | 4-client Manual | Late join не добавляется в active roster |
| MP-03 | Reward scaling | Auto/Studio | Base reward/XP соответствует participation ratio |
| MP-04 | Disconnect/reconnect | 4-client Manual | Нет duplicate grant, profile корректен |
| MP-05 | Party API unavailable | Play Solo Manual | Empty/fallback view, round работает |
| MP-06 | Invite spam | Manual | Prompt только после click, 2 s local debounce |

`MP-01`–`MP-06`, особенно четыре одновременных клиента, — `OPEN GATE` до ручного прогона.

## Meta/economy/data

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| DATA-01 | v1→v5 fixture | Auto | Currency/unlocks/loadout/receipts сохранены |
| DATA-02 | v2/v3/v4→v5 fixture | Auto | Remix/First Miracle tables добавлены, repeat idempotent |
| DATA-03 | Active foreign lease | Studio RunScript | Второй writer не захватывает profile |
| DATA-04 | Save mutation during yield | Auto/Studio RunScript | Dirty revision не теряется |
| ECON-01 | Duplicate round/quest/event | Auto | Второй grant не меняет balance |
| ECON-02 | Mastery threshold | Auto | Точный deterministic item, один раз |
| ECON-03 | Late join progression | Auto | Scaled base, action XP capped |
| ECON-04 | Idle participation | Studio RunScript | 0 reward и нет side effects в quests/liveops/crew |
| ECON-05 | Paid receipt archive | Studio/private | Replay идемпотентен; conflict/outage fail-closed |
| QUEST-01 | UTC rollover/bank | Auto | Daily archived ≤5 days, weekly refreshed |
| QUEST-02 | Reroll | Auto/Play Solo Manual | Один free reroll/day, новая valid quest |
| LOOK-01 | Save/delete/equip | Play Solo Manual | Ownership, name filter, max 20, read-only block |
| HUB-01 | Creator Hub navigation | Play Solo Manual | Profile, quests, Canvas, Lookbook, Postcards и Atelier доступны без overlap |
| REPLAY-01 | Consent/save/play/delete | Studio + Play Solo | Владелец, read-only, лимиты и privacy соблюдены |
| SEASON-01 | 40-node free claim | Studio RunScript | XP, item ID и duplicate claim проверены сервером |

## Social и LiveOps

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| POST-01 | Create outside Finale/Results | Studio RunScript | Отклонено |
| POST-02 | Duplicate create same round | Studio RunScript | Только одна postcard |
| POST-03 | Remix missing ownership | Studio RunScript | Missing reported, item не выдан |
| POST-04 | Self/unknown reaction | Studio RunScript | Отклонено |
| ATL-01 | Offline/self invite | 4-client Manual | Отклонено |
| ATL-02 | Expired invite | 4-client Manual | После 120 s не принимается |
| ATL-03 | Decline/block/cooldown | Studio + 4-client Manual | Revalidation и session block не обходятся |
| LIVE-01 | Duplicate contribution | Auto | Personal/global total не удваивается |
| LIVE-02 | Milestone duplicate claim | Auto | Reward один раз |
| LIVE-03 | Cache/messaging failure | Studio RunScript | Personal flow работает, no crash |
| LIVE-04 | Shutdown pending flush | Studio/private | Delta сохраняется или явно deferred |

## Premium City v6

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| CITY-01 | Hero landmark и география | Studio RunScript | 6 плавных лент / 60 сегментов, 6 ворот, 72 rail segments, 4 плиты, 2 фотозоны |
| CITY-02 | Северные ворота/rail | Studio RunScript | `GetPartsInPart` не находит пересечений с фасадами |
| CITY-03 | Видимая русская навигация | Studio RunScript + Play Solo | Канонические названия, номера/формы и подписи плит, нет служебного текста |
| CITY-04 | Превью районов | Studio + Play Solo | Все 6 ProximityPrompt имеют consumer и показывают правильный район |
| CITY-05 | Фотоплощадки | Studio + Play Solo | Оба prompt вызывают Capture; сохранение только по решению игрока |
| CITY-06 | Pulse lifecycle/kill switch | Studio + code audit | Stop отключает snapshot, epoch не оживляет старый loop; re-enable работает |
| CITY-07 | Pulse вклад | Studio + 4-client Manual | Живой игрок рядом с плитой, cooldown, два участника при доступной группе |
| CITY-08 | Pulse HUD и reset | Studio + Play Solo | Видна бонусная плита; reset не стирает актуальную реакцию Сердца |
| CITY-09 | Replay/roles | Studio + Play Solo | Нет возврата старого replay HUD; повтор той же роли не вытесняет storyboard |
| CITY-10 | Репликация Pulse | Code audit + load test | Coalescing ≤12 world/UI обновлений/с; реальные касания ×4 — OPEN GATE |
| CITY-11 | Parts/lights/transparency | Studio RunScript | Hub 402/480, world 1140/2600, lights 23/24, hub alpha 62/72, total 293/320, зона ≤100 |
| CITY-12 | Streaming compatibility | Build XML + Studio | Enum tokens сериализованы; недоступные API дают явный fallback, не runtime error |
| CITY-13 | Chemistry regression | Studio RunScript | 512 loadouts: no sort error, unique top three, descending matches, deterministic signature |
| CITY-14 | Priority и safe-area | Studio + Play Solo | Pulse не возвращается поверх onboarding/modal, единые inset, нет пустого toast |
| CITY-15 | Реальная layout-regression | Studio + Play Solo | Accent не занимает UIListLayout slot; Border не обводит glyphs |
| CITY-16 | Primary activity + late snapshot | Studio + Play Solo | Примерка/выбор/кнопочные испытания не перекрыты ролями/route ribbon; read-only badge остаётся видимым |
| CITY-17 | Arrival каждого акта | Studio + Play Solo | Metadata смотрит вдоль RouteFloor; framing происходит после teleport, не удерживает camera |
| CITY-18 | 2→3 доступных выбора | Studio renderer | Нет третьей пустой карточки; gamepad не фокусирует скрытый вариант; карточка возвращается в следующем раунде |
| CITY-19 | First Miracle spatial actions | Studio renderer + Play Solo | «Проверить шаг»/Skip имеют ≥48 px hit targets и 10 px зазор, не накладываются |
| SF-01 | Catalog/world contract | Studio RunScript | 6 unique frames, по одному на район, русский copy, нет paywall/time gate |
| SF-02 | Authority/range | Studio RunScript | Server-owned prompt; far/unknown/cooldown отклоняются |
| SF-03 | Reward/idempotency | Studio RunScript | 35 Искр + 15 Camera XP ровно один раз; repeat без grant |
| SF-04 | Collection completion | Studio RunScript | 6/6 даёт 120 Искр и achievement ровно один раз |
| SF-05 | Kill switch/lifecycle | Studio RunScript | Prompt availability следует флагу; Destroy очищает connections |
| SF-06 | Route/reveal/input | Play Solo + Device Manual | Все 6 точек достижимы; reveal читаем; touch/gamepad prompt работает — OPEN GATE |

Эти контракты не доказывают визуальное качество, FPS или удобство кооперации.
Screenshot matrix, фактическая частота рассылок под нагрузкой и четыре клиента
остаются отдельными gates.

## Accessibility/presentation

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| UI-01 | Phone portrait/landscape | Device Manual | Reflow, no clipped primary actions |
| UI-02 | Gamepad navigation | Manual | Все primary actions достижимы |
| UI-03 | Large text + RU | Manual | Нет critical truncation/overlap |
| A11Y-01 | Reduced motion | Manual | Camera/transitions сокращены |
| A11Y-02 | No flashes | Manual | Нет rapid high-contrast pulse |
| A11Y-03 | Low VFX | Manual | Minimal pool, gameplay cues видны |
| A11Y-04 | Captions/haptics off | Manual | Preferences соблюдаются |
| PREV-01 | R6/R15 preview | Manual | Clean clone, scripts/tools/effects удалены |
| AUDIO-01 | Modern graph unavailable | Play Solo Manual | Legacy Sound fallback работает |
| BLOOM-01 | Camera interruption | Manual | Camera возвращается из Scriptable |
| BLOOM-02 | Recipe v4 axes | Studio RunScript | Material/aura/pose/accent/route/performance потребляются миром |
| BLOOM-03 | Glowstorm accessibility | Studio + Manual | Сервер не форсирует post-effects; настройки клиента соблюдены |

Device accessibility и production audio/art checks — `OPEN GATE`.

## Commerce

| ID | Сценарий | Метод | Ожидание |
|---|---|---|---|
| COM-01 | IDs 0/empty, flags off | Auto/Studio RunScript | Нет prompt |
| COM-02 | Unknown product | Studio RunScript | `NotProcessedYet`/нет grant по контракту |
| COM-03 | Duplicate receipt | Private commerce | Entitlement один раз |
| COM-04 | Save failure/read-only | Private commerce | Receipt не acknowledged |
| COM-05 | Glowstorm token/retry | Private commerce | Durable token; restore on launch failure |
| COM-06 | Signature collection | Auto/private | Точный список, без mastery items |
| COM-07 | Pass/subscription benefits | Private Manual | Каждая заявленная benefit доказана |

`COM-03`–`COM-07` — `OPEN GATE`; реальные IDs и published commerce намеренно не настроены.

## Performance

| Проверка | Метод | Gate |
|---|---|---|
| 30 FPS mobile / 60 FPS desktop target | Real device profiler | OPEN |
| Bloom hitch ≤100 ms | Real device profiler | OPEN |
| Memory growth ≤30 MB / 5 rounds | Server+client profiler | OPEN |
| 4→12 client server heartbeat/script time | Private load test | OPEN |
| `ServerBoot.WorldBuild` p50/p95 | Private server + performance snapshot | Instrumented; baseline OPEN |
| External asset footprint | После asset import | OPEN |

## Отдельный Play Solo gate

Ручной `Play Solo` должен подтвердить: отсутствие красных ошибок server/client в
Output, видимый onboarding, normal/skip First Miracle, персональный Bloom, открытие
Creator Hub, адаптивный HUD, начало и завершение полного раунда, а затем корректный
Stop без выдачи награды после shutdown. Результат фиксируется отдельно от
`studio-smoke.log`; 12 `RunScript` PASS не являются доказательством этого gate.

Историческая попытка 25.08.2026 на тогдашней v5-сборке подтвердила
`REMIX CITY server booted (schema v4, client v5)`, после чего Studio сообщил
`Connection fell back to legacy networking`. За 19 секунд LocalPlayer не создался,
клиентский bootstrap/UI не запустился, а проектных красных ошибок в Output не
появилось. Это согласуется с прежним loopback-блокером этой машины, но не является
визуальным доказательством клиента. В диагностике 03.09.2026 LocalPlayer уже
успешно загрузился; прежний loopback-блокер не воспроизведён. Живой проход выявил
crash Style Chemistry и несколько UI/camera дефектов, которых не заметил headless
runner. Исправления и точный охват повторных проходов записаны в
[Play Solo review v6](PLAY_SOLO_V6_REVIEW.md). Это не закрывает автоматически
физические задания, multiplayer, устройства и production persistence.

## Release decision

Текущую сборку можно называть локальным RC только на основании Auto и 17 Studio
RunScript PASS для одного и того же build.
Публикация/production release не выполнены и требуют закрыть все `OPEN GATE`:
ручной Play Solo, лицензированные external assets/audio, реальные commerce IDs и
sandbox flow, четырёхклиентный тест и device performance evidence.
