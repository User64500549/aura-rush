# Журнал архитектурных решений

## D-001 — Русский creative fantasy вместо оценки внешности

**Решение:** игра оценивает действия, кооперацию и образ, а не лицо, тело или
«привлекательность» игрока.

**Почему:** это безопаснее для молодой аудитории, лучше соответствует Roblox и
даёт более интересные игровые переменные: маршрут, ритм, цвет, роль и команда.

## D-002 — Маленький server-owned OPS вместо универсальной админ-консоли

**Решение:** роли определяет `StaffPolicy`; UI доступен только после
авторизованного server snapshot. Разрешены health/audit и два шаблонных
объявления.

**Почему:** произвольные команды, free text, выдача наград и live-конфигурация
создали бы крупную exploit/операционную поверхность без доказанной пользы.

## D-003 — Один shared guard для вторичных durable stores

**Решение:** receipt archive, shared Atelier и Community Bloom используют
`DataStoreOperation` с budget wait, bounded retry и diagnostics.

**Почему:** эти записи раньше имели разный уровень защиты. Общая политика
уменьшает риск молчаливого расхождения и делает деградацию видимой в OPS.

## D-004 — Community Bloom защищён receipt ledger-ом

**Решение:** global contribution пишет bounded idempotency receipt map, а не
безусловный delta.

**Почему:** результат `UpdateAsync` при transient failure может быть неизвестен;
повтор не должен дважды начислить один contribution.

## D-005 — Не публиковать и не включать commerce автоматически

**Решение:** этот репозиторий строит и тестирует локальный candidate, но не меняет
live place и не активирует нулевые SKU.

**Почему:** публикация, asset лицензии, SKU и production DataStores требуют
отдельной авторизации и ручного evidence.

## D-006 — CI проверяет честные source contracts, Studio остаётся local gate

**Решение:** GitHub Actions запускает self-contained PowerShell contract test.
Полный Roblox Studio smoke suite выполняется локально там, где доступен Studio.

**Почему:** это даёт настоящий повторяемый PR gate без имитации Roblox runtime в
облачном runner-е и без ложного заявления, что CI проверил Player UX.
