# Архитектура AURA RUSH — runtime v7

## Слои

```text
ReplicatedFirst
  autonomous Russian loading shell → client boot ready/failed state
                    │
Client presentation
  App + Round/Remix/FirstMiracle/Meta controllers + local camera/audio/VFX/preview/input
                    │ validated intents / snapshots
Shared contracts    │ Config, Types, Remotes, catalogs, localization, art/liveops
                    │
Server orchestration
  Round ─ RunDirector ─ Challenge ─ RemixCity ─ World ─ AuraGenome/BloomComposer
    │          │             │          │
    ├─ Reward ─ Progression ─ Economy ─ Data
    ├─ FirstMiracle / SecretFrames / Quest / LiveOps / CommunityBloom
    ├─ Style / SocialCreation / Party / Celebration / Purchase
    └─ Analytics / Performance / FeatureFlags / Remote
```

Клиент получает snapshot и визуализирует его; он не вычисляет authoritative
progress. Shared-модули содержат стабильные идентификаторы и сетевой контракт, но
не секреты и не доверенные решения. Contract inventory v7: 192 briefs, 6 worlds,
18 encounter cells, 40 season nodes, 6 Secret Frames, 35 remotes и client/profile
schema versions 6/5.

## Порядок загрузки сервера

Bootstrap сначала создаёт remotes и world; world build замеряется под
`ServerBoot.WorldBuild`. Затем он поднимает данные и сервисы, которым
они нужны. Критическая dependency-цепочка:

```text
Data → Economy → Progression → Quest → LiveOps → CommunityBloom
     → Style → RemixCity → Challenge → Reward → Purchase
     → RunDirector + AuraGenome → Round → FirstMiracle
     → SocialCreation + Celebration + Meta → SecretFrames
```

Для каждого вошедшего игрока: profile load → v5 migrate/reconcile → mastery check →
quest refresh → party refresh → character styling → round snapshot → meta snapshot.
Shutdown останавливает round/community sampling и сохраняет профили в заданный budget.

## First Miracle state machine

До первого основного run клиент запрашивает серверное состояние First Miracle:

```text
NotStarted → PaletteChoice → Actions (3 spatial) → Bloom → Complete
                     └──────── timeout/skip ────────┘
```

Сервер принимает только allowlist palette/action IDs, а для реального Player
проверяет движение/прыжок/поворот по Humanoid и HRP, не доверяя позиции из payload.
Также он проверяет порядок и cooldown,
гарантирует начало Bloom не позднее 30 секунд и продолжает незавершённую сессию после
reconnect. Персональный Bloom включает palette colors и fingerprint Aura Genome.
Идемпотентный grant `system:first_miracle:v1` выдаёт 100 GlowDust, 80 Motion Aura
Atlas XP, открывает/экипирует `aura_first_miracle` и завершает onboarding. В
read-only Studio path demo завершается без durable записи и зависания.

## Round state machine

`RoundService` владеет `state`, `stateVersion`, `roundId`, server timestamps,
participants, votes, route votes, requeue, run plan, active act, Aura Genome и
Bloom Recipe. Клиентский таймер считается от server time, а не является источником
истины.

```text
Waiting
  → Intermission: фиксируется eligible roster
  → BriefChoice: 3 briefs, team vote, route choice
  → ThreadRun legacy phase: первый encounter cell
  → BeatLab legacy phase: второй encounter cell
  → PrismPuzzle legacy phase: третий encounter cell
  → MixLab: owned item selection + ready
  → Finale: Страж → capture team genome → server World Bloom
  → Results: idempotent reward/meta/liveops → optional replay/requeue
  → Cleanup
```

Run Director генерирует 18 candidates, применяет history penalty к последним восьми
signatures и выбирает минимальный deterministic score. Route vote может пересобрать
акты в пределах тех же трёх legacy slots. Target scale зависит от размера команды;
team completion ratio снижается для больших групп, чтобы один отсутствующий игрок
не блокировал фазу.

Brief axes и art profile входят в semantic tuning. Полное пространство композиции —
18 432 theoretical signatures; детерминированная Studio выборка наблюдает 1 536
empirical gameplay-signatures. Anti-repeat penalizes recent signatures, не ломая
reproducibility одинакового seed/history.

## Late join

Snapshot request может зарегистрировать загруженного non-participant во время
ThreadRun, BeatLab, PrismPuzzle, MixLab или Finale, если в фазе осталось не менее
12 секунд и сервер не достиг лимита 12 игроков. Сервер:

1. Назначает роль `BackstageApprentice` и join act index.
2. Добавляет challenge state, применяет текущий style и телепортирует к сцене.
3. Вычисляет participation ratio от оставшейся части раунда, минимум 0.2.
4. Масштабирует completion reward и базовую часть progression XP.

Клиент не может самостоятельно назначить роль или увеличить ratio.

## Aura Genome и World Bloom

Персональный genome содержит catalog IDs пяти категорий, tags, palette color и
stable fingerprint. Командный genome агрегирует dominant items, average color,
diversity и synergy. Он ничего не открывает и не предполагает ownership.

`BuildBloomRecipe` создаёт version 4 recipe: round/seed/world, dominant style IDs,
route, modifier, act IDs, performance и три Bloom acts (`seed`, `cascade`, `bloom`).
`BloomComposerService` резолвит palette stops, материал, aura motif, camera preset,
landmark preset и route pattern. `WorldService` применяет recipe на сервере;
Camera/VFX/Audio clients используют его для синхронной доступной презентации.

## Сетевой контракт

Основные client intents:

| Группа | Remotes | Серверная проверка |
|---|---|---|
| First Miracle | request, spatial action, update | feature flag, state, server movement evidence, order, cooldown, deadline |
| Round | snapshot, brief/route vote, beat, prism, ready, requeue | phase, participant, value bounds, rate |
| Style/meta | equip, save/delete/equip look, settings, reroll | ownership, catalog, limits, read-only |
| Social | postcard action, atelier action | phase, owner/target, allowlist, limits |
| Remix | role, Guardian pulse, consent, save/play/delete, season claim | phase, distance, cooldown, ownership, XP, read-only |
| Commerce | activate token; Marketplace receipt вне remote | token balance, cooldown, durable grant |

Server→client snapshots могут повторяться; UI обязан быть идемпотентным по
`stateVersion`/`roundId`. Неизвестный payload игнорируется, а не исполняется.
Полный registry содержит 35 remotes v2; новые intent нельзя создавать вне shared
definitions и server binding. Три OPS-remotes не дают клиенту полномочия: role и
каждое действие проверяет `AdminService` на сервере.

## Creator Hub и social meta

`MetaPanelController` показывает authoritative meta snapshot: профиль/Aura Atlas,
Community Canvas и milestones, daily/weekly quests и reroll, Lookbook,
Postcards/create/remix/positive reactions, Atelier/crew invites, membership и прогресс
Secret Frames.
Durable действия блокируются в read-only профиле. Postcard recipe не содержит
свободный текст, remix применяет только уже принадлежащие items, реакции используют
positive allowlist, а destructive delete/leave требуют явного подтверждения UI.

## Persistence

Profile schema v5 хранится в `AuraRush_Profile_v1`. DataService использует
`UpdateAsync`, session lease и revision-aware dirty state, чтобы mutation во время
yield не потерялась. Read-only profile позволяет пройти run, но запрещает durable
mutations и не подтверждает receipt.

Раздельные ledger:

- `paidReceipts` — только Roblox receipt IDs;
- `grants.rounds/events/quests/mastery/system` — earnable/idempotent grants;
- `spends` — списания;
- compatibility-поля `grantedRounds` и `purchaseReceipts` сохраняются при миграции.

## Live services и деградация

- Experience Configs: только allowlist флагов; fallback на локальный Config.
- DataStore/MemoryStore/Messaging: Community Bloom использует durable total, cache и
  broadcast; недоступность cache/broadcast не должна ломать личный grant.
- Party API: snapshot пустой при недоступности.
- Modular Audio: попытка создать modern graph, fallback на built-in Sound.
- Capture/Marketplace/Analytics: вызовы обёрнуты безопасными проверками/pcall там,
  где platform API может быть недоступен.

Remote runtime allowlist фиксирован: `FirstMiracle`, `AdaptiveRuns`, `Progression`,
`LiveOps`, `Crews`, `CommunityBloom`, `EditablePostcards`, `ModularAudio`,
`ChallengeFramework2`, `BloomComposer2`, `SpatialFirstMiracle`, `LivingCity`,
`StyleOS`, `RemixCity`, `StyleChemistry`, `GuardianFinales`, `ReplayGhosts`,
`SeasonOne`, `CityPulse`, `SecretFrames`.
`Persistence`, `Analytics`, `Capture`, `Purchases`, `Passes`, `MarketplaceCatalog`
и `Subscriptions` остаются local-only. Commerce IDs безопасно не настроены
(`0`/`""`), а commerce flags выключены; архитектура не утверждает публикацию или
production entitlement readiness.

## Security invariants

1. Client не передаёт сумму награды, XP, unlock или product entitlement.
2. Locked style item нельзя экипировать или получить через postcard remix.
3. Mastery item не включается в paid collection.
4. Round/event/quest/receipt повтор не меняет баланс второй раз.
5. Purchase prompt не запускается автоматически и не использует ID `0`/`""`.
6. Свободный social text отсутствует; postcard recipe и reactions используют allowlist.
7. Session owner проверяется повторно перед сохранением/release.
8. Secret Frame засчитывается только из server-owned prompt после серверной
   проверки дистанции, cooldown, catalog ID и idempotency ledger.
