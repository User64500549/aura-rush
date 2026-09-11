# Контент и удержание

## Основная фантазия

Игрок развивает узнаваемый визуальный почерк, а не «идеальное тело». Пять осей
образа — palette, material, aura, pose и accent — становятся `Aura Genome`; общий
геном команды задаёт цвет, материал, ауру, маршрут и трёхактный World Bloom.

## Брифы и миры

`BriefCatalog` комбинирует четыре совместимые оси:

- 6 миров: Prism Metro, Cloud Bazaar, Moonlit Greenhouse, Orbital Boardwalk,
  Velvet Archive, Solar Cathedral;
- 4 повода: rescue rehearsal, midnight festival, mystery premiere, friendship parade;
- 4 эстетики: retro future, soft gothic, bioluminescent, toybox editorial;
- 2 твиста: zero gravity, color eclipse.

Итого: `6 × 4 × 4 × 2 = 192` безопасных сочетания. Для каждого мира есть art
profile, Finale spawn, World Bloom model и camera anchor.

## Вариативность забега

Adaptive Run Director выбирает по одному испытанию из каждой пары:

1. Thread Run или Material Surf — сбор и движение.
2. Beat Lab или Light Loom — ритм и совместный паттерн.
3. Prism Puzzle или Bloom Rescue — память/последовательность и восстановление мира.

Две route options (`kinetic`, `precision` или mixed-направление) и один modifier
влияют на подбор актов. Последние signatures получают штраф, а одинаковый seed и
history дают воспроизводимый результат. Это контентная вариативность, а не
бесконечно генерируемые вручную обещания: новые сцены всё равно требуют QA.

## Метапетли

- Creative Rank 1–100 — общий показатель опыта.
- Aura Atlas: Color, Texture, Motion, Camera, SetDesign, уровень 1–20.
- Mastery items открываются автоматически и детерминированно при достижении уровня.
- Три daily quest, четыре weekly quest, один free daily reroll, банк незавершённых
  daily до пяти дней и мягкий grace streak.
- Lookbook хранит до 20 именованных образов; названия фильтруются сервером.
- Postcard создаётся участником только в Finale/Results, максимум одна на раунд и
  24 в профиле; рецепт состоит только из catalog IDs.
- Remix применяет только предметы, которые уже принадлежат игроку, а реакции
  ограничены позитивным allowlist и запрещают self-reaction.
- Atelier — лёгкая persist-связь Founder/Member с приглашениями только между
  игроками текущего сервера; это не полноценная guild-модерация.
- Community Canvas начисляет 10 contribution за завершённый раунд, ограничивает
  личный дневной вклад и открывает заранее объявленные milestones.

## Контент-пайплайн

1. Добавьте постоянный ID в соответствующий shared-каталог.
2. Не меняйте существующий ID после релиза; для rename используйте migration map.
3. Для mastery задайте school/category и известный required level.
4. Для платного bundle перечислите детерминированный список косметики; mastery item
   нельзя включать в покупаемый комплект.
5. Добавьте visual preset в `StyleService` и preview-совместимость.
6. Проверьте R6/R15, no-flashes, reduced-motion, low-VFX и contrast.
7. Для нового мира добавьте art profile, spawn, Bloom model, hero landmark и camera.

Случайных loot boxes, скрытых шансов, body-rating и power boosts в дизайне нет.
