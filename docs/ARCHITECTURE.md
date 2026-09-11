# Архитектура AURA RUSH

Это краткая карта release candidate. Полный контракт находится в
[ARCHITECTURE_V2.md](ARCHITECTURE_V2.md).

Текущий контракт — client v6 / profile schema v5: 192 briefs, 6 worlds, 18
encounter cells, 40 сезонных узлов, 6 Secret Frames и ровно 32 объявленных
remotes. Secret Frames не добавляют client→server remote: поиск запускает сам
серверный `ProximityPrompt`.

## Загрузка и диагностика

`ReplicatedFirst/AuraRushLoading` строит автономный loading shell без
сетевых assets и убирает default loading screen только после своего mount.
Клиентский bootstrap обёрнут в `xpcall` и передаёт состояния
`client_starting`, `ready` и `failed` через атрибуты `PlayerGui`.
`PerformanceService.Measure("ServerBoot.WorldBuild", ...)` отдельно замеряет
синхронную сборку мира.

## Первый опыт

`FirstMiracleService` — серверный state machine перед основным забегом:
`PaletteChoice → 3 server-verified spatial Actions → Bloom → Complete`.
`MaximumSeconds = 30`,
причём normal, timeout и явный skip сходятся в один персонализированный Bloom.
Состояние хранится в профиле и возобновляется после reconnect. Namespaced grant
`system:first_miracle:v1` атомарно выдаёт 100 GlowDust, 80 Motion Aura Atlas XP и
milestone `aura_first_miracle`, экипирует её и отмечает onboarding завершённым.
Повторный remote или reconnect не дублирует награду.

## Поток раунда

`RoundService` — единственный авторитет над фазой, временем, участниками, выбранным
брифом, маршрутом и выдачей результата для `roundId`.

```text
Waiting → Intermission → BriefChoice
        → непрерывный Cell 1: Thread Run | Material Surf
        → непрерывный Cell 2: Beat Lab   | Light Loom
        → непрерывный Cell 3: Prism Puzzle | Bloom Rescue
        → MixLab → Страж → World Bloom → Results / Replay → Cleanup
```

`RunDirectorService` детерминированно собирает три акта из 18 encounter cells, две
route options и один modifier, штрафуя недавние signatures. Новые акты сохраняют legacy-фазы
`ThreadRun`, `BeatLab`, `PrismPuzzle`, поэтому сетевой и UI-контракт остаётся
обратно совместимым. `AuraGenomeService` агрегирует пять категорий экипировки
команды и строит Bloom Recipe v4. `BloomComposerService` добавляет material, aura,
camera, landmark, route и performance presentation. Полное пространство составляет
18 432 theoretical signatures; Studio sampling подтверждает 1 536 empirical
gameplay-signatures и влияние world/occasion/aesthetic/twist на композицию.

## Границы доверия

- Клиент отвечает за ввод, UI, локальную камеру, звук и декоративный VFX.
- Сервер отвечает за phase clock, участие, challenge progress, ownership,
  экипировку, XP, валюту, quests, community contribution и commerce grants.
- Client→server remotes rate-limited и проверяют типы, длины, диапазоны и фазу.
- Round, quest, event, mastery и paid grants имеют отдельные idempotency keys.
- Receipt подтверждается только после успешного сохранения entitlement; read-only
  профиль возвращает `NotProcessedYet`.
- Late join не доверяет клиентской роли: сервер назначает `BackstageApprentice`,
  фиксирует join act и participation ratio.

## Мир и presentation

`WorldService` строит Hub, сцены испытаний и шесть финальных миров из Roblox
primitives. `ArtDirectionRegistry` задаёт палитру, пять material families,
silhouette language, lighting normal/bloom и sound motif для каждого мира.
`ApplyRunPlan` добавляет активную геометрию выбранной ветки и меняет route spawn.
`SecretFrameService` подписывается на шесть server-owned prompts, повторно
проверяет дистанцию/флаг/cooldown и выдаёт идемпотентную награду через
существующие `DataService`, `EconomyService` и `ProgressionService`.
`ProductionAssetService` проверяет и предзагружает только реальные ID из manifest.
Процедурный fallback делает проект запускаемым без внешних asset IDs, но не заменяет
финальный production art pass и не маскируется выдуманными ID.

Клиент разделён на `App`, `RoundController`, `RemixController`, `CameraController`, `AudioDirector`,
`VfxDirector`, `AvatarPreviewController`, `SocialInviteController` и остальные
узкие контроллеры. `FirstMiracleController` визуализирует первый Bloom, а
`MetaPanelController` собирает Creator Hub: профиль, сезон, quests, Community Canvas,
Lookbook, Postcards/remix/reactions, архив replay и Atelier/crew flows. Mix Lab использует
очищенный clone аватара в `ViewportFrame` / `WorldModel`; он не выполняет скрипты
и не меняет персонажа игрока.

## Данные и конфигурация

`DataService` хранит schema v5 в прежнем `AuraRush_Profile_v1`, включая bounded
`photoModeUnlocks`, и выполняет явные
миграции v1→v2→v3→v4→v5, reconcile новых полей, session lease, autosave и shutdown save.
Experience Configs могут переопределять ограниченный allowlist флагов; при
недоступности используется локальный snapshot из `Config.lua`.

Runtime allowlist содержит ровно: `FirstMiracle`, `AdaptiveRuns`, `Progression`,
`LiveOps`, `Crews`, `CommunityBloom`, `EditablePostcards`, `ModularAudio`,
`ChallengeFramework2`, `BloomComposer2`, `SpatialFirstMiracle`, `LivingCity`,
`StyleOS`, `RemixCity`, `StyleChemistry`, `GuardianFinales`, `ReplayGhosts`,
`SeasonOne`, `CityPulse`, `SecretFrames`.
Persistence, analytics, capture и commerce flags этим каналом не включаются.
Product/pass IDs остаются `0`, subscription ID — `""`, а `Purchases`, `Passes` и
`Subscriptions` выключены до отдельной настройки и закрытого commerce QA.

Shared-каталоги — источник истины для IDs брифов, стиля, продуктов, live-ops,
локализации, remotes и art direction. После публикации постоянные IDs нельзя
переименовывать без миграции.
