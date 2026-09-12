# Evidence для релиза

Этот файл разделяет доказанные локальные контракты от того, что ещё требует
живого Roblox-теста. PASS одного слоя не заменяет другой.

## Автоматические локальные gates

| Gate | Команда | Что подтверждает | Чего не подтверждает |
|---|---|---|---|
| Static/build | `tests/check-project.ps1` | Stylua, Selene, Rojo и актуальный `AuraRush.rbxlx` | Player join, визуальный UX, FPS |
| Studio suites | `tests/run-studio-smoke.ps1` | 17 изолированных `RunScript` контрактов | Интерактивный `Play Solo`, touch, gamepad, 4 клиента |
| Repository contracts | `tests/verify-repository-contracts.ps1` | Canonical remotes, deny-by-default OPS, durable-store guard, документы и список suites | Runtime Roblox API |
| GitHub Actions | `Repository contracts` | Запуск repository-contract gate на push/PR | Studio binary и реальную сессию |

Последний полный локальный прогон и SHA-256 записываются в `studio-smoke.log`.
Нельзя переносить цифры из старого лога в новый release note: build должен
совпадать с текущим `AuraRush.rbxlx`.

## Последнее полное локальное evidence

- UTC: `2026-09-12T15:37:34.8248266Z`
- Build: `AuraRush.rbxlx`, 1,119,604 bytes
- SHA-256: `BB134CD516B81031D4C4452F1242CB433880A5094098A3678A56C9EAB80CF8DC`
- Результат: 17/17 isolated Studio `RunScript` suites PASS, без runtime failure.
- Дополнительно: static/build gate PASS и repository contract gate PASS (55 checks).

Это закрывает только automatic local gates. Manual/private/device gates ниже
сохраняют статус `OPEN`.

## Обязательные ручные gates до production

1. **Play Solo:** loading shell → First Miracle normal/skip → основной UI →
   полный раунд → Results → Cleanup; без красных client/server ошибок.
2. **Server & Clients ×4:** роли, City Pulse, late join, reconnect, общий Bloom,
   Secret Frame и повторная доставка награды.
3. **Device matrix:** low-end phone portrait/landscape, tablet, desktop и gamepad;
   проверить safe area, touch target, текст, reduced effects и FPS/memory.
4. **Persistence:** private published universe с разрешённым DataStore API;
   reconnect, transient failure, shutdown, receipt idempotency.
5. **Commerce:** только после реальных SKU и private receipt test. До этого
   значения `0`/пустые IDs и выключенные feature flags — корректный safe-off.
6. **Operations:** private owner/support/moderator/admin accounts, отсутствие OPS у
   игрока, audit privacy, два allowlisted announcements и cooldown.

## Release decision

Локальная сборка может считаться **кандидатом для закрытого теста** лишь после
зелёных трёх автоматических gates. Она не является production-ready, пока не
закрыты ручные gates выше. Отсутствующий evidence — это `OPEN`, а не «скорее
всего работает».

Подробная последовательность находится в [RUNBOOK](RUNBOOK.md), а риски — в
[RISK_REGISTER](RISK_REGISTER.md).
