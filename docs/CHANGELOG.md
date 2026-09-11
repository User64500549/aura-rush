# Changelog

## 7.0.0-rc — Secret Frames и resilient startup

### Первые секунды

- До тяжёлого App монтируется русский `ReplicatedFirst` loading shell без внешних
  asset ID; default loading screen убирается только после mount.
- Client bootstrap получил верхнюю `xpcall`-границу и явные `client_starting` /
  `ready` / `failed` states. Долгая загрузка и ошибка теперь различимы.
- Server bootstrap замеряет синхронную сборку мира как `ServerBoot.WorldBuild`.

### Исследование города

- Добавлены шесть авторских Secret Frames: по одному на район, с русскими
  намёками, коротким reveal и постоянным прогрессом в Creator Hub.
- Награду контролирует сервер: дистанция, cooldown, allowlist ID, feature flag и
  namespaced idempotency ledger. Полная коллекция выдаёт отдельный one-time bonus.
- Механика не имеет paywall и time gate; runtime kill switch отключает prompts без
  перезапуска сервера.

### Reliability и evidence

- Исправлен `CaptureController`: первый screenshot больше не уничтожает постоянную
  подписку фотозон; все connections снимаются в `Destroy`.
- Добавлены loading, lifecycle и 133-check Secret Frames suites. Полный runner теперь
  состоит из 12 независимых Studio RunScript suites.
- Созданы постоянные `VISION`, `GAME_ANALYSIS`, `UPGRADE_STATE`, `UPGRADE_HISTORY`,
  `KNOWN_PROBLEMS`, `IDEA_BACKLOG` и `METRICS`; они разделяют реализованное и внешние gates.

## 6.0.0-rc — Premium City: Сердце стиля

### Карта и живой хаб

- Хаб пересобран вокруг `HeartOfStyle`: шесть переплетённых цветных лент,
  читаемый arrival → heart → districts flow, наземное кольцо и 72-сегментный
  elevated Prism Rail.
- Добавлены шесть русских маяков районов, независимые от цвета числовые cues,
  радиальные линии, функциональные preview prompts и две фотоплощадки, связанные
  с безопасным CaptureService.
- `CityPulseService` превращает ожидание в короткое кооперативное действие на
  четырёх физических плитах. Состояние проверяет сервер; видимые номера/русские
  labels и HUD объясняют бонусную плиту; progress replication ограничен 12/с.
- Skyline вынесен из северных ворот/rail; spatial smoke блокирует повторный clipping.

### Исправления по живому Play Solo

- Устранён реальный crash сортировки Style Chemistry; 512 образов проверяются
  дважды на корректный, детерминированный порядок.
- Продуктовый язык теперь русский независимо от LocaleId аккаунта; сокращены
  подписи, palette buttons сохраняют читаемый контраст, read-only не обещает save.
- Найдена и исправлена причина пустых карточек: декоративный Frame вытеснял
  содержимое UIListLayout. Обводка панелей больше не обводит мелкие буквы.
- Единая PresentationPolicy убирает роли/дополнительные плашки поверх примерочной,
  выбора и кнопочных испытаний. Предупреждение о сохранении занимает свой слот
  в topbar. PlayerList не закрывает таймер/настройки; системные safety UI сохранены.
- Стартовая камера показывает Сердце, а камера каждого акта смотрит вдоль пути.
  Framing краткий, не блокирует управление и отменяется при смене фазы.
- ThreadRun получил боковую компактную карточку; отсутствующие варианты маршрута
  скрыты вместе с недоступными gamepad-переходами; исчез пустой toast.
- Кнопки проверки шага и пропуска первого выхода разнесены на отдельные строки:
  обе цели 48 px, между ними 10 px; проверено в живом GUI и layout regression.
- Автоматический выбор палитры больше не выдаётся за `first_input`. Принятый
  ручной выбор или последующее действие учитываются один раз на активную сессию.
- Приглушены Bloom/rail, осветлено основание, ленты Сердца разбиты на 60 плавных
  сегментов, ограничена дальность табличек и расширен свободный вход между фонарями.

### Контракты и качество

- Client/Remix/Run contract обновлён до v6 без изменения profile schema v5.
- Добавлены PremiumCityCatalog, remote-safe flag, hub performance budgets и отдельный
  Studio smoke suite.
- Исправлены lifecycle/hot flag City Pulse, replay HUD, role storyboard spam и
  восстановление pulse visuals после общего Bloom reset.
- Runner принимает только отдельные runtime PASS lines, сначала ищет ошибки,
  проверяет freshness/hash и использует отдельный place на suite.
- Итоговый world budget: 372 hub parts, 1110 world parts, 23 lights и 287/320
  partially transparent parts; все девять Studio suites проходят.
- Созданы новый master-промпт, доказательный аудит и map concept v3; commerce
  остаётся safe-off, публикация не выполнялась.

## 5.2.0-rc — Premium Growth Loop

### First-session integrity

- Основной цикл ждёт не просто подключённого, а загруженного и готового к раунду
  игрока. First Miracle и active round больше не конкурируют за teleport, phase и UI.
- Завершивший First Miracle не ждёт следующего полного цикла: он входит в BriefChoice и
  может голосовать, либо подключается к active act через Backstage Apprentice.
- Reconnect на PaletteChoice/Actions/Bloom возобновляет First Miracle без повторного welcome.
- Клиент больше не может обойти First Miracle обычным `UpdateSettings`; v5 migration
  повышает entry contract до First Miracle v2 и не понижает future schema.

### Results UX

- Дублирующая Remix Results card скрыта; на главном экране остался один primary CTA
  «ещё раунд», он же получает gamepad focus.
- Образ и personal remix сохраняются одним действием; read-only state явно отключает кнопку.

### Verification

- Formatting/Selene/parse/Rojo: 0 errors, 0 warnings; `AuraRush.rbxlx` собирается.
- Все восемь Studio RunScript suites проходят; structural smoke — 152 checks.
- Реальные production asset/SKU ID, Player screenshot matrix, 4-client и physical-device MicroProfiler
  остаются честными external gates.

## 5.1.0-rc — Prism Metro vertical slice

### World / first session

- Creator Hub и Prism Metro пересобраны в цельный modular kit: слои фасадов,
  рельсы, бордюры, ритмический свет, лампы, кинетическая арка и чистая
  основная линия.
- Spawn вынесен из landmark, развёрнут к маршруту и защищён явной safe-zone;
  collision-smoke не находит барьеров в центральной полосе.
- First Miracle гарантирует большую реакцию не позднее 30 секунд. Движение
  сразу оставляет локальный цветовой сигнал; 12 плит маршрута отвечают
  усиленным импульсом.

### UI / copy / performance

- Приветствие, hub, выбор темы и Remix HUD сжаты до компактных контекстных
  карточек, которые оставляют мир видимым. Русский copy сокращён и очищен от
  служебных формулировок.
- Цветовой след клиентский, pooled и adaptive: 0 новых remotes, реже на low tier,
  полностью off для reduced motion, no flashes и low VFX.
- Добавлена low-cardinality воронка `first_input` → `first_movement` →
  `first_world_reaction` без user ID и свободного текста.

### Verification

- Formatting/Selene/parse/Rojo: 0 errors, 0 warnings; сборка `AuraRush.rbxlx` успешна.
- Все восемь Studio RunScript suites проходят; structural smoke — 138 checks.
- Ручной Player/device/performance pass, лицензированные asset IDs и Creator Dashboard
  SKU остаются открытыми release gates.

## 5.0.0-rc — Remix City

### Gameplay / UX

- Добавлены четыре кооперативные роли, 18 авторских encounter cells, шесть Стражей
  районов и непрерывная трасса без телепортов между тремя актами.
- Каталог расширен до ровно 18 server-authoritative механик: Signal Gate, Duet,
  Tempo Charge, Palette Shift, Role Spotlight и Guardian Choreography работают как
  игровые правила, а не как декоративные теги.
- Style Chemistry содержит 20 детерминированных реакций и три русских результата.
- Новый адаптивный русский Remix HUD показывает роль, химию, сториборд и Стража;
  replay-анимация, Guardian audio/VFX и настройки доступности связаны с событиями.

### Retention / data / safety

- Сезон 1: 40 узлов на восемь недель, серверная выдача бесплатных наград и защита
  от повторного claim. Premium entitlement остаётся safe-off.
- Серверный сториборд, явное replay-consent, архив до восьми записей, безопасное
  воспроизведение/удаление и отсутствие user ID в replay payload.
- Profile schema v4 и миграция v3→v4 добавляют remixCity state без смены DataStore.
- Блокировка Atelier-приглашений сохраняется на 30 дней, а production asset bridge
  принимает только реальные configured ID и честно включает procedural fallback.

### Verification

- Client v5, schema v4, 32 remotes; formatting/Selene/Rojo — PASS.
- Восемь независимых Studio RunScript markers, structural smoke — 136 checks.
- `AURA_RUSH_REMIX_CITY_V5_PASS` подтверждает cells, роли, сезон, HUD, replay и
  production-asset fallback в реальном Roblox runtime.

## 4.1.0-rc — Living City v4

### Added

- Компонентный русский Style OS: visual item tiles, 44–48 px hit targets,
  gamepad focus, accessibility metadata и capability-safe StyleSheet/StyleQuery.
- 12 server-authoritative gameplay mechanics; occasion/aesthetic/twist теперь
  формируют реальный mechanicProfile каждого акта.
- Пространственный First Miracle с серверной проверкой движения, прыжка и поворота.
- Bloom Recipe v4 и Living City route geometry: экипировка, маршрут и performance
  меняют материал, палитру, VFX, аудио, камеру и landmark финала.
- Input Action System с ContextActionService fallback.
- ProductionAssetManifest на 66 честных asset slots и новые brand v2 PNG sources.

### Security / economy / social

- Qualified-participation anti-AFK, безопасный late join, раздельные personal/global
  milestones, единый action budget daily bank и lifetime streak.
- LiveOps manifest v2 fail-closed; Atelier role/TTL/cooldown/revalidation,
  decline/block; postcard privacy; durable paid-receipt archive и tombstones.
- Glowstorm стал client-local и соблюдает reduced motion/no flashes/low VFX.
- Commerce и неподключённые experimental features остаются safe-off.

### Verification

- Project check: formatting PASS, Selene 0 errors/0 warnings, Rojo build PASS.
- Studio RunScript: 128 structural checks и семь независимых PASS-marker.
- Gameplay composition: 18 432 theoretical / 1 536 empirical signatures.
- Добавлены economy/liveops/social и Living City v4 runtime contracts; PASS-marker
  больше нельзя получить из напечатанного source после упавшего assertion.

## 4.0.0-rc — «Стиль-рейд»

### Product / copy

- Русский язык стал основным; сохранён полный английский fallback и stable ID.
- Новое позиционирование: «Собери образ. Пройди район. Перекрась сцену.»
- Добавлены 283 локализационных ключа, 70 названий предметов и безопасные helpers,
  которые не показывают игроку raw ID или developer-текст.
- Player-facing термины переписаны коротким живым языком; убраны псевдопоэзия,
  технический жаргон, случайный caplock и английские названия игровых фаз.

### UX / presentation

- UI переведён на editorial × music clip × city wayfinding арт-направление с
  семантическими токенами, понятными CTA, вкладками Профиля и адаптивными layout.
- Добавлен platform accessibility bridge для reduced motion, preferred text size и
  transparency с graceful fallback.
- Все шесть районов получили отдельные силуэты, русскую навигацию, слои глубины,
  landmarks и трёхступенчатую перекраску из `ArtDirectionRegistry`.
- Финальная камера делает streaming prefetch; lighting/DOF, VFX-мотив и audio EQ/reverb
  выбираются по району. Low-VFX/no-flash режимы остаются функциональными.
- Добавлены готовые key art и experience icon в `assets/brand/`.

### Gameplay / retention

- Модификаторы маршрута получили серверно-авторитетный эффект: mirror/echo/wave
  преобразуют сигналы, «Лёгкий шаг» временно меняет прыжок и безопасно его возвращает.
- «Район недели» ротирует шесть локаций каждые семь дней и хранит отдельный недельный
  вклад без изменения schema/DataStore key.
- Добавлены localization и presentation smoke contracts; общий runner теперь содержит
  пять изолированных Studio RunScript случаев.

## 3.0.0-rc — global upgrade

### Added

- First Miracle: reconnect-safe серверный onboarding до 90 секунд с тремя
  ordered actions, timeout/skip путями, персональным Aura Genome Bloom и
  идемпотентной наградой 100 GlowDust + 80 Motion Aura Atlas XP +
  `aura_first_miracle`.
- Adaptive Run Director с route options, modifiers, deterministic composition,
  difficulty/team scaling и anti-repeat history.
- Проверяемое пространство Run Director: 18 432 theoretical и 1 536 empirical
  gameplay-signatures; world/occasion/aesthetic/twist влияют на композицию.
- Material Surf, Light Loom и Bloom Rescue рядом с тремя legacy challenges.
- Aura Genome, team diversity/synergy и version 2 Bloom Recipe.
- Late join `BackstageApprentice`, proportional completion rewards/XP и requeue.
- Velvet Archive и Solar Cathedral; теперь шесть art-directed worlds.
- Brief Catalog расширен со 128 до 192 комбинаций.
- Art Direction Registry с palettes, material families, silhouettes, lighting и sound motifs.
- Creative Rank 1–100 и пять школ Aura Atlas 1–20.
- Deterministic mastery unlocks и отдельные progression/economy ledgers.
- Daily/weekly quests, free reroll, пятидневный daily bank и grace streak.
- Lookbook save/delete/equip до 20 образов.
- Postcards, ownership-safe remix, positive reactions и Ateliers.
- Creator Hub для профиля, Aura Atlas, Community Canvas/milestones, quests,
  Lookbook, Postcards и Atelier/crew flows.
- Party snapshot, voluntary native invite prompt и launch context.
- Evergreen Community Canvas / Community Bloom с milestones и global total pipeline.
- Schema v3 migrations, activation tokens и новые social/live-ops profile fields.
- Runtime Experience Config allowlist ровно из `FirstMiracle`, `AdaptiveRuns`,
  `Progression`, `LiveOps`, `Crews`, `CommunityBloom`, `EditablePostcards`,
  `ModularAudio`, плюс local feature fallback.
- Funnel, economy и progression analytics wrappers.
- Server performance sampler и declared RC budgets.
- ViewportFrame avatar preview, pooled quality VFX и modular Audio API fallback.
- Accessibility: no flashes, high contrast, captions, haptics, ambience volume и
  сохранение существующих reduced-motion/low-VFX/large-text controls.

### Changed

- Round generation теперь выбирает adaptive acts, сохраняя legacy phase contract.
- Completion rewards и базовый progression XP учитывают late-join participation ratio.
- Миры и финал используют versioned recipe и три Bloom acts.
- Streaming radii уменьшены для mobile-first загрузки.
- Remote registry создаётся из shared definitions и охватывает meta/social/token flows.
- Client/profile contract зафиксирован на v3/v3, registry содержит 30 remotes.
- Paid Server Glowstorm больше не запускается receipt-ом мгновенно: receipt сохраняет
  activation token, который игрок активирует отдельно.
- Старый gift placeholder заменён детерминированной Signature Prism Collection.
- `Prism VIP` переименован в `Prism Patron`; ID всё ещё не настроен.

### Security / fairness

- Mastery cosmetics нельзя купить через GlowDust или paid collection.
- Paid receipt, earnable grants и spends разделены.
- Social recipes не содержат свободный текст; reactions работают по positive allowlist.
- Postcard remix не выдаёт отсутствующие предметы.
- Commerce prompts остаются explicit-click only, IDs `0`/`""` safe-off.
- Read-only profile не подтверждает receipt и блокирует durable social/economy mutations.

### Migration

- Profile schema поднята с v1 до v3 без изменения physical DataStore name.
- v1→v2 переносит receipts/round history в ledgers и нормализует saved looks.
- v2→v3 добавляет quests, live-ops, activation/pending activation tokens,
  postcards, atelier, First Miracle state и grant ledger.

### Verification

- `tests/check-project.ps1`: formatting, Selene и Rojo build release candidate.
- Headless Roblox Studio `RunScript`: `AURA_RUSH_SMOKE_PASS (120 checks)`.
- Headless Roblox Studio `RunScript`: `AURA_RUSH_GAMEPLAY_DIRECTOR_SMOKE_PASS`
  с 18 432 theoretical / 1 536 empirical signatures.
- Headless Roblox Studio `RunScript`: `AURA_RUSH_FIRST_MIRACLE_SMOKE_PASS`.
- Эти три PASS не считаются ручным `Play Solo`; интерактивная client/server/UI
  проверка остаётся отдельным release gate.

### Known release gates

- Финальные Roblox asset IDs, лицензированный external art и production audio stems не включены.
- Developer product/pass/subscription IDs не настроены; соответствующие flags выключены.
- Pass/subscription benefits не считаются проверенными для продажи.
- Ручной Roblox Studio Server & Clients тест минимум с четырьмя клиентами не может
  быть заменён статическим/одноклиентным smoke.
- Ручной Roblox Studio Play Solo с First Miracle, Creator Hub, полным раундом и
  чистым server/client Output остаётся отдельным gate от headless RunScript.
- Реальные mobile/desktop performance captures требуются после final asset import.
