# QA-чеклист release candidate

Расширенная матрица и критерии выхода: [QA_MATRIX.md](QA_MATRIX.md).

## Автоматический smoke

- `stylua --check src tests` без diff.
- `selene src tests` без errors/warnings.
- `rojo build default.project.json -o AuraRush.rbxlx` успешен.
- 12 headless Studio `RunScript` smoke проходят независимо: structural
  `AURA_RUSH_SMOKE_PASS (161 checks)`, loading shell, client lifecycle, gameplay
  director, First Miracle, localization, presentation, economy/liveops/social,
  Living City v4, Remix City v5, Premium City v6 compatibility и Secret Frames v7.
- Structural contract: client/schema v6/v5, 192 брифа, шесть art profiles,
  6 Secret Frames, 32 remotes и все процедурные сцены. Director smoke подтверждает 18 432
  theoretical / 1 536 empirical signatures.

Headless `RunScript` не создаёт интерактивный LocalPlayer и не заменяет ручной
Studio `Play Solo`.

## Вход в игру

- `ReplicatedFirst` создаёт loading shell до клиентского App и не требует remote assets.
- Default loading screen удаляется только после mount брендированного shell.
- Bootstrap передаёт `ready` или `failed`; при долгом старте есть отдельный текст.
- Server bootstrap замеряет `ServerBoot.WorldBuild`; число нужно снять в live/private server.

## Первый опыт

- Allowlist palette → три spatial actions с серверной проверкой → персональный Bloom
  не позднее 30 секунд.
- Первое движение ещё до закрытия приветствия даёт pooled client-local след;
  маршрутные плиты отвечают усиленным сигналом.
- Timeout, skip и reconnect сходятся в безопасное завершение.
- Награда ровно один раз: 100 GlowDust, 80 Motion Aura Atlas XP и
  `aura_first_miracle`, которая открывается и экипируется.
- Runtime `FirstMiracle` kill-switch и read-only Studio flow не оставляют UI висеть.

## Один полный раунд

- Сервер проходит весь state machine и восстанавливается после ошибки в Cleanup.
- Выбираются три валидных брифа; route vote принимает только серверную option.
- Run Director выдаёт три соединённых encounter cells, потребляет semantic brief в
  18 mechanic verbs и не повторяет недавнюю signature без необходимости.
- Thread Run / Material Surf, Beat Lab / Light Loom, Prism Puzzle / Bloom Rescue
  принимают только валидный input текущей фазы.
- Mix Lab не экипирует locked item; `ViewportFrame` не содержит исполняемых scripts.
- Aura Genome строится из фактических loadout участников.
- World Bloom запускает recipe v4, применяет пять style axes/route/performance,
  проходит три визуальных акта и возвращает
  камеру из `Scriptable`.
- Повторная выдача того же `roundId` не дублирует валюту, XP, quest или live-ops.

## Multiplayer

- Late join в разрешённой фазе становится `BackstageApprentice`, если осталось не
  меньше 12 секунд; participation ratio и базовые rewards/XP снижены.
- Игрок, вышедший из сервера, не блокирует team completion.
- Requeue учитывает только текущих участников.
- Party snapshot деградирует безопасно, если Party API недоступен.
- Invite prompt вызывается только после кнопки и не повторяется spam-кликом.
- Atelier invite требует роль, принимает только online target, имеет TTL/cooldown,
  повторную проверку accept и decline/block flow.

## Secret Frames

- Каталог содержит ровно шесть уникальных русских названий/намёков, по
  одному на район; нет product ID и time gate.
- Server-owned prompt проверяет дистанцию, cooldown, catalog ID и feature flag.
- Первая находка, повтор, рассинхронизация ledger и полная коллекция проверены.
- Runtime kill switch отключает prompts; `Destroy` снимает все connections.
- Визуальная достижимость всех точек, touch/gamepad prompt и reveal — ручной gate.

## Persistence и social

- v1–v4 fixture мигрируются в v5 без wipe currency/unlocks/loadout.
- `photoModeUnlocks` нормализуется, дедуплицируется и ограничивается конфигом.
- Saved legacy look преобразуется в modern record; лимиты ledgers соблюдаются.
- Lookbook save/delete/equip проверяет ownership и read-only.
- Postcard создаётся один раз на раунд; self-reaction/unknown reaction отвергается;
  remix не выдаёт отсутствующие items.
- Replay сохраняется только после consent, не содержит user ID, ограничен 24
  событиями/8 записями и воспроизводится только владельцу.
- Season claim проверяет XP, catalog item и повторную выдачу на сервере.
- Idle run не получает награду и не двигает quests/community/atelier; Community
  contribution и milestone claim идемпотентны.
- Одновременный вход не перезаписывает активную session lease.

## Accessibility и устройства

- Desktop 1280×720/1920×1080, phone portrait/landscape, tablet, gamepad.
- Touch targets не меньше 48 px и имеют достаточный spacing.
- Reduced motion, low VFX и no flashes реально уменьшают camera/VFX sequence.
- High contrast, large text, captions и volume sliders сохраняются после reconnect.
- R6/R15 preview и world character не меняют body proportions.

## Commerce

- ID `0` / `""` и выключенные flags не позволяют открыть purchase prompt.
- Duplicate receipt выдаёт entitlement один раз.
- Save failure и read-only возвращают `NotProcessedYet`.
- Glowstorm token списывается только при успешном запуске; при ошибке возвращается.
- Signature collection выдаёт точный список и не содержит mastery items.

## Обязательные release gates

- Финальные Roblox asset IDs и лицензии external art/audio.
- Опубликованные SKU и ручная проверка всех benefits.
- Отдельный ручной `Play Solo`: First Miracle, Creator Hub, server/client Output,
  полный раунд, все Secret Frames, Capture до и после первого снимка и clean Stop.
- Studio `Server & Clients` минимум с четырьмя клиентами.
- Профилирование на реальных low-end mobile и целевом desktop.
