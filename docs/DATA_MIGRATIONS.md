# Data schema и миграции

## Канонический storage

Текущая версия профиля — `5`. Имя DataStore намеренно не менялось:
`AuraRush_Profile_v1`. Версия schema и имя physical store — разные понятия;
переименование store без backfill создало бы видимость wipe.

Основные поля v5:

```text
schemaVersion, glowDust, unlocks, equipped, savedLooks
auraAtlas, auraAtlasXp, progression, seasonProgress, achievements
quests, liveOps, activationTokens, postcards, atelier, grantLedger
pendingActivations, firstMiracle, settings, stats, ledgers, economyStats
remixCity, grantedRounds, purchaseReceipts, lastSeenAt, session
```

## Migration chain

### v1 → v2

- Создаётся `ledgers` с раздельными paid/grant/spend namespaces.
- Старые `purchaseReceipts` копируются в `ledgers.paidReceipts`.
- Старые `grantedRounds` преобразуются в timestamped `grants.rounds`.
- Добавляются `auraAtlasXp`, `progression`, `economyStats`.
- Legacy saved look вида `{category = itemId}` нормализуется в record с `id`,
  `name`, `createdAt`, `loadout`; отсутствующие категории заполняются default loadout.

### v2 → v3

- Добавляются daily/weekly quests, bank/streak/totals.
- Добавляются `liveOps.contributions` и `claimedMilestones`.
- Добавляются `activationTokens`, `pendingActivations`, `postcards`, `atelier`,
  `firstMiracle` и `grantLedger`.

`pendingActivations` делает платный celebration token crash/reconnect-safe, а
`firstMiracle` хранит versioned status, выбранную palette, индекс действия, deadlines,
причину completion и флаг уже выданной награды. Завершение использует постоянный
namespaced grant `system:first_miracle:v1`, поэтому 100 GlowDust, 80 Motion Aura Atlas XP и
`aura_first_miracle` нельзя получить повторно через reconnect или повторный запрос.

### v3 → v4

- Добавляется `remixCity`: preferred role, replay consent, до восьми сохранённых
  replay, счётчики вклада и сезон 1.
- В `atelier` добавляется durable `blockedInviters`; блокировка приглашений хранится
  30 дней и проверяется до создания invite.
- Replay нормализуется до 24 серверно-сформированных событий; свободный текст и
  user ID в persistent contract не входят.

### v4 → v5

- `firstMiracle.version` повышается до `2`: завершение первого выхода теперь
  серверно-авторитетно и связано с eligibility основного раунда.
- Начатый First Miracle возобновляется без повторного welcome; свежий игрок не может
  попасть в раунд до completion, а завершивший входит в BriefChoice или как late join.
- `onboardingComplete` от клиента принимается только при выключенном First Miracle или
  уже доказанном `Complete`; прежнее завершённое состояние не сбрасывается.

После step migrations `reconcile` добавляет отсутствующие default fields, а
`normalizeProfile` ограничивает числа, коллекции и ledgers. Migration никогда не
должна уменьшать currency, удалять unlocks или переименовывать catalog IDs молча.

## Session и save semantics

- Load/save использует `UpdateAsync` и session lease с job ID и expiry. Lease из
  текущего Config — 180 секунд.
- Активная чужая lease блокирует захват профиля.
- Entry хранит revision; если mutation произошла во время save yield, dirty flag не
  очищается ошибочно.
- Autosave запускается раз в 60 секунд согласно Config.
- Shutdown пытается сохранять до 25-секундного Config budget и не снимает lease,
  если финальная запись не подтверждена.
- В неопубликованном Studio или при недоступном persistent storage профиль работает
  read-only: run доступен, durable mutations/purchase acknowledgment запрещены.

## Limits

Канонические значения берутся из `Config.DataLimits`; таблица ниже соответствует
schema/client v5/v6 и текущему writer.

| Поле | Лимит |
|---|---:|
| Saved looks | 20 |
| Look name | 24 символа до filtering/trim |
| Unlocks на category | 256 |
| Granted rounds compatibility history | 30 |
| Grant ledger | 180 entries |
| Quest history | 90 entries |
| Postcards | 24 |
| Saved replays | 8 |
| Events per replay | 24 |

Saved looks, compatibility history, grant ledger и postcards обрезаются writer-ом
до соответствующего лимита. `MaximumUnlocksPerCategory` — защитный предел каталога,
но существующие permanent unlocks нельзя молча обрезать при migration. Отдельной
quest-history collection в v3 нет; значение 90 зарезервировано для будущего history
writer, а текущие daily/weekly/bank коллекции имеют собственные контентные пределы.
Timestamp ledgers удаляют самые старые transient entries при переполнении. Permanent
entitlement нельзя помещать в агрессивно обрезаемый ledger без отдельного источника
истины.

## Idempotency rules

- `roundId` уникален для награды и quest record.
- Receipt использует Roblox purchase/receipt ID.
- LiveOps contribution и milestone имеют event-namespaced ID.
- Mastery использует permanent `item:<itemId>`.
- Spend должен иметь уникальный caller-generated ID.

Повтор операции возвращает `alreadyApplied`/существующий результат, не повторяя
mutation. Совпадение ID между namespaces не конфликтует.

## Обязательные migration fixtures

1. Минимальный v1 profile с валютой, unlocks, loadout, receipts и granted rounds.
2. v1 legacy saved looks с пропущенными categories.
3. Полный v2 profile с Aura Atlas XP и ledgers.
4. Повреждённые optional tables и числа вне диапазона.
5. v3 profile с максимально заполненными ledgers/postcards/lookbook, незавершённой
   `pendingActivations` и каждым допустимым статусом `firstMiracle`.
6. v4 profile с полным replay-архивом, сезоном и blocked inviters.
7. v5 profile с First Miracle v2: fresh, active, complete и legacy onboarding-complete.
8. Повтор completion `system:first_miracle:v1`, timeout/skip и reconnect во время Bloom.
9. Duplicate load/save, чужая active session lease и future schema, которую writer не имеет права понижать.

Для каждого fixture сравниваются invariants: баланс не уменьшается, starter/default
loadout валиден, existing unlocks остаются, paid receipt не теряется, schema становится
не ниже 5 и никогда не понижается, limits соблюдаются, повторная migration даёт тот же результат.

## Rollback

Code rollback не должен понижать `schemaVersion` или записывать v5 profile старым
writer, который не сохраняет новые поля. Безопасный rollback — предыдущий binary с
forward-compatible reconcile либо feature kill-switch при сохранении v5 writer.
Перед production rollout нужен snapshot/backup strategy Creator Dashboard и малый cohort.
