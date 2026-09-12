# Runbook AURA RUSH

## Перед любым release candidate

```powershell
powershell -ExecutionPolicy Bypass -File tests/check-project.ps1
powershell -ExecutionPolicy Bypass -File tests/verify-repository-contracts.ps1
powershell -ExecutionPolicy Bypass -File tests/run-studio-smoke.ps1
```

Сохраните `studio-smoke.log` вместе с hash build. Если любой шаг красный, не
переходите к публикации и не заменяйте ошибку повторными кликами.

## Private test sequence

1. Откройте `AuraRush.rbxlx` в Studio и выполните `Play Solo`.
2. Проверьте loading shell и переход в UI; затем normal и skip варианты First
   Miracle, один полный раунд и clean stop.
3. Используйте Studio `Server & Clients` минимум с четырьмя клиентами.
4. Проверьте обычного игрока и каждую staff-роль согласно
   [ADMIN_OPERATIONS](ADMIN_OPERATIONS.md).
5. Зафиксируйте build hash, список сценариев, Output, profiler evidence и
   screenshots. Слово PASS без артефакта не закрывает gate.

## Серый экран или вход без UI

1. Не удаляйте Roblox и не публикуйте новую версию сразу. Сначала сохраните
   время, версию Player/Studio, place build hash и свежий client log.
2. В Studio проверьте наличие `ReplicatedFirst/AuraRushLoading`. После join
   посмотрите `PlayerGui` attributes: `AuraRushBootState` и
   `AuraRushBootDurationMs`.
3. В server Output проверьте `ReplicatedStorage/AuraRushRuntimeState`:
   `ServerState`, `ServerStep`, `ServerDetail`, `ServerFailureCode` и
   `CleanupFailureCount`.
4. Если `AuraRushBootState = failed`, зафиксируйте traceback client bootstrap.
   Если server state не `server_ready`, начинайте с server failure code. Если оба
   состояния healthy, сравните Player install/network/GPU logs — это может быть
   внешняя проблема клиента, а не place.
5. Воспроизведите на чистом актуальном Player и отдельно в Studio Play Solo.
   Только повторяемый project-side сбой должен вести к коду.

## Persistence warning

1. В OPS посмотрите failures, retries и budget waits; не компенсируйте игрока
   вручную из UI.
2. Проверьте `read-only` profile state и DataStore API configuration private
   universe.
3. Используйте существующий idempotency key при повторе награды/receipt. Никогда
   не добавляйте вторую валютную мутацию «на всякий случай».
4. Снимите `studio-smoke.log` и server Output, затем откройте incident с build
   hash и минимальным reproducer.

## Controlled publish

Перед публикацией нужны явное разрешение владельца, закрытые ручные gates,
лицензированные asset IDs и отдельно проверенные commerce IDs. После publish:

1. Сначала private server smoke под владельцем и обычным игроком.
2. Проверьте DataStore, OPS и одну read-only/temporary failure ветку.
3. Включайте feature flags поэтапно; нельзя одновременно менять карту, экономику
   и onboarding.
4. При проблеме отключайте только заранее существующий безопасный flag, фиксируйте
   evidence и не удаляйте player data.
