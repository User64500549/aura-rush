# Living City v4 — реализованный upgrade

Срез: 24 августа 2026. Это описание текущего кода, а не список желаний.

## Что изменилось для игрока

- Русский `Style OS` заменяет сырой набор панелей: единые токены, визуальные плитки
  предметов, короткая микрокопия, крупные зоны нажатия, safe-area, адаптивная сетка,
  gamepad focus и настройки доступности.
- Маршрут теперь физически читается в мире. Run Director строит отдельную
  `ActiveRunGeometry`, меняет точки появления и показывает cascade,
  precision-grid либо split-remix рисунок выбранной ветки.
- Occasion, aesthetic и twist брифа резолвятся в серверный `mechanicProfile`.
  Каталог содержит 12 реально реализованных mechanic verbs, включая ordered и
  discovery routes, inertia flow, relay, festival combo, weave, shared repair и
  eclipse decode.
- «Первый выход» перестал быть модальной анкетой: три коротких пространственных
  шага проходят непосредственно в мире. Сервер проверяет Humanoid/HRP и не
  принимает заявленную клиентом позицию как доказательство.
- Финал использует `Bloom Recipe v4`. Пять осей экипировки, маршрут и performance
  выбирают palette stops, материал, VFX-мотив, pulse/emission, camera preset,
  landmark preset и интенсивность трёх актов Bloom.
- Glowstorm создаётся локально на каждом клиенте. Сервер реплицирует только
  безопасный marker; reduced motion, no flashes и low VFX применяются персонально.

## Технологический слой

- `StyleSheet`, `StyleRule`, `StyleLink` и `StyleQuery` включаются capability-safe:
  если конкретный клиент или флаг их не поддерживает, ручная тема и layout остаются
  полностью рабочими.
- Input Action System разделяет контексты Beat Lab и Prism Puzzle; старый
  `ContextActionService` автоматически используется как fallback.
- Predictive streaming включён только стабильным feature flag. Экспериментальные
  mesh streaming, acoustics, recommender и rewarded video намеренно выключены.
- Modular Audio читает финальный recipe и меняет EQ/reverb/pulse; отсутствие
  production asset ID не ломает базовый `Sound` fallback.

## Economy, LiveOps и social safety

- Награда за раунд требует квалифицированного участия; idle run не двигает валюту,
  progression, quests, Community Bloom или Atelier. Late join сохраняет доступную
  компенсацию Backstage Apprentice.
- Daily bank больше не умножает одно действие на несколько заданий; streak хранит
  отдельно текущий momentum и lifetime days.
- LiveOps manifest v2 валидируется строго и fail-closed. Personal/global milestone
  scope разделён явно.
- Atelier имеет role checks, TTL, cooldown, accept revalidation, decline и session
  block. Публичные postcards не раскрывают round ID и ID других участников.
- Paid receipts имеют durable archive/compaction и fail-closed поведение при
  конфликте или outage. Commerce остаётся выключенным, пока ID равны `0`/`""`.

## Production assets

`ProductionAssetManifest.lua` содержит 66 явных слотов для шести районов:
mesh kits, surface families и audio stems. Пустой ID не маскируется тестовым ID —
runtime использует `procedural_v4` fallback.

Новые локальные source assets:

- `assets/brand/style-raid-key-art-v2.png`;
- `assets/brand/style-raid-icon-v2.png`.

Их нужно загрузить через Creator Dashboard и записать реальные owner/license/ID
перед production release. Локальный PNG-путь сам по себе не является Roblox asset.

## Rollout

Включены: `ChallengeFramework2`, `BloomComposer2`, `SpatialFirstMiracle`,
`LivingCity`, `StyleOS`, `PredictiveStreaming`.

Выключены до отдельной интеграции и проверки: `RecommendationService`,
`ExperimentalMeshStreaming`, `ExperimentalAcoustics`, `RewardedVideo`, вся commerce
группа.

## Автоматическая проверка

```powershell
powershell -ExecutionPolicy Bypass -File tests/check-project.ps1
powershell -ExecutionPolicy Bypass -File tests/run-studio-smoke.ps1
```

Текущий результат: Selene 0/0, Rojo build PASS, 128 structural checks, 18 432
theoretical / 1 536 empirical gameplay signatures, отдельные PASS для gameplay,
First Miracle, localization, presentation, economy/liveops/social и Living City v4.

Studio `RunScript` не создаёт настоящий LocalPlayer. Перед production всё ещё нужны
ручной Play Solo, четыре клиента, профилирование на целевых телефонах, реальные
licensed asset/audio IDs и published-universe commerce sandbox.
