# Performance report — release candidate

## Статус

В коде есть performance budgets, серверный sampler и клиентские degradation paths.
В репозитории нет достоверного device profile с real hardware, поэтому численные
FPS/memory/hitch результаты не заявляются как пройденные. Финальное profiling —
открытый release gate.

## Budgets из Config

| Метрика | Budget |
|---|---:|
| Target low/mobile FPS | 30 FPS |
| Target desktop FPS | 60 FPS |
| Server script work | ≤ 8 ms для измеряемого critical slice |
| World Bloom hitch | ≤ 100 ms |
| Memory growth за 5 раундов | ≤ 30 MB |
| Quality sample interval | 2 s |
| Quality recovery | 20 s |
| Viewport preview target | ≤ 150 ms |

Это acceptance targets, а не автоматически доказанные результаты.

## Автоматически проверяемый world budget v7

| Метрика | Текущая сборка | Лимит |
|---|---:|---:|
| Hub BasePart | 402 | 480 |
| Все world BasePart | 1140 | 2600 |
| Все `Light` | 23 | 24 |
| Hub layered transparency (`0 < T < 1`) | 62 | 72 |
| Максимум layered transparency в streamed-зоне | 85 (`PrismMetro`) | 100 |
| Всего layered transparency | 293 | 320 |
| City Pulse replicated world/UI updates | coalesced | 12/с |

Все world lights в smoke имеют `Shadows=false`. Fully invisible anchors и trigger
volumes не считаются alpha-overdraw; glass/частичная прозрачность считаются. Эти
счётчики не измеряют экранную площадь, draw calls, particles или texture memory,
поэтому device pass остаётся обязательным.

## Реализованные меры

- `StreamingEnabled` с reduced target/initial radii для более ранней загрузки на mobile.
- Predictive streaming, opportunistic stream-out, integrity pause и SLIM записаны
  как enum tokens в canonical build. Локальная Studio без этих members использует
  проверяемый fallback; server Luau не пытается писать NotScriptable properties.
- Procedural world строится один раз и переключает visibility/phase state вместо
  постоянного clone больших сцен.
- Server `PerformanceService` хранит ограниченное окно heartbeat samples и p50/p95
  измерений labeled sections. Тяжёлая процедурная сборка мира теперь измеряется
  под отдельной меткой `ServerBoot.WorldBuild`.
- Client VFX использует object pool и quality tiers `Minimal/Low/Balanced/High`.
- Reduced motion, low VFX и no flashes принудительно выбирают минимальный visual path.
- Bloom sequence использует cancellation token, чтобы delayed callbacks старой фазы
  не продолжали создавать эффекты.
- Viewport avatar clone удаляет scripts, tools, sounds, particles, trails, beams и
  highlights; refresh debounce ограничивает churn.
- Modular audio graph создаётся capability-safe; fallback не блокирует startup.
- Data ledgers/profile arrays имеют caps; autosave не запускает unbounded history.
- Community global writes batch-ятся и flush-ятся примерно раз в 20 секунд.

## Риски, требующие измерения

- Полная процедурная сборка WorldService при server boot: instrumentation есть,
  но baseline ещё не снят на целевом private server/device.
- Шесть Finale models и hero landmarks под StreamingEnabled.
- World Bloom property tweens и camera/VFX fan-out на 12 клиентов.
- Character clone/appearance accessories в MixLab ViewportFrame на R15.
- MemoryStore/Messaging retries и shutdown flush при нагрузке.
- UI reflow на portrait phone при large text/high contrast.
- Будущие external textures, meshes, SurfaceAppearance и audio stems — их footprint
  сейчас не представлен и может изменить все показатели.

## Обязательный профиль

### Server

1. Запустить private Studio Server & Clients с 4, затем 12 clients.
2. Записать boot world-build time, heartbeat p50/p95 и каждый state transition.
3. Пройти пять раундов без restart; сравнить Lua heap/Instances/connections до и после.
4. Симулировать leave/late join/requeue и Community flush.
5. Проверить отсутствие накопления delayed bloom/VFX callbacks.

### Client

1. Low-end Android target, iOS target, 1280×720 desktop, 1920×1080 desktop, gamepad.
2. Отдельно profile Hub, каждый challenge, MixLab preview и Finale.
3. Сравнить default, low VFX, reduced motion, no flashes и large text.
4. Измерить P50/P95 frame time, memory, network receive, preview refresh и Bloom hitch.
5. Повторить после подключения production asset manifest.

## Pass criteria

- Средний FPS достигает target, а P95 frame time не создаёт длительных stalls.
- Bloom hitch ≤ 100 ms на заявленном mobile target.
- Memory growth за пять одинаковых раундов ≤ 30 MB и стабилизируется.
- Нет unbounded Instance/connection/task growth.
- Late join snapshot/teleport не создаёт видимого многосекундного freeze.
- Minimal quality сохраняет gameplay signals и captions.

До сохранения raw profiler captures, device/build identifiers и результатов в
release evidence этот документ остаётся планом/аудитом реализации, не сертификатом.

Точный build hash и время последнего evidence run хранятся в
[`UPGRADE_STATE.md`](UPGRADE_STATE.md). Studio runtime PASS — это structural/runtime
evidence, а не физический performance certificate.
