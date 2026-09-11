# AURA RUSH: СТИЛЬ-РЕЙД — Secret Frames v7

«Собери образ. Пройди район. Перекрась сцену.» Это кооперативная
fashion-adventure игра про развитие вкуса и собственного почерка. Игрок собирает
цвет, фактуру, ауру, позу и акцент — игра не оценивает тело или лицо аватара.
Командный образ меняет маршрут, свет, ритм и финальную перекраску района.

## Что реализовано

- Premium City: хаб пересобран вокруг монументального «Сердца стиля» из шести
  переплетённых плавных лент (60 сегментов). Наземное кольцо, 72-сегментный Prism Rail, шесть русских
  маяков районов, независимые от цвета номера и две рабочие фотоплощадки дают
  городу понятную и запоминающуюся географию. Ворота открывают компактное русское
  превью района, а фотоплощадки вызывают штатный безопасный CaptureService.
- `Secret Frames v7`: в шести районах есть по одному постоянному секретному
  кадру. Игрок ищет их по коротким русским намёкам; сервер проверяет
  дистанцию, cooldown и повторную выдачу. Находка даёт 35 Искр и 15 XP
  школы камеры, а полная коллекция — ещё 120 Искр и achievement. Paywall и
  ограничение по времени отсутствуют.
- До запуска тяжёлого UI в `ReplicatedFirst` показывается автономный русский
  loading shell без внешних asset ID. Он различает долгую загрузку и сбой
  клиентского bootstrap, поэтому проектная ошибка не выглядит как бесконечный
  серый экран.
- «Городской пульс» убирает пустое ожидание: четыре физические плиты ПУТЬ / БИТ /
  ЦВЕТ / КАДР запускают одно из шести коротких кооперативных событий, сервер
  проверяет присутствие/cooldown, объединяет рассылки до 12 обновлений/с, а Сердце
  и компактный HUD показывают общий вклад и номер бонусной плиты. При наличии
  группы нужны два участника; одиночный сервер не блокируется.

- «Первый выход» для нового игрока: выбор одной из трёх безопасных палитр и три
  пространственных действия в мире — движение, прыжок, движение с разворотом —
  с серверной проверкой и персональной перекраской не позднее 30 секунд.
  Идемпотентная награда — 100 Искр, 80 XP школы движения и
  `aura_first_miracle`, которая сразу открывается и экипируется. Состояние
  сохраняется и продолжается после reconnect; timeout/skip также ведут к Bloom.
- Серверный цикл `Waiting → Intermission → BriefChoice → 3 adaptive acts → MixLab
  → Finale → Results → Cleanup` и повторный вход в следующий раунд.
- `Adaptive Run Director`: две ветки маршрута, модификатор, анти-повтор последних
  комбинаций, масштабирование командной цели и совместимость с legacy-фазами.
  Пространство композиции проверено как 18 432 теоретических и 1 536 эмпирически
  наблюдаемых gameplay-signatures; повод, эстетика и твист брифа влияют на план.
- 18 серверно-авторитетных механик в непрерывном маршруте: к прежним испытаниям
  добавлены «Сигнальные ворота», парный ритм, заряд темпа, смена палитры,
  ролевые моменты и хореография Стража. Клиент сообщает только намерение — очки,
  пары, порядок сигналов и завершение проверяет сервер.
- `Remix City`: 18 вручную собранных encounter cells, четыре понятные командные
  роли (`ПУТЬ`, `БИТ`, `ЦВЕТ`, `КАДР`) и шесть разных Стражей районов. Три акта
  физически соединены в один маршрут без телепортов между сценами.
- `Style Chemistry` детерминированно находит три читаемые реакции командного
  образа из 20 рецептов и показывает живое русское название вместо технических ID.
- Серверный сториборд фиксирует до 12 лучших моментов раунда. С согласия игрока
  результат можно сохранить в один из восьми replay-слотов, безопасно воспроизвести
  или удалить с подтверждением; чужие user ID в запись не попадают.
- Первый сезон Remix City содержит 40 узлов на восемь недель, бесплатные
  косметические награды и Искры. Выдача и защита от повторного получения находятся
  на сервере; платная дорожка не включена без настроенного commerce-контракта.
- Четыре модификатора теперь влияют на игру, а не только на подпись: отражают или
  повторяют дорожки, запускают волну сигналов либо дают более высокий прыжок.
- `Aura Genome` из пяти категорий экипировки и детерминированный `Bloom Recipe v4`:
  палитра, материал, аура, поза, акцент, маршрут и качество прохождения меняют
  геометрию, свет, VFX-мотив, камеру, landmark и три акта финального Bloom.
- Late join как `Backstage Apprentice`: сервер подключает игрока к текущему акту,
  отмечает долю участия и пропорционально масштабирует базовые награды и XP.
- 192 безопасных брифа: 6 миров × 4 повода × 4 эстетики × 2 твиста.
- Шесть районов с разными силуэтами, материалами, русской навигацией и
  трёхступенчатой перекраской: Призма-метро, Облачный квартал, Лунная оранжерея,
  Орбитальная набережная, Бархатный архив и Солнечный собор.
- Метапрогрессия: Creative Rank 1–100, пять школ Aura Atlas 1–20, детерминированные
  mastery-unlock, GlowDust, ежедневные/недельные задания и банк daily на пять дней.
- «Мой стиль» с вкладками, Районом недели, Общим районом, Лукбуком до 20 образов,
  daily/weekly quests, Postcards с безопасными recipe и позитивными реакциями,
  ownership-safe remix, а также Ateliers с role/TTL/cooldown-проверками,
  отклонением и блокировкой приглашений.
- Район недели меняется по безопасной серверной ротации из шести локаций и хранит
  отдельный недельный прогресс. Общий район сохраняет глобальные этапы и награды.
- Party-aware серверный snapshot и нативный invite prompt только после явного
  нажатия игрока.
- Русский — основной язык. Компонентный `Style OS` использует семантические токены,
  visual item tiles, понятные CTA, safe-area, адаптивную сетку, gamepad focus,
  hit targets не меньше 48 px и capability-safe `StyleSheet`/`StyleQuery` fallback.
- Язык Roblox-аккаунта больше не переключает часть игры на английский. Вступление,
  Первый выход, настройки и «Мой стиль» скрывают вторичный HUD; пустой toast не
  показывается, а камера при первом появлении направлена на Сердце.
- Настройки игры объединены с системными предпочтениями Roblox: reduced motion,
  preferred text size и transparency; сохранены captions, haptics, high contrast,
  low VFX и независимая громкость каналов.
- Камера заранее подгружает финальную сцену; свет, глубина резкости и VFX читают
  `ArtDirectionRegistry` для всех шести районов. Вместо одинаковых шаров используются
  сигналы, жемчуг, лепестки, орбиты, страницы и солнечные осколки. Glowstorm
  реплицирует только событие, а эффекты строятся локально с учётом reduced motion,
  no flashes и low VFX.
- Modular Audio graph включает fader/compressor/EQ/reverb с безопасным fallback на
  `Sound`; Bloom Recipe меняет EQ, reverb и pulse, а лицензированные production
  stems всё ещё требуют реальных asset ID.
- Новый Input Action System используется для ритма и Prism Puzzle при поддержке
  текущим клиентом; `ContextActionService` остаётся безопасным fallback.
- Client contract v6 и profile schema v5 без смены DataStore key: миграции
  v1→v2→v3→v4→v5, session lease, autosave,
  read-only fallback в Studio, раздельные ledger для наград, трат и receipts.
- 32 объявленных remotes, серверная авторитетность, rate limits, идемпотентные
  round/quest/event/receipt операции и телеметрия funnel/economy/progression.
- Runtime Experience Config allowlist ограничен ровно флагами `FirstMiracle`,
  `AdaptiveRuns`, `Progression`, `LiveOps`, `Crews`, `CommunityBloom`,
  `EditablePostcards`, `ModularAudio`, `ChallengeFramework2`, `BloomComposer2`,
  `SpatialFirstMiracle`, `LivingCity`, `StyleOS`, `RemixCity`, `StyleChemistry`,
  `GuardianFinales`, `ReplayGhosts`, `SeasonOne`, `CityPulse`, `SecretFrames`.
  Persistence, capture, analytics,
  экспериментальные API и commerce не могут быть удалённо включены этим каналом.

## Быстрый запуск

```powershell
powershell -ExecutionPolicy Bypass -File tests/check-project.ps1
powershell -ExecutionPolicy Bypass -File tests/run-studio-smoke.ps1
```

Второй скрипт запускает 12 независимых headless Studio `RunScript` проверок:
структуру, loading shell, жизненный цикл Capture, gameplay director, Первый выход,
русский текст, presentation, economy/liveops/social, Living City v4, Remix City v5,
Premium City v6 compatibility и Secret Frames v7. Они проверяют
runtime-контракты, но не являются интерактивным `Play Solo`.

Точечный запуск нового контракта:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run-studio-smoke.ps1 -Script secret-frames-v7-smoke.luau
```

Или вручную:

`tests/check-project.ps1` — канонический build: после Rojo он сериализует новые
NotScriptable Workspace enum-свойства, которых ещё нет в reflection-базе Rojo 7.7.
Для live-editing используйте `rojo serve default.project.json`.

Откройте `AuraRush.rbxlx` в Roblox Studio либо подключите Rojo plugin к
`127.0.0.1:34872`. В неопубликованном Studio-place сохранения работают в безопасном
read-only режиме, если DataStore API недоступен.

## Монетизация

В коде есть прозрачный косметический каталог: известные пакеты GlowDust,
детерминированная Signature Prism Collection и Glowstorm как сохраняемый
activation token. Ничто платное не повышает результат испытаний и не обходит
mastery. Все product/pass ID равны `0`, subscription ID пуст, а `Purchases`,
`Passes` и `Subscriptions` выключены. До публикации ID и полного receipt-теста
покупки недоступны по замыслу.

## Release gates

Последний автоматический evidence run: `2026-09-04T05:03:33.3327838Z`, build
`SHA256 57DB30D472E7F365D9F1EF3777CBD5CE39B8F4A52C65CBADA917710BCBFC2019`,
`1039450` байт. 12 runtime suites дали PASS, runner завершился с кодом `0`;
premium world: `402` hub parts, `1140` world parts, `23` lights и `293`
частично прозрачных BasePart. Полный лог: `studio-smoke.log`.
Style Chemistry отдельно проверена на 512 сочетаниях предметов после ошибки,
обнаруженной живым Play Solo. [Интерактивный аудит](docs/PLAY_SOLO_V6_REVIEW.md).
Дополнительно в настоящем Play Solo проверены загрузка LocalPlayer, русский
onboarding, ракурс маршрута, примерочная, «Мой стиль», Results и возврат в хаб.
Это не заменяет ручное прохождение всех физических действий и multiplayer/device QA.
Последняя серверная правка отделяет ручной ввод от автоподбора палитры;
normal/timeout/resume/rejected/duplicate paths повторно проверены smoke suite.

Release candidate ещё не считается production-ready, пока не выполнены:

1. Подключение и лицензирование финальных Roblox asset IDs, внешнего art pack и
   музыкальных/ambient/SFX stems.
2. Создание SKU в Creator Dashboard, заполнение ID, проверка benefits и закрытый
   commerce-тест до включения флагов.
3. Завершение ручной матрицы Studio `Play Solo`: normal/skip First Miracle,
   физические действия, все input paths и Capture. Частичный desktop UI/round
   проход от 03.09.2026 записан отдельно и не считается полным gate.
4. Ручной Studio `Server & Clients` тест минимум с четырьмя клиентами, включая
   late join, reconnect, party invite, World Bloom и повторную доставку receipt.
5. Device/performance profiling на целевых телефонах, desktop и gamepad, включая
   фактический `ServerBoot.WorldBuild` p50/p95.

Подробности: [master-промпт Premium City v6](docs/PREMIUM_CITY_V6_MASTER_PROMPT_RU.md),
[аудит Premium City v6](docs/PREMIUM_CITY_V6_AUDIT.md), [Remix City v5](docs/REMIX_CITY_V5.md),
[Living City v4](docs/LIVING_CITY_V4.md),
[архитектура v2](docs/ARCHITECTURE_V2.md),
[арт-библия](docs/ART_BIBLE.md), [экономика](docs/ECONOMY_AND_MONETIZATION.md),
[hardening экономики и social](docs/ECONOMY_SOCIAL_HARDENING.md),
[LiveOps](docs/LIVEOPS.md), [миграции](docs/DATA_MIGRATIONS.md),
[аналитика](docs/ANALYTICS_PLAN.md), [QA-матрица](docs/QA_MATRIX.md) и
[changelog](docs/CHANGELOG.md). Текущая память эволюции: [vision](docs/VISION.md),
[анализ игры](docs/GAME_ANALYSIS.md), [upgrade state](docs/UPGRADE_STATE.md),
[известные проблемы](docs/KNOWN_PROBLEMS.md), [backlog](docs/IDEA_BACKLOG.md) и
[метрики](docs/METRICS.md).
