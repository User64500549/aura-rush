# UPGRADE HISTORY

## 2026-09-04 — Cycle 1: Instant Arrival

**Problem:** до `StarterPlayerScripts` не существовало собственного кадра; медленная
репликация или client bootstrap error могли выглядеть как серый/пустой экран.

**Change:** добавлен self-contained `ReplicatedFirst/AuraRushLoading`, premium
Russian-first arrival card, indeterminate progress, reduced-motion path, 12/30 s
degraded copy и handoff по `AuraRushBootState`. Client bootstrap обёрнут в `xpcall`
и сообщает `client_starting → ready/failed`.

**Expected result:** игрок всегда видит понятное состояние до основного App, а
ошибка не маскируется под пустой кадр.

**Risk:** загрузочная оболочка могла закрыть основной UI или зависнуть.

**Verification:** `loading-shell-smoke` — 18 checks; отдельный LocalScript в
ReplicatedFirst; нет `rbxassetid://`, `RenderStepped` или скрытой зависимости;
полный regression PASS. Решение соответствует официальной роли
[ReplicatedFirst](https://create.roblox.com/docs/scripting/locations) и правилу
[RemoveDefaultLoadingScreen](https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst/RemoveDefaultLoadingScreen).

## 2026-09-04 — Cycle 2: Repeatable Capture

**Problem:** `TakeScreenshot()` отключал `ProximityPromptService.PromptTriggered`
при первом снимке; `Destroy()` при этом оставлял listener, если снимок не делался.

**Change:** постоянные соединения больше не трогаются в operation path и очищаются
только в lifecycle destroy.

**Expected result:** игрок может использовать несколько фотозон/снимков за сессию,
а respawn/reload не оставляет утечку listener.

**Risk:** callback предыдущего capture мог пережить controller destroy; существующий
`OperationId` и `Destroyed` guard оставлены и проверены.

**Verification:** `client-lifecycle-smoke` — 6 checks; полный regression PASS.

## 2026-09-04 — Cycle 3: Secret Frames v7

**Problem:** exploration и «покажи другу» слой был заявлен в design docs, но реально
отсутствовал.

**Change:** по одной скрытой световой рамке у ворот каждого из шести районов;
постоянная коллекция, 35 Искр + 15 Camera XP за первый кадр, 120 Искр за комплект,
shared reveal, Creator Hub progress, low-cardinality analytics и runtime kill switch.
Награда выдаётся сервером атомарно через существующий system ledger; distance,
prompt identity, loaded profile и cooldown проверяются повторно.

**Expected result:** ожидание между раундами получает понятную exploration-цель,
карта создаёт редкие социальные открытия, а unlock меняет долгосрочную цель без новой
валюты или FOMO.

**Risk:** спам prompt, повторная награда, активация через стену/с расстояния, visual
clutter и mobile overdraw.

**Verification:** 133 Secret Frames checks, включая far/repeat/collection/kill-switch;
Premium City regression: hub 402/480 parts, 62/72 alpha, lights 23/24; 12/12 suites
PASS.

## 2026-09-04 — Cycle 4: Startup observability

**Problem:** performance audit правильно называл полную сборку `WorldService`
риском, но bootstrap не собирал для неё отдельную метрику.

**Change:** `WorldService.Build` выполняется через
`PerformanceService.Measure("ServerBoot.WorldBuild", ...)` без нового loop,
remote или изменения gameplay.

**Expected result:** private/live profile сможет отделить world-build stall от
загрузки данных и client failure.

**Risk:** instrumentation мог изменить return value или выпасть при
рефакторинге bootstrap.

**Verification:** structural suite проверяет call site, return path, world
attribute и server-log surface; 161 checks, 12/12 Studio suites PASS. Числовой
baseline честно остаётся private-server gate.
