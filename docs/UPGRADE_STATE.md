# UPGRADE STATE

Последнее обновление: 2026-09-04.

## Где мы сейчас

- Local build: `AuraRush.rbxlx`, 1,039,450 bytes.
- SHA-256: `57DB30D472E7F365D9F1EF3777CBD5CE39B8F4A52C65CBADA917710BCBFC2019`.
- Evidence UTC: `2026-09-04T05:03:33.3327838Z`.
- Contract: client v6, profile schema v5, Premium City catalog v7, 32 remotes.
- Static gate: Stylua PASS; Selene 0 errors / 0 warnings / 0 parse errors; Rojo PASS.
- Runtime gate: 12/12 isolated Studio suites PASS, 0 `RunScript` failures.
- Structural suite: 161 checks. Secret Frames suite: 133 checks.
- World budget: hub 402/480 BaseParts; world 1140/2600; lights 23/24; hub
  partial transparency 62/72; total 293/320.
- Live Roblox place was not published or modified in this cycle.

## Что сделано в текущем запуске

1. Добавлен self-contained `ReplicatedFirst` экран входа без внешних assets.
2. Client bootstrap получил явные состояния `client_starting`, `ready`, `failed`,
   время локальной инициализации и top-level error boundary.
3. Исправлен lifecycle фотозон: первый снимок больше не отключает следующие, а
   destroy очищает listener.
4. Реализованы шесть постоянных Secret Frames: физическая карта, prompts,
   server distance validation, cooldown, idempotent grants, Camera XP, collection
   bonus, общий reveal, analytics, kill switch и Creator Hub progress.
5. Нормализация `photoModeUnlocks` получила dedupe/limit; поле включено в client
   profile без смены DataStore key или schema.
6. Синхронная сборка мира в server bootstrap обёрнута в
   `PerformanceService.Measure("ServerBoot.WorldBuild", ...)`; результат пишется в
   server log и `ServerBootWorldBuildMilliseconds` атрибут мира. Structural suite
   защищает instrumentation от случайного удаления.

## Что удалено или сознательно не добавлено

- Не добавлялись новая валюта, новый remote, paywall, daily FOMO и автоматический
  purchase prompt.
- Не переписывались работающие Round/Data/Remote системы.
- Не включались commerce flags и нулевые SKU.
- Не публиковалась непроверенная локальная версия поверх live place.

## Решения и причины

- Boot UI находится в `ReplicatedFirst`, потому что это минимальный слой, который
  приходит раньше основного client tree; он не требует Theme, Localization или CDN.
- Secret Frames используют серверный `ProximityPrompt.Triggered` и повторную
  проверку дистанции. Это сохраняет 32-remote контракт и не доверяет клиентской
  награде/позиции.
- Коллекция хранится в уже существующем `photoModeUnlocks`; schema bump не нужен.
- Карта получила только 30 BaseParts и 6 alpha surfaces: visual gain не нарушил
  mobile-oriented budget.

## Подтверждённые гипотезы

- Новая загрузочная ветка сериализуется в place, содержит ready/fail handoff и не
  зависит от remote asset: runtime contract PASS.
- Capture listener сохраняется между снимками и очищается только на destroy:
  lifecycle contract PASS.
- Secret reward idempotent, out-of-range запрос отклоняется, шестой секрет выдаёт
  bonus один раз, flag отключает prompts: 133 runtime checks PASS.
- Новая геометрия не превысила существующие world/light/transparency budgets.
- World-build measurement присутствует в canonical server bootstrap и сериализуется
  в place; числовой baseline остаётся external performance gate.

## Неподтверждённые гипотезы

- Игрок действительно замечает рамки без лишнего шума.
- Награда 35 Искр + 15 Camera XP и bonus 120 Искр имеет правильный темп.
- Boot shell виден на целевых телефонах и корректно переходит в App при реальном join.
- Secret Frames повышают exploration, session length или возвраты.

## Текущая крупнейшая проблема

Нет физического доказательного прогона именно этого build на LocalPlayer, четырёх
клиентах и low-end mobile. Дополнительно локальный Roblox Player имеет несколько
install roots; последний проблемный журнал содержал `tr.rbxcdn.com` DNS failures,
хотя текущий DNS lookup уже проходит. Это мешает отличать client-install проблему
от place regression без нового чистого запуска.

## Следующий цикл

1. Устранить конфликт установок Roblox вне репозитория только с явного согласия
   владельца машины; затем выполнить чистый Player join.
2. Play Solo: boot handoff → First Miracle → два снимка подряд → один Secret Frame →
   полный раунд → clean Stop.
3. Server & Clients ×4: simultaneous frame reveal, City Pulse, late join, encore.
4. Device matrix и MicroProfiler; сохранить raw evidence.
5. После 10–20 наблюдаемых first sessions выбрать один measured onboarding change.

## Git

Репозиторий существует, но весь проект до этого цикла отображается как untracked.
Автоматический commit не создан: он присвоил бы агенту весь существующий проект и
смешал пользовательскую базу с новыми изменениями. Нужен осознанный baseline commit
владельца или подтверждение включить все текущие файлы.
