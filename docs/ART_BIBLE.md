# AURA RUSH: СТИЛЬ-РЕЙД — art bible v6

Композиционный референс Premium City: `assets/brand/remix-city-premium-map-concept-v3.png`.
Он задаёт иерархию «arrival → Сердце стиля → кольцо шести районов», но не является
runtime-текстурой и не отменяет Roblox-specific performance budgets.

## Визуальный принцип

Стиль выражается не телом аватара, а умением собрать цвет, поверхность, движение,
позу и сценографию. Мир должен читать командный образ с дальнего плана, а UI —
оставаться редакторским, ясным и не перекрывать действие.

## Общие правила

- Сначала silhouette и value contrast, затем glow и частицы.
- Не более пяти material families на основную локацию; новые материалы обязаны
  принадлежать одной из заявленных семей.
- Emissive accents показывают gameplay state, а не заполняют весь кадр.
- Базовая палитра продукта: глубокие чернильные поверхности, молочный текст, acid
  lime, coral, cold blue и точечный chrome. Фиолетово-розовый градиент не является
  универсальным фоном.
- Пространство строится в три слоя: понятный игровой маршрут, узнаваемый landmark и
  дальний силуэт района. Ряды одинаковых Part не считаются законченной композицией.
- Bloom проходит три акта: `seed` (32%), `cascade` (68%), `bloom` (100%).
- Тело, лицо и proportions аватара не редактируются. Cosmetics — наружный visual layer.
- На low VFX смысл должен сохраняться через цвет, форму и движение крупных объектов.

## Шесть миров

| Мир | Color script | Material families | Silhouette | Sound motif |
|---|---|---|---|---|
| Prism Metro | `172039 / 38E8FF / FF6B8B / C6D4FF` | LiquidChrome, HolographicGlass, WetStone, CarbonTextile, PrismLight | diagonal, kinetic gates, long perspective | mechanical editorial breakbeat |
| Cloud Bazaar | `FFF7ED / FFC8DD / B8F2E6 / CDB4DB` | InflatedSilk, Porcelain, Pearl, CloudFoam, OpalGlass | soft arches, floating pavilions, round volumes | air bells / soft house |
| Moonlit Greenhouse | `071A17 / 0A9396 / 94D2BD / B58CFF` | WetObsidian, TranslucentLeaf, LuminousVein, MoonGlass, VelvetMoss | branches, petals, glass ribs | organic pulse / whispered leaves |
| Orbital Boardwalk | `0B0C2A / 9B5DE5 / FFD166 / F72585` | StarGlass, Lacquer, Carbon, FiberOptic, SolarMetal | orbits, festival ramps, wide rings | cosmic disco groove |
| Velvet Archive | `160B22 / 5A189A / E0AAFF / F3D9B1` | InkVelvet, SilkPaper, DarkBrass, BookGlass, StarlitThread | vaults, flying pages, spiral shelves | chamber strings / ink percussion |
| Solar Cathedral | `3A1D12 / FF9F1C / FFD166 / FFF4D6` | WarmGlass, SolarMirror, IvoryStone, GoldLeaf, LightFabric | sun arches, vertical rays, mirror fans | radiant choir / future garage |

Точные normal/bloom lighting numbers находятся в `ArtDirectionRegistry.lua` и
считаются canonical; art implementation должна их читать, а не дублировать.

## Challenge language

- Thread Run: натянутые линии, collectible knots, направляющая перспектива.
- Material Surf: широкая ribbon-wave, образцы поверхности, ощущение потока.
- Beat Lab: четыре явные lanes; момент ввода различим формой и caption, не только flash.
- Light Loom: те же четыре lanes превращаются в тканый световой паттерн.
- Prism Puzzle: четыре устойчивых color/shape states и читаемый reset.
- Bloom Rescue: повреждённые nodes визуально восстанавливаются по последовательности.
- Mix Lab: тёмная editor surface, крупный avatar preview, категории отдельно от items.

## UI

- Digital street-fashion editorial × music clip × city wayfinding; не generic glass UI.
- Один экран — одна главная задача и один primary CTA. Карточка обязана отвечать на
  вопросы «что происходит», «что нажать» и «что получу» без developer-терминов.
- Кириллица имеет приоритет; all-caps используется только для коротких навигационных
  меток, а не для абзацев или названий каждой сущности.
- Minimum touch target 48 px, минимум 8 px между соседними интерактивными targets.
- Safe areas и responsive reflow важнее фиксированной композиции.
- `ViewportFrame` показывает очищенный clone персонажа на нейтральной stage; drag и
  кнопки вращают preview, но не world character.
- Status не кодируется одним цветом: используйте icon/label/tone вместе.

## Accessibility art contract

- `reducedMotion`: короткие или статичные transitions, без длинной orbital camera.
- `lowVfx`: минимальный pool particles и крупные сигналы вместо мелкого шума.
- `noFlashes`: не использовать быстрый contrast pulse; bloom/camera intensity снижать.
- `highContrast`: непрозрачнее panels, белый primary text, яркие strokes.
- `largeText`: layout обязан reflow, а не обрезать строки.
- `captions`: rhythm, World Bloom и важные audio cues имеют текстовый эквивалент.

## External asset pipeline — release gate

Процедурные primitives — рабочий fallback, но не финальный art pack. Перед импортом
каждого внешнего asset записать: Roblox asset ID, owner, license/source, version,
fallback и measured memory. Запрещены непроверенные free models и assets со scripts.

Обязательный review: R6/R15, StreamingEnabled, collision/touch/query, LOD, texture
memory, mobile screenshots, no-flashes pass и World Bloom hitch. Пока manifest и
Roblox asset IDs не заполнены, production art/audio остаются открытым release gate.
