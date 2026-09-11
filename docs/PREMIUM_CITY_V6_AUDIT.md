# Premium City v6 → Secret Frames v7 — доказательный аудит

Дата последнего автоматического прохода: 2026‑09‑04. Объект: локальная сборка
`AuraRush.rbxlx`; живой приватный place этим проходом не изменялся.

## Исправленные причины сырого состояния

| Симптом | Причина | Исправление | Доказательство |
|---|---|---|---|
| Хаб был плоской круглой площадкой без главного образа | Не было пространственной иерархии | `HeartOfStyle`, arrival→heart→districts, ground loop, Prism Rail, новый skyline | 6 плавных лент / 60 сегментов, 72 rail segments, clear gateway/rail overlap test |
| Районы не читались как единый город | Не было overview и стабильных русских имён | Шесть ворот, radial routes, номера/формы и канонические названия | 6 gateways/labels/prompts, каталог v6 |
| Северные ворота и rail клиппились с фасадами | Старый skyline стоял внутри нового кольца | Фасады вынесены за ворота, оставлен центральный sightline | `GetPartsInPart` не находит пересечений с `PlazaFacade` |
| Ожидание между забегами было пустым | Hub был только декорацией | Серверный City Pulse: 4 плиты, 6 событий, 2 участника при доступной группе | service/UI/lifecycle smoke |
| Игрок не понимал бонусную плиту без различения цвета | Название существовало только в metadata | Видимые `1 · ПУТЬ` labels и `БОНУС: 1 · ПУТЬ` в HUD | 4 rendered labels + HUD assertion |
| Ворота и фотозоны были декоративными stubs | Атрибуты никто не потреблял | Русские ProximityPrompt; ворота показывают preview, фотозона вызывает CaptureService | 6 preview + 2 photo prompt contracts |
| Reset раунда стирал реакцию Сердца при живом progress | Общий Bloom reset затрагивал pulse visuals | После reset повторно применяется authoritative City Pulse state | color preservation assertion |
| Повтор мог вернуть устаревший HUD | Replay скрывал только ScreenGui | Panel/PulseCard скрываются, live state восстанавливается | controller/UI code audit |
| Смена одной роли могла вытеснить storyboard | Повтор той же роли писал important moment | Same-role ignored, фазы ограничены, role moment не important | server phase/cooldown contract |
| Kill switch/re-init мог оставить старый loop | Lifecycle опирался на общий boolean | lifecycle epoch, flag listener, полный Stop и очистка участника | stopped snapshot + static/runtime smoke |
| Массовые касания могли раздувать репликацию | Лимит 12/с был только числом в каталоге | World/UI state coalescing с immediate start/complete | getter/budget contract; implementation audit |
| Частичная прозрачность превышала budget: 446 | Непрозрачные metal/marble/plastic arcs делались alpha-layer | Alpha оставлена настоящему стеклу, остальные silhouette rings opaque | итог `287 ≤ 320`; hub `56 ≤ 72`; каждая зона `≤100` |
| Streaming/SLIM код молча падал | NotScriptable properties задавались из server Luau; SLIM получил boolean | Runtime pcall удалён; enum tokens сериализуются build-gate и проверяются capability-safe | XML token gate + Studio fallback/enum check |
| Studio runner мог принять PASS из напечатанного source | Искомая строка не была привязана к runtime line | anchored marker, failure-first scan, final reread, isolated place per suite | 9 runtime markers, 0 RunScript errors |
| Реальный раунд срывался до первого акта | Асимметричный tie-break в Style Chemistry нарушал порядок сортировки | Одинаковый seed обеих сторон, стабильный final tie-break по ID | 512-loadout regression; live recheck |
| Первый экран смешивал русский и английский | App наследовал LocaleId аккаунта, часть copy была авторской RU | Единая продуктовая локаль App/Store, без auto-translation GUI | Play Solo с английской локалью аккаунта |
| Вступление/Первый выход конфликтовали с Pulse и topbar | У независимых ScreenGui не было общего приоритета и inset | Primary overlay registry, SuppressSecondaryHud, согласованные safe-area | suppression regression + Play Solo |
| Стартовый кадр смотрел от центра и был пересвечен | Spawn CFrame не управлял default camera; слишком сильный Bloom | Arrival framing, мягкий Bloom, металлический rail, более светлое основание | отдельный интерактивный review |
| Карточки были пустыми, кнопки уходили за край | Accent Frame участвовал в UIListLayout как полноразмерный элемент | Layout-neutral UIStroke; Border вместо обводки букв | реальный Play Solo + layout regression |
| Примерочную перекрывали роли и служебные строки | Несколько равноправных HUD рисовались поверх основного действия | PresentationPolicy, read-only badge в topbar, snapshot-safe suppression | тест реального App renderer + интерактивный review |
| После teleport игрок видел путь позади себя | Camera сохраняла предыдущий кинематографический ракурс | Arrival metadata каждого chunk, короткий framing после готовности персонажа | direction dot-product + Play Solo |
| Пустой третий маршрут выглядел незавершённым | Template оставался видимым при двух вариантах | Скрытие отсутствующих карточек и корректная gamepad-соседность | real renderer 2→3 choices regression |
| Skip перекрывал проверку шага | Процентные позиции конфликтовали на короткой панели | Фиксированная вертикальная сетка, цели 48 px, зазор 10 px | реальный layout regression + короткий Play Solo |
| Автоподбор завышал метрику первого ввода | Общий setPalette безусловно отправлял `first_input` | Только принятый ручной выбор/действие, session-local dedupe | normal/timeout/resume/rejected/duplicate smoke |
| Серый экран не объяснял прогресс/сбой | UI ждал полный client bootstrap | Автономный `ReplicatedFirst` shell + ready/failed contract | 18 loading-shell checks |
| Первый screenshot ломал следующую фотозону | Action disconnect-ил постоянный listener | Connections живут до `Destroy` | 6 client-lifecycle checks |
| У районов не было побочной цели для исследования | Фотозоны не создавали exploration loop | 6 Secret Frames, hints, reveal, permanent collection | 133 runtime checks + manual route gate |

## Traceability: требование → реализация → тест

| Требование master‑промпта | Статус | Код/данные | Проверка или внешний gate |
|---|---|---|---|
| Новый дизайн карты и ясная навигация | Реализовано как production-capable procedural fallback | `WorldService`, `PremiumCityCatalog`, map concept v3 | spatial/count/Russian contract; ручная screenshot matrix остаётся gate |
| Русский UX без шаблонного AI‑текста | Реализовано для нового v6 слоя | catalog, pad/gateway/photo labels, `RemixOverlay` | Cyrillic/forbidden-copy smoke; полный screenshot review остаётся gate |
| Style Routes | Реализовано | route vote, 3 physical patterns, continuous geometry | gameplay director + Remix v5 suites |
| District Remix | Реализовано | Aura Genome/Style Chemistry → Bloom recipe/world mutation | deterministic composition/Bloom tests |
| Guardian Variants | Реализовано | 6 Guardians, role pattern, anti-repeat Run Director | Remix v5 suite |
| Secret Frames | Реализовано v7 | catalog/world/service/profile/meta/reveal, server authority и idempotency | 133 checks; видимость и touch/gamepad остаются manual gate |
| Friend Encore | Частично | server requeue/encore stats и party-aware snapshot | нужен 4-client UX test сохранения состава |
| Функциональные фото и превью районов | Реализовано | ProximityPrompt → Capture/preview | premium v6 suite; системный save prompt решает Roblox/игрок |
| City Pulse social loop | Реализовано | physical `.Touched`, proximity, cooldown, min contributors, network cap | premium v6 suite; 4-client feel test остаётся gate |
| Воронка City Pulse | Реализовано в коде | impression, first pad, complete, next run | low-cardinality implementation; dashboard/cohort — после запуска |
| Честная монетизация | Safe-off | cosmetic catalog, нулевые SKU, flags off | economy suite; реальные Dashboard/receipt/refund tests — gate |
| Современный streaming | Реализован с fallback | StreamingEnabled + serialized enum tokens | build XML gate; локальная Studio сообщает capability fallback |
| Profile/DataStore compatibility | Реализовано | client v6, schema v5, прежний DataStore key | structural/economy/migration suites |

## Автоматический evidence run

- Build/hash/UTC фиксируются в [`UPGRADE_STATE.md`](UPGRADE_STATE.md) после каждого
  канонического evidence run.
- Static: Stylua check PASS; Selene `0 errors / 0 warnings / 0 parse errors`; Rojo build PASS.
- Studio runtime: 12 PASS markers, 0 `RunScript` failures.
- Structural suite: 161 checks; Secret Frames suite: 133 checks.
- Premium counts: hub BasePart `402/480`, world BasePart `1140/2600`, lights
  `23/24`, hub layered transparency `62/72`, total `293/320`.
- Style Chemistry regression: 512 разных образов, каждый проверен дважды.
- First input: manual, timeout, resumed timeout, rejected и duplicate paths PASS.
- Самая тяжёлая streamed-зона по layered transparency: `PrismMetro 85/100`.
- Локальная Studio не экспонирует четыре новые Workspace members и честно пишет
  capability fallback; build всё равно содержит canonical enum tokens.
- Полный исходный лог: `studio-smoke.log`.

## Осознанно открытые внешние gates

- Procedural art — сильный fallback, но не лицензированный финальный mesh/material/audio pack.
- Частичный настоящий Play Solo подтвердил LocalPlayer, camera/UI, «Мой стиль»,
  Results и возврат в хаб. Нужно завершить физические input paths, затем Server &
  Clients минимум с четырьмя игроками, late join, reconnect, party encore и Capture.
- Нужны screenshot matrix и MicroProfiler/Render Stats на выбранном low-end Android,
  iOS, desktop и gamepad; автоматический part budget не заменяет frame-time/memory.
- Commerce остаётся выключенным до реальных SKU, PolicyService, receipt/reconnect,
  duplicate delivery и refund проверки.
- Retention и высокий онлайн нельзя гарантировать локальной сборкой. После закрытого
  запуска решения принимаются по bounce, D1/D7, play days, completion и co-play.

## Следующий data-driven цикл

1. Провести 10–20 первых сессий без подсказок разработчика.
2. Найти первый массовый drop-off в onboarding/round/City Pulse funnel.
3. Закрыть 4-client и device profile, не меняя одновременно несколько переменных.
4. Импортировать production assets модульными kits с owner/license/fallback и
   повторять memory/render budget после каждого набора.
5. Только затем тестировать один holdout-эксперимент формулировки первой цели или
   длины выбора маршрута.
