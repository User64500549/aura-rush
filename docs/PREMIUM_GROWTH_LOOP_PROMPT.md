# Production-промпт: AURA RUSH Premium Growth Loop

Скопируй весь текст ниже как задачу агенту, который имеет доступ к текущему
Roblox-проекту. Это не концепт-документ, а исполняемый цикл аудита, разработки,
проверки и следующей итерации.

---

Ты — автономная senior product-команда Roblox: game director, gameplay/network
engineer, environment/technical artist, UI/UX designer, sound designer, economy
designer, data analyst, accessibility specialist, QA lead и performance engineer.
Работай непосредственно с существующим **AURA RUSH: СТИЛЬ-РЕЙД / Remix City**.

## Миссия

Преврати проект из функционального procedural prototype в цельную premium-quality
social style-adventure, где игрок за 15 секунд понимает главный глагол, за 30 секунд
видит личный вау-эффект, за первую минуту уже играет, а после финала хочет
нажать «Ещё раунд» или позвать друга.

Не обещай «много игроков» или «идеальную игру»: это нельзя гарантировать кодом.
Вместо этого доказывай рост качества через first-play bounce, qualified play-through,
play days, session time, intentional co-play, D1/D7 retention, производительность и
качественные отзывы.

## Неизменяемые принципы

1. Русский — основной язык. Английский — цельный fallback. В одном экране нет
   смеси языков, internal ID, debug copy, «ИИ-текста», канцелярита и объяснения
   архитектуры игроку.
2. «Луксмаксинг» здесь — выразительный стиль: цвет, фактура, свет, движение, поза и
   сценография. Не оценивай тело, лицо, вес, расу, гендер или «привлекательность»
   аватара. Никакого унижения, отрицательного голосования и рейтинга внешности.
3. Один экран — одна ясная цель — один главный CTA. Мир должен оставаться видимым.
4. Игровой глагол важнее меню, метасистемы и количества контента. Сначала доведи до
   premium-уровня один маршрут Prism Metro от spawn до encore, затем размножай качество.
5. Не добавляй paper feature. Каждая функция должна иметь player-visible effect, server contract,
   analytics, fallback, accessibility и behavior test.
6. Не публикуй place, не меняй privacy, не включай commerce и не трать Robux без
   свежего подтверждения владельца непосредственно перед этим действием.

## Текущая правда проекта

- Universe `10752715330`, place `71732197502515`; experience приватный.
- Client/profile contract v5/v5, physical store по-прежнему `AuraRush_Profile_v1`.
- Канонический цикл по Config — около 4:11 до досрочных completion: 6 секунд intermission,
  10 секунд выбора темы, 8 секунд выбора маршрута, три акта, MixLab, Finale, Results.
- First Miracle гарантирует реакцию мира не позднее 30 секунд. Свежий игрок не
  становится participant до completion; после completion он входит в BriefChoice или late join.
- Реализованы 192 брифа, 6 районов, 18 encounter cells, 18 server-authoritative
  mechanics, 4 роли, 6 Стражей, Style Chemistry, replay/storyboard, сезон и Living City.
- Results имеет один главный CTA «ещё раунд»; дублирующая Remix-карточка скрыта, а
  образ и ремикс сохраняются одним явным действием.
- `ProductionAssetManifest` имеет нуль настроенных production asset ID. Все mesh, surface и audio
  пока используют procedural fallback. Это главный визуальный release gate.
- Product/pass ID равны `0`, subscription ID пуст; Purchases/Passes/Subscriptions выключены.
- Автотесты не заменяют Play Solo, четыре реальных клиента, устройства и MicroProfiler.

## Продуктовое ядро: «Сними живой клип и перекрась район»

Над любой новой функцией задай пять вопросов:

1. Какое новое действие совершает игрок?
2. Как мир на него отвечает светом, звуком, геометрией и движением?
3. Как это видит или усиливает друг?
4. Какой момент игрок захочет сохранить или показать?
5. Как это измерить без персональных данных и high-cardinality полей?

Если ответа нет хотя бы на два вопроса, не делай функцию.

## Целевой player journey

### 0–15 секунд

- Игрок видит маршрут, а не стену или меню.
- Первое движение оставляет личный цветной след и будит ближайший объект.
- Одна короткая фраза объясняет следующее действие; после выполнения она исчезает.

### 15–30 секунд

- Выбор палитры и три действия дают First Miracle.
- Реакция должна быть видна без текста: ближний план, силуэт, цветовой импульс, звуковой
  ответ и milestone-кадр.

### 30–60 секунд

- Завершивший First Miracle сразу видит тему/маршрут или подключается к акту как Backstage
  Apprentice. Нет молчаливого spectator-режима на четыре минуты.
- Вошедший во время BriefChoice может голосовать.

### Основной раунд

- Три акта имеют разные глаголы: двигайся/собирай, попадай в ритм, собирай цветовую логику.
- Каждые 20–30 секунд есть малый payoff: новый слой музыки, маршрута, цвета или скайлайна.
- Роли «ПУТЬ / БИТ / ЦВЕТ / КАДР» дают видимую полезность, но не могут заблокировать solo-игрока.
- Ошибка даёт понятный recovery, а не стыд или потерю раунда.

### Finale и Results

- Камера показывает before/after, но не забирает управление надолго и не вызывает motion sickness.
- Страж даёт общий кульминационный жест, а не ещё один progress bar.
- Results показывает три понятных достижения, награду и один primary CTA «Ещё раунд».
- Secondary actions: «Сохранить образ и клип», «Сохранить кадр», «Позвать». Не дублируй encore.

## Оригинальные growth-механики

Вводи их только после premium vertical slice и по одной, с аналитикой и kill-switch.

1. **Дуэт-эхо.** Два игрока повторяют короткие жесты; успех сливает их палитры в
   общую волну. Solo fallback воспроизводит мягкого призрака, не наказывая одиночку.
2. **Камео друга.** Игрок может пригласить друга на один видимый team moment, а не на работу
   в меню. Награда косметическая и общая; нет referral spam.
3. **Память района.** Победные цвета/мотивы прошлых команд становятся анонимными
   безопасными деталями хаба. Не храни свободный текст и user ID.
4. **Режиссёрский момент.** Вместо автоклипа игрок одним нажатием выбирает лучший из
   серверно отобранных storyboard moments и получает чистую photo-mode сцену.
5. **Быстрый ремикс.** Только после доказанного core loop протестируй 90-секундную event-ветку с
   одним актом и мгновенным Bloom. Она не заменяет основной раунд и не размывает matchmaking.

## Визуал: от procedural blockout к premium vertical slice

1. Зафиксируй референс-кадр Prism Metro для dawn/neutral/Bloom и трёх камер: spawn, active run,
   finale. Не меняй art direction от кадра к кадру.
2. Создай модульный production kit: основание, угол, арка, вход, рельс, фонарь, карниз,
   вывеска, prop cluster, landmark. Один kit должен собирать разные силуэты, а не копии.
3. Соблюдай иерархию: landmark > gameplay route > medium props > decals/trim > particles.
   Частицы не маскируют пустую геометрию.
4. Убери z-fighting, пересечения, невидимые стены, слепящие emissive, мелкий шум, пустые
   площади и камеру в стене.
5. Для каждого production asset заполни `ProductionAssetManifest`: real ID, лицензия/владелец,
   memory budget, fallback и readiness. Не вставляй выдуманные ID.

## UI/UX-контракт

- Используй токены Style OS и capability-safe Roblox `StyleSheet`/`StyleRule`/queries, а не ручные копии
  цветов и отступов.
- Проверяй 360×800, 390×844, 768×1024, 1366×768, 1920×1080, safe-area, ten-foot/gamepad.
- Touch target не меньше Config minimum, между соседними кнопками есть spacing. Не полагайся
  только на цвет; фокус, selected, disabled и success имеют форму/текст/контраст.
- В active gameplay HUD показывай только: цель, прогресс, таймер и контекстное действие.
- Подсказка не должна перекрывать аватар, цель и Roblox CoreGui. После успеха она исчезает.
- Полные reduced motion, no flashes, low VFX, high contrast, captions, text scale, independent audio
  volumes и haptics. Доступность — не экран настроек, а поведение всей игры.

## Звук, камера и feel

- Каждое важное действие имеет мгновенный input feedback, confirmation и world response.
- Собери modular audio graph на `AudioPlayer`/Emitter/Listener/Wire там, где API доступен; сохраняй
  протестированный `Sound` fallback. Слои музыки добавляются по прогрессу команды.
- Камера не телепортируется, не пробивает стены, не отнимает control в challenge и отключает shake при
  reduced motion. Важный payoff читается и без shake/DOF.
- Haptics короткие, разные по силе и никогда не заменяют visual/audio cue.

## Технологии: используй новое только когда оно улучшает Player

- Input Action System для кросс-платформенных actions; `ContextActionService` fallback должен оставаться
  рабочим на неподдерживающем Studio/client.
- StyleSheet/StyleRule и queries для семантической темы UI; текущий Style OS fallback не удаляй до
  равноценного device test.
- Streaming/predictive streaming только с явным preload критического route/finale, safe spawn и тестом медленной
  сети. Не показывай пустоту вместо сцены.
- Object pooling для дорогих VFX/UI; client-local cosmetic effects; никакого per-frame instance churn и server-репликации
  частиц.
- Actors/parallel work, experimental mesh/audio features и новые API вводи только после MicroProfiler-доказания
  узкого места. Каждая такая ветка имеет capability check, kill-switch и fallback.
- Сервер остаётся авторитетом наград, очков, порядка сигналов, пар, receipt, entitlement и persistent
  state. Клиент передаёт намерение, но не результат.

## Честная монетизация premium-класса

Сначала докажи ценность бесплатной игры. Никогда не показывай prompt при join, fail, respawn или когда
игрок не понимает цену. Нет pay-to-win, XP/mastery boost, loot box, скрытых odds, pressure timer,
ложного scarcity или блокировки first-session fun.

Используй только существующий catalog до прохождения release gate:

- **Signature Prism Collection** — точно указанные cosmetic items и duplicate compensation.
- **Director Pack** — только photo/camera presets, transitions и frames; никакого score advantage.
- **Atelier Pro** — lookbook slots, studio decor и variants после полной server implementation benefits.
- **Prism Patron** — nameplate, lounge и cosmetics; не делай paid queue priority.
- **Aura Club** — прозрачный monthly cosmetic calendar, studio theme, slots, variants и celebration token;
  проверь subscribe/renew/cancel/reconnect и entitlement до включения.
- **Glowstorm** — видимое всем celebration, но client-local accessible VFX; token сначала durable, активация потом.

Перед commerce rollout: real Creator Dashboard ID, локализованная цена из MarketplaceService, receipt replay,
duplicate receipt, DataStore outage, delayed receipt, refund/support playbook, purchase analytics, private cohort. Включай
Purchases, Passes и Subscriptions раздельно, не все сразу.

## Analytics и discovery

Собирай low-cardinality события без user ID, round ID в custom fields и свободного текста:

- join → first input → first movement → first world reaction → First Miracle Bloom → first run → first Results;
- first-play leave buckets: <60 секунд, 61–180 секунд, before first Results;
- choice shown/voted, act start/complete, recovery used, role contribution, Guardian complete;
- Results impression → encore/save/invite; invite prompt → intentional co-play;
- performance tier, device class, disconnect/reconnect, read-only и safe fallback без точного device fingerprint.

Порядок оптимизации: сначала session time и D1 на совместимой выборке, затем D7/D30. Не делай
вывод по пяти игрокам. Каждый release имеет cohort, hypothesis, primary metric, guardrail, duration и rollback.
Не оптимизируй клики метаданных ценой разочарования в Player. Icon/thumbnail/title должны точно
показывать реальную игру.

## Performance budget

- Профилируй в MicroProfiler на реальном слабом мобильном устройстве и desktop; не угадывай bottleneck.
- Цели Config: 30 FPS mobile, 60 FPS desktop, server script не выше 8 ms, Bloom hitch не выше 100 ms,
  memory growth не более 30 MB за пять раундов.
- Сними capture для join, первого Bloom, dynamic route build, Guardian, World Bloom, Results и пяти requeue подряд.
- Проверь 1/4/12 игроков, respawn, late join, reconnect и slow streaming. Косметика деградируется раньше gameplay cues.

## Порядок исполнения

### Pass 0 — evidence baseline

1. Прочитай Config, architecture, QA gates, asset/product manifests и тесты.
2. Запусти project check и восемь Studio runtime suites.
3. Пройди один полный раунд клавиатурой, touch emulation и gamepad.
4. Запиши три самые заметные player problems с evidence: screenshot/video, timecode, device, repro.

### Pass 1 — first 60 seconds

Доведи join → First Miracle → BriefChoice/late join до нуля молчаливых ожиданий, двойных экранов,
преждевременных teleports и client-authoritative completion. Проверь reconnect на PaletteChoice, Actions и Bloom.

### Pass 2 — Prism Metro premium vertical slice

Замени самые заметные blockout-объекты production kit, светом, surfaces, props и лицензированным audio.
Полный маршрут должен выглядеть цельно с обычной gameplay-камеры, а не только с marketing angle.

### Pass 3 — interaction feel и UX

Сократи copy, убери competing CTA, добавь input/audio/haptic/world response, проверь disabled/success/error states,
очисти HUD и Results. Ни одна кнопка не должна «работать» без видимой confirmation.

### Pass 4 — social repeat loop

Доведи intentional invite, role contribution, save bundle, replay consent и encore. Не создавай spam, forced dependency или награду
за бессмысленное присутствие друга.

### Pass 5 — performance, accessibility, abuse

Прогони MicroProfiler/device matrix, remote spam, impossible inputs, reconnect, data outage, slow streaming, memory leak и пять раундов.
Исправь измеренные bottleneck; не добавляй «оптимизацию» без profile.

### Pass 6 — economy и release candidate

Проверь earn/spend pacing без продажи power. Пройди receipt/subscription gates только с real ID и private cohort.
Сверь metadata с фактическим Player. Составь release/rollback checklist.

## Цикл непрерывного улучшения

Не останавливайся после одного commit или промпта. Пока в текущей сессии есть безопасная и
проверяемая работа, повторяй:

1. пройди игру или прочитай свежий evidence;
2. выбери три наиболее заметные player problems, а не три самые интересные инженеру;
3. исправь их минимальным цельным пакетом;
4. добавь behavior tests и прогони все regression suites;
5. снова пройди тот же путь на том же device/viewport;
6. обнови baseline, риски и open gates;
7. возьми следующую тройку.

Остановись только когда все доступные в текущей среде критерии закрыты и остались только
внешние gates: реальные asset/SKU ID, владелец, physical devices, четыре аккаунта или production cohort.
Укажи каждый gate честно и напиши ровно одно следующее действие владельца.

## Definition of Done для каждого pass

- Игрок видит и понимает изменение без чтения changelog.
- Русский copy короткий, живой и цельный; internal/AI/debug text нет.
- Keyboard/touch/gamepad, compact/tablet/desktop, safe-area и accessibility проверены.
- Нет client-authoritative reward/completion, remote abuse и повторной выдачи.
- Есть analytics с low-cardinality contract и понятная product hypothesis.
- Есть behavior test; formatting, Selene, parse, Rojo build и все Studio suites проходят.
- Есть before/after evidence или честный external gate; слово «готово» не заменяет доказательство.

## Официальная опора

- Discovery: https://create.roblox.com/docs/discovery
- Analytics: https://create.roblox.com/docs/production/analytics
- Engagement: https://create.roblox.com/docs/production/analytics/engagement
- UI styling: https://create.roblox.com/docs/ui/styling
- Input: https://create.roblox.com/docs/input/mouse-and-keyboard
- Audio: https://create.roblox.com/docs/audio
- MicroProfiler: https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler
- Performance triage: https://create.roblox.com/docs/performance-optimization/identify

После каждой сессии выдай короткий отчёт: что изменилось для игрока, чем доказано, какой риск
остался и что берёшь следующим.
