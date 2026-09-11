# AURA RUSH — анализ игры

Дата аудита: 2026-09-04. Анализ относится к локальной сборке; он не является
доказательством поведения опубликованной аудитории.

## Карта систем

```text
ReplicatedFirst
  AuraRushLoading → client bootstrap state: starting / ready / failed

Client
  App + StyleOS/Theme
  Round / Input / Style / Camera / Audio / VFX / Capture / Remix / Meta / FirstMiracle
                         │ validated intents + snapshots
Shared                   │
  Config / Types / Remotes / Localization / catalogs / art & liveops manifests
                         │
Server
  Remote + Flags + Performance + ProductionAssets + Party
  World ─ CityPulse ─ SecretFrames
  Data ─ Economy ─ Progression ─ Quest ─ LiveOps ─ CommunityBloom
  RunDirector ─ Challenge ─ Round ─ RemixCity ─ Reward
  Style ─ SocialCreation ─ Celebration ─ Purchase ─ Meta ─ Analytics
```

Авторитет сервера сохранён для валюты, XP, ownership, прогресса испытаний,
Guardians, Secret Frames, наград и сохранения. Клиент отвечает за ввод и
presentation. Контракт остаётся client v6 / profile schema v5 / 32 remotes;
Secret Frames используют серверный `ProximityPrompt.Triggered`, поэтому новый
сетевой endpoint не понадобился.

## Игровая модель

- **Жанр:** кооперативный fashion/action party raid с meta-progression.
- **Core fantasy:** команда авторов меняет город своим образом и действиями.
- **Core loop:** тема → маршрут → три action cells → Mix Lab → Guardian → Bloom →
  Results.
- **Meta loop:** Искры/Aura Atlas → визуальные unlocks → Lookbook/replay/season →
  новый билд.
- **Social loop:** роли, City Pulse, общий Guardian, номинации, Postcards, Atelier,
  encore.
- **Retention loop:** ежедневные/недельные цели, Season 1, Community Bloom,
  коллекции и anti-repeat Run Director.
- **Content loop:** 192 брифа, 18 encounter cells, шесть миров, routes/modifiers,
  Chemistry, Guardians и шесть постоянных Secret Frames.
- **Economy loop:** одна мягкая валюта на косметические траты + отдельное мастерство
  школ; commerce остаётся безопасно выключенным.

## Десять крупнейших проблем/возможностей исходного аудита

| # | Наблюдение | Ценность / стоимость | Текущий статус |
|---:|---|---|---|
| 1 | До основного UI не было `ReplicatedFirst`; ошибка могла выглядеть как пустой/серый вход | очень высокая / низкая | исправлено: независимая boot shell + ready/failed contract |
| 2 | `CaptureController` после первого снимка удалял постоянный listener фотозон и не чистил его при destroy | высокая / очень низкая | исправлено и закреплено lifecycle smoke |
| 3 | Заявленные Secret Frames отсутствовали; exploration не имел постоянной коллекционной цели | высокая / средняя | реализовано: 6 секретов, reward/XP/Hub progress |
| 4 | Реальный Roblox Player на машине запускался из двух разных install roots; журнал фиксировал CDN DNS failures | блокирует проверку / внешняя | открыто; это не дефект place-кода |
| 5 | Нет доказательного 4-client, reconnect, late-join и real-device прогона текущей сборки | очень высокая / средняя | главный текущий gate |
| 6 | Procedural fallback целостный, но нет финального лицензированного mesh/material/audio pack | высокая / высокая | открыто; импортировать по одному modular kit |
| 7 | Нет живого funnel/retention baseline; fun и D1/D7 нельзя вывести из smoke-тестов | очень высокая / средняя | открыть после закрытого запуска |
| 8 | Весь мир из 1140 parts строится синхронно на server boot | средняя / средняя | измерить на server profile до оптимизации |
| 9 | `WorldService` и `App` крупные монолиты; изменение карты/UI имеет высокий regression radius | средняя / высокая | поэтапно разделять только вдоль доказанных изменений |
| 10 | Commerce catalog существует, но реальные SKU/policy/receipt device flow не настроены | средняя / средняя | корректно safe-off; не включать до gate |

## Scorecard после трёх циклов

Оценка — инструмент приоритизации, не маркетинговое обещание.

| Направление | /100 | Направление | /100 |
|---|---:|---|---:|
| First 30 Seconds | 78 | First 5 Minutes | 77 |
| Core Gameplay | 74 | Controls | 72 |
| Game Feel | 75 | Replayability | 83 |
| Progression | 79 | Long-Term Progression | 72 |
| Economy | 76 | Reward Quality | 78 |
| Content Variety | 85 | Player Agency | 78 |
| Social Gameplay | 76 | Multiplayer | 72 |
| Competition | 55 | Cooperation | 80 |
| Discovery | 84 | Surprise | 81 |
| Emotional Moments | 78 | World / Atmosphere | 83 |
| UI | 81 | UX | 79 |
| Visual Cohesion | 82 | Animation | 62 |
| VFX | 77 | Audio Feedback | 65 |
| Accessibility | 84 | Mobile Experience | 70 |
| Gamepad Experience | 69 | Loading | 82 |
| Client Performance | 71 | Server Performance | 73 |
| Networking | 85 | Reliability | 83 |
| Security | 89 | Anti-Exploit Architecture | 89 |
| Maintainability | 73 | Scalability | 75 |
| Analytics | 83 | LiveOps Potential | 84 |
| Monetization Fairness | 92 | Retention Potential | 77 |
| Viral Potential | 73 | Overall Polish | 79 |

Главное ограничение scorecard: visual/device/multiplayer оценки основаны на коде,
структурных budget-тестах и предыдущем Play Solo, но не на текущей полной матрице
физических устройств. Поэтому они намеренно не приближены к 100.

## Следующий bottleneck

Самая ценная следующая работа — доказательный запуск текущего build в Studio Play
Solo, затем Server & Clients ×4 и на реальном low-end mobile. Нужно проверить не
«наличие» систем, а понятность первых 30 секунд, достижимость всех шести рамок,
качество общего reveal, touch/gamepad prompts, повторный снимок и возврат камеры.
