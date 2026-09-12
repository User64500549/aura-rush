# AURA RUSH — анализ игры

Дата аудита: 2026-09-12. Анализ относится к локальной сборке и её contracts; он
не является доказательством поведения опубликованной аудитории.

## Карта систем

```text
ReplicatedFirst
  AuraRushLoading → client bootstrap state: starting / ready / failed

Client
  App + StyleOS/Theme + gameplay/camera/audio/VFX/meta controllers
  └─ AdminDashboardController (только после server authorization)
                              │ validated intents / snapshots
Shared                         │
  Config / Remotes v2 / Localization / catalogs / StaffPolicy / manifests
                              │
Server
  Remote + Flags + Performance + ProductionAssets + Party
  World ─ CityPulse ─ SecretFrames
  Data ─ Economy ─ Progression ─ Quest ─ LiveOps ─ CommunityBloom
  RunDirector ─ Challenge ─ Round ─ RemixCity ─ Reward
  Style ─ SocialCreation ─ Celebration ─ Purchase ─ Meta ─ Analytics
  AdminService ─ health / audit / approved announcements
```

Клиент отвечает за ввод и presentation. Сервер — за фазу, награды, валюту,
ownership, progression, community contribution, commerce и staff permissions.
Текущий контракт: client v6 / profile schema v5 / 35 remotes v2.

## Игровая модель

- **Жанр:** кооперативный fashion/action party raid с метапрогрессией.
- **Core fantasy:** команда авторов меняет город своим образом и действиями.
- **Core loop:** тема → маршрут → три action cells → Mix Lab → Guardian → Bloom → Results.
- **Meta loop:** Искры/Aura Atlas → visual unlocks → Lookbook/replay/season → новый билд.
- **Social loop:** роли, City Pulse, общий Guardian, nomination, Postcards, Atelier, encore.
- **Retention loop:** daily/weekly цели, Season 1, Community Bloom, коллекции,
  anti-repeat Run Director.
- **Content loop:** 192 briefs, 18 cells, 6 worlds, routes/modifiers, Chemistry,
  Guardians и Secret Frames.
- **Economy loop:** одна мягкая валюта и отдельное mastery; commerce safe-off.

## Десять главных проблем / возможностей

| # | Наблюдение | Expected value / cost | Статус |
|---:|---|---|---|
| 1 | Нет full physical proof current build на Player, 4 clients и devices | очень высокая / средняя | OPEN — главный bottleneck |
| 2 | Внешние DataStores могли по-разному переживать throttle/outage | высокая / низкая | улучшено shared guard + diagnostics; published proof OPEN |
| 3 | У владельца не было безопасной видимости health и аудита | высокая / средняя | реализован constrained OPS; role/device proof OPEN |
| 4 | Ранний вход мог выглядеть серым при external Player failure | очень высокая / низкая | loading shell/error state есть; clean Player proof OPEN |
| 5 | Синхронная сборка 1140 parts может бить по join | высокая / средняя | инструментирована; profile evidence OPEN |
| 6 | World/App имеют высокий regression radius | средняя / высокая | не переписывать без измеренной причины |
| 7 | Визуальный authored asset/audio pack не подключён | средняя / высокая | procedural fallback работает; art pass OPEN |
| 8 | Нет product baseline для onboarding/retention | очень высокая / средняя | analytics есть; first-session research OPEN |
| 9 | Commerce может повредить fairness без real SKU QA | высокая / средняя | safe-off сохранён |
| 10 | Документы и tests были рассинхронизированы с контрактом | высокая / низкая | обновлены + CI source gate |

## Scorecard

Оценка — инструмент выбора bottleneck, не маркетинговое обещание. Поля,
требующие живой device/multiplayer proof, намеренно не завышены.

| Направление | /100 | Направление | /100 |
|---|---:|---|---:|
| First 30 Seconds | 79 | First 5 Minutes | 77 |
| Core Gameplay | 74 | Controls | 72 |
| Game Feel | 75 | Replayability | 83 |
| Progression | 79 | Long-Term Progression | 72 |
| Economy | 79 | Reward Quality | 78 |
| Content Variety | 85 | Player Agency | 78 |
| Social Gameplay | 76 | Multiplayer | 72 |
| Competition | 55 | Cooperation | 80 |
| Discovery | 84 | Surprise | 81 |
| Emotional Moments | 78 | World / Atmosphere | 83 |
| UI | 82 | UX | 80 |
| Visual Cohesion | 82 | Animation | 62 |
| VFX | 77 | Audio Feedback | 65 |
| Accessibility | 84 | Mobile Experience | 70 |
| Gamepad Experience | 69 | Loading | 84 |
| Client Performance | 71 | Server Performance | 73 |
| Networking | 87 | Reliability | 87 |
| Security | 91 | Anti-Exploit Architecture | 91 |
| Maintainability | 78 | Scalability | 78 |
| Analytics | 84 | LiveOps Potential | 84 |
| Monetization Fairness | 92 | Retention Potential | 77 |
| Viral Potential | 73 | Overall Polish | 81 |

## Следующий bottleneck

Самая ценная следующая работа не новая система: доказательный запуск current build
по [RUNBOOK](RUNBOOK.md). Нужно проверить первые 30 секунд, boot state, touch/
gamepad, 4-client coordination, clean disconnect и persistence recovery. Только
после evidence выбирать один следующий product/visual upgrade по метрикам.
