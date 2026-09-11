# AURA RUSH v3 — upgrade masterplan

## Цель релиза

Сделать из vertical slice воспроизводимый release candidate с тремя связанными
петлями: короткий кооперативный run, долгосрочное развитие художественного почерка
и безопасное социальное творчество. Критерий качества — не количество обещанных
функций, а серверная проверяемость, понятная награда и управляемый rollout.

## Что вошло в v3

### Core run — реализовано

- Adaptive Run Director с тремя слотами актов, двумя route options, modifier,
  anti-repeat history и deterministic seed.
- Шесть challenge variants: три legacy и три новые сцены.
- Aura Genome и versioned Bloom Recipe, связывающие loadout команды с финалом.
- Late join / Backstage Apprentice с join-act tracking и reward scaling.
- Requeue из Results и безопасное восстановление round loop после runtime error.

### Content и art — реализовано процедурно

- 192 брифа и шесть миров.
- Единый Art Direction Registry: color script, пять material families,
  silhouettes, normal/bloom lighting и sound motif.
- Трёхактный World Bloom, hero landmarks и camera anchors.
- Процедурные Roblox primitives как автономный fallback.

Финальные meshes, textures, PBR SurfaceAppearance, анимации и аудио stems не входят
в репозиторий без подтверждённых Roblox asset IDs и лицензий. Это release gate, а
не скрытая «готовность».

### Meta — реализовано

- Creative Rank 1–100.
- Aura Atlas: Color, Texture, Motion, Camera, SetDesign, каждый 1–20.
- Детерминированные mastery unlocks.
- Daily/weekly quests, free reroll, пятидневный daily bank и grace streak.
- Lookbook до 20 записей и отдельные idempotency ledgers.

### Social и retention — реализовано в безопасном минимальном объёме

- Postcards с catalog-only recipes, лимитом 24, positive reactions и ownership-safe remix.
- Ateliers как persisted Founder/Member affiliation с server-local invitation flow.
- Party snapshot и добровольный Roblox game invite prompt.
- Evergreen Community Canvas, personal daily cap, milestones и global total через
  DataStore + MemoryStore cache + MessagingService с graceful fallback.

Ateliers пока не являются полноценными guilds: нет ролей модераторов, cross-server
member directory, пользовательских описаний и UGC-текста. `EditablePostcards`
намеренно выключен.

### Presentation и accessibility — реализовано

- Responsive App shell и adaptive layouts.
- ViewportFrame / WorldModel preview очищенного clone аватара.
- Modular Audio API с legacy Sound fallback.
- Quality-tiered pooled VFX.
- Captions, haptics, reduced motion, low VFX, no flashes, high contrast, large text,
  camera shake и независимые volume settings.

### Platform и безопасность — реализовано

- Schema v3, явные v1→v2→v3 migrations и сохранение прежнего DataStore name.
- Session lease, autosave, shutdown budget, read-only Studio fallback.
- Server authority, remote rate limits, catalog validation и idempotent grants.
- Experience Config allowlist с local fallback и kill-switch-ready LiveOps manifest.
- Funnel/economy/progression analytics и server performance sampling.

## Rollout после кода

### Gate A — integration

1. Прогнать formatter, linter, Rojo build и Studio smoke.
2. Прогнать полный раунд каждой комбинации challenge variants.
3. Проверить migration fixtures v1/v2, duplicate grants и reconnect.

### Gate B — multiplayer/device

1. Studio `Server & Clients`, минимум четыре клиента.
2. Late join на каждом act, leave/rejoin, requeue и party invite.
3. Phone portrait/landscape, tablet, desktop, gamepad, R6 и R15.
4. Профилирование пяти последовательных раундов на целевых устройствах.

### Gate C — production content

1. Импортировать только лицензированные art/audio assets.
2. Заполнить asset manifest с owner, source и fallback.
3. Проверить streaming, memory, moderation и audio loudness.

### Gate D — commerce

1. Создать SKU и заполнить canonical IDs.
2. Проверить developer products в закрытом universe.
3. Реализовать и проверить все pass/subscription benefits.
4. Включать `Purchases`, `Passes`, `Subscriptions` по отдельности после telemetry review.

## Не входит в обещание RC

- Опубликованный production experience и живые Robux-покупки.
- Финальный внешний art/audio pack.
- Доказанная стабильность на четырёх клиентах и реальных low-end phones до ручного QA.
- Полноценная guild/social moderation или свободный пользовательский текст.
- Гарантия retention/KPI без A/B данных после staged launch.
