# UPGRADE STATE

Последнее обновление: 2026-09-12.

## Где мы сейчас

- Local build: `AuraRush.rbxlx`, 1,119,604 bytes.
- SHA-256: `BB134CD516B81031D4C4452F1242CB433880A5094098A3678A56C9EAB80CF8DC`.
- Full evidence UTC: `2026-09-12T15:37:34.8248266Z`.
- Contract: client v6, profile schema v5, Premium City catalog v7, 35 remotes v2.
- Static gate: Stylua PASS; Selene 0 errors / 0 warnings / 0 parse errors; Rojo PASS.
- Runtime gate: 17/17 isolated Studio `RunScript` suites PASS, 0 `RunScript`
  failures for the build above.
- Repository gate: `tests/verify-repository-contracts.ps1` и GitHub Actions
  `Repository contracts` защищают canonical network/admin/persistence contracts.
- Live Roblox place не публиковался и не изменялся в этом цикле.

## Cycle 5 — Operations, reliability and release truthfulness

### Проблема

У игры не было безопасного operational surface для владельца и команды, вторичные
DataStore записи применяли неодинаковые retry paths, некоторые lifecycle-сервисы
могли удерживать player/connection state, а release-документы описывали старый
32-remote/12-suite contract.

### Реализовано

1. Добавлены canonical remotes v2: `RequestAdminSnapshot`, `AdminAction`,
   `AdminUpdate`. `RemoteService` теперь создаёт контракт только из shared
   manifest и отвергает невалидные/дублирующиеся declarations.
2. Добавлены `StaffPolicy`, server-owned `AdminService` и Russian OPS panel.
   Роли deny-by-default; доступны health, bounded in-memory audit и только два
   template announcements. Нет arbitrary commands/free text/kick/currency tools.
3. `EconomyService`, `SocialCreationService` и `CommunityBloomService` переведены
   на общий `DataStoreOperation`: bounded retry, request budget, diagnostics.
   Community Bloom использует bounded idempotent receipt ledger вместо голого
   delta, поэтому повторяемый durable update не должен двойно начислить вклад.
4. Lifecycle усилен в Party, Challenge, Style, Celebration, Remix City, First
   Miracle, Social Creation и Round. Раунд очищает state вышедшего игрока сразу и
   освобождает PlayerRemoving subscription при terminal shutdown.
5. Добавлены 36 data-resilience checks, 55 server integration checks, updated
   structural remote test, CI source-contract gate и операционная документация.

### Подтверждено автоматически

- Static/build gate прошёл на build после этих изменений.
- `data-resilience-smoke` прошёл 36 checks.
- `server-integration-smoke` прошёл 55 checks.
- `studio-smoke` прошёл 171 checks после обновления remote contract.
- Полный runner прошёл 17/17 suites на exact SHA выше: structural 171, server
  integration 55, loading 51, client lifecycle 9, network security 23,
  readiness 94, analytics 26, data resilience 36, economy/social 26 и все
  остальные contract suites PASS.

### Сознательно не добавлено

- Не добавлены новая валюта, pay-to-win, FOMO, auto-purchase prompt или ещё один
  battle pass.
- Не добавлены произвольные админ-команды, live profile editing, кики или
  рассылки с free text.
- Не включены commerce flags/нулевые SKU и не опубликована непроверенная версия.
- Не сделан big-bang rewrite `WorldService` или `App`.

## Подтверждённые решения

- OPS остаётся маленьким, потому что продуктовая ценность health/audit выше, чем
  риск универсальной admin console.
- Внешние durable records нуждаются в той же дисциплине retry и observability,
  что и profiles; это снижает silent failure risk без schema wipe.
- Документация и CI — часть качества: тест, который ожидает старый remote count,
  хуже отсутствующего теста, потому что создаёт ложную уверенность.

## Неподтверждённые гипотезы

- Владелец/модератор может быстро понять OPS на реальном mobile/desktop screen.
- Новый DataStore guard достаточно ведёт себя при реальном throttling/outage.
- Текущий build стабильно проходит живой Player join без внешнего install/network
  конфликтa.
- Игра достигает заявленных activation, retention и viral целей без живой выборки.

## Текущий самый большой bottleneck

Нет полного физического evidence именно этого build: Play Solo, Server & Clients
×4, actual Roblox Player и device matrix. Это важнее новой механики или большей
карты, потому что может обнаружить дефект входа, UX или производительности, который
не виден в headless runtime.

## Следующий цикл

1. Выполнить Play Solo по [RUNBOOK](RUNBOOK.md), особенно серый экран/boot handoff.
2. Выполнить Server & Clients ×4: role cooperation, leave/rejoin, City Pulse,
   Secret Frames, Round cleanup и OPS permissions.
3. Снять phone/gamepad profiler evidence до оптимизации мира по предположению.
4. После 10–20 no-coaching first sessions выбрать один измеримый onboarding change.

## Git

Каждый логический upgrade должен быть отдельным commit. До push проверить status,
полный local evidence и отсутствие private owner IDs/asset credentials в diff.
