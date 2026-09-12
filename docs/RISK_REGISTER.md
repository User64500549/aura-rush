# Реестр рисков

| Приоритет | Риск | Текущий контроль | Следующее доказательство | Статус |
|---|---|---|---|---|
| P0 | Реальный Player join может снова показать серый экран из-за клиента, сети или handoff | Независимый `ReplicatedFirst` loading shell, runtime state и error boundary | Чистый актуальный Roblox Player + свежий log на этом build | OPEN |
| P0 | Мультиплеерная регрессия не ловится одним headless сервером | Server-authoritative contracts, 17 Studio suites, remote limits | Studio Server & Clients ×4: late join, disconnect, City Pulse, Bloom | OPEN |
| P0 | Данные внешних social/community/receipt stores могут временно быть недоступны | Unified retry/budget guard, idempotent receipt ledger, OPS diagnostics | Published private universe outage/reconnect/shutdown matrix | OPEN |
| P1 | Неправильно настроенная staff policy может лишить владельца доступа или выдать лишний | Deny-by-default, server resolution, allowlisted actions | Private role matrix: owner/support/moderator/admin/player | OPEN |
| P1 | Синхронная генерация 1140 BaseParts может ухудшить join | `ServerBoot.WorldBuild` measurement и budget checks | p50/p95 private server + device profiler | OPEN |
| P1 | Процедурные assets не дают финального premium impression | Art direction contract и fallback не зависят от asset IDs | Лицензированный один district kit + повторный performance pass | OPEN |
| P1 | Onboarding/retention не подтверждены живой аудиторией | Funnel events и короткий action-first flow | 10–20 no-coaching sessions, затем cohort baseline | OPEN |
| P2 | `WorldService` и `App` остаются крупными зонами регрессии | Узкие contracts, no big-bang rewrite policy | Извлекать module только вместе с измеренной задачей | MITIGATED |
| P2 | Commerce может стать unfair при раннем включении | Все SKU выключены, IDs пустые, server receipt path | Full SKU/policy/refund test перед любой активацией | OPEN |

## Правило закрытия риска

Риск закрывается только ссылкой на конкретный build, тестовый сценарий, дату и
наблюдаемый результат. Кодовая гипотеза, старый лог или «у меня открылось один
раз» не являются достаточным evidence.
