# «Стиль-рейд» — карта реализованного апгрейда

## Что теперь обещает игра

Игрок заходит не в меню ради меню. За первые 30 секунд он выбирает цвет, выполняет
три коротких действия и видит, как его решение меняет сцену. Дальше команда выбирает
тему и маршрут, проходит три испытания, собирает образ в Гримерке и перекрашивает
район в трёх актах.

Тело и лицо аватара не оцениваются и не «улучшаются». Прогресс показывает вкус,
коллекцию, командную работу, движение, камеру и сценографию.

## Реализованные слои

| Слой | Реализация |
|---|---|
| Русский продукт | RU default, 283 keys, 70 предметов, безопасные fallback без raw ID |
| UX | editorial tokens, понятные CTA, адаптивная компоновка, вкладки Профиля |
| Accessibility | системные reduced motion / text size / transparency + локальные настройки |
| Мир | 6 районов, отдельные silhouette/material rules, RU wayfinding, landmarks |
| Перекраска | 3 стадии, authored target colors/materials, palette команды |
| Камера | 6/6 anchors, prefetch, world profiles, reduced-motion-safe shots |
| VFX | 6 мотивов, pool, FPS/viewport quality tiers, no-flash fallback |
| Аудио | modular fader/compressor/EQ/reverb, world motifs, legacy fallback |
| Gameplay | 3 маршрута, 4 физических модификатора, 6 испытаний, server authority |
| Retention | Район недели, задания, Лукбук, карточки, Команда, Общий район |
| Monetization | только косметика, точный состав, explicit click, commerce safe-off |

## Статус сборки 02.09.2026

- `tests/check-project.ps1`: PASS, 0 ошибок, 0 предупреждений, 0 parse errors.
- Все восемь Studio RunScript-контрактов: PASS, включая economy/liveops/social,
  Living City v4 и Remix City v5; structural smoke — 138 проверок.
- Предыдущая сборка опубликована в приватный стартовый плейс `71732197502515`
  (universe `10752715330`). Текущая v5.1 собрана локально и этим pass не публиковалась.
- По подтверждению владельца анкета контента заполнена. Публичная доступность и
  публикация текущей v4 остаются отдельными действиями в Creator Dashboard.

## Честные внешние gates

- PNG из `assets/brand/` нужно загрузить в Creator Dashboard и дождаться модерации;
  код не содержит выдуманных Roblox asset ID.
- Для доступности игрокам нужно отдельно опубликовать v4 и проверить access/privacy
  стартового плейса; этот implementation pass настройки публикации не менял.
- Финальные MeshPart/PBR textures и музыкальные stems требуют подтверждённых ID,
  владельца и лицензии. Процедурный мир остаётся полноценным безопасным fallback.
- Product/pass/subscription ID не заполнены, поэтому Robux prompts намеренно выключены.
- Headless smoke не заменяет визуальный Play Solo, тест четырёх клиентов и профилирование
  на реальном слабом телефоне.

## Definition of Done для публикации

1. `tests/check-project.ps1` проходит полностью.
2. Восемь Studio RunScript marker проходят без assertion/ложноположительного source match.
3. Play Solo: Первый выход, тема/маршрут, три испытания, Гримерка, Перекраска, результат.
4. Server & Clients ×4: late join, reconnect, requeue, карточка и вклад в Район недели.
5. Phone/tablet/desktop/gamepad: текст не обрезается, CTA доступны, смысл не зависит от цвета.
6. Пять последовательных финалов: нет утечки памяти и заметного hitch сверх бюджета.
7. Только после этого отдельно включаются подтверждённые commerce flags.
