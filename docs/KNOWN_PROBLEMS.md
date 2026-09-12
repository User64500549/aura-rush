# KNOWN PROBLEMS

| Приоритет | Проблема | Что известно | Следующее доказательство |
|---|---|---|---|
| P0 | Чистый Roblox Player join текущего build не выполнен | На машине одновременно есть Player 0.708 в LocalAppData и 0.737/старые версии в Program Files. Проблемный журнал 0.737 фиксировал массовый `DnsResolve` для `tr.rbxcdn.com`; GPU/D3D11 и swap chain создались успешно. Сейчас DNS lookup проходит, поэтому сбой мог быть временным. | Новый запуск только актуального клиента; проверить свежий лог и реальный join. Не удалять установки без явного согласия. |
| P0 | Нет 4-client regression текущей версии | Server authority покрыт smoke, но реальные City Pulse, simultaneous Secret Frame reveal, late join, reconnect и friend encore не доказаны. | Studio Server & Clients ×4 с записанным Output. |
| P0 | Нет published DataStore evidence вторичных durable stores | Receipt archive, Atelier и Community Bloom теперь имеют unified retry/budget guard и idempotent receipt path, но реальный throttle/outage/reconnect не воспроизведён. | Private published universe: transient failure, shutdown flush, reconnect и duplicate receipt/contribution. |
| P0 | Нет текущего low-end mobile/gamepad profile | Есть responsive contracts и budgets, но нет raw FPS/memory/input evidence. | Android/iOS target + gamepad, MicroProfiler и screenshot matrix. |
| P1 | OPS role matrix не пройдена руками | Код deny-by-default и source contracts защищают access, но owner/support/moderator/admin/player UI на настоящих аккаунтах ещё не проверены. | Private server с пятью ролями; audit privacy, cooldown и отсутствие OPS у игрока. |
| P1 | Нет живой продуктовой выборки | Локальные suites не доказывают fun, D1/D7, viral или discovery conversion. | 10–20 first sessions, затем закрытый cohort и dashboard baseline. |
| P1 | Финальные assets не подключены | Procedural fallback целостный и быстрый, но production manifest не содержит подтверждённый полный mesh/material/audio pack. | Один лицензированный district kit, затем повторить memory/render budget. |
| P1 | Secret Frames не прошли ручную навигацию | Координаты, line-of-sight и server distance проверены структурно; видимость/достижимость игроком не подтверждена в Play Solo. | Найти все шесть без Explorer/подсказки разработчика на desktop и touch. |
| P1 | Synchronous world construction | 1140 BaseParts создаются до полного server startup. Loading shell скрывает пустой кадр, но не уменьшает CPU join cost. `ServerBoot.WorldBuild` уже пишется в log/атрибут. | Снять baseline на 4/12-client server; оптимизировать только после профиля. |
| P2 | Крупные `WorldService` и `App` | Высокий regression radius, хотя текущие contracts стабильны. | Извлекать домены только при следующем измеренном изменении; не делать big-bang rewrite. |
| P2 | Commerce не готов | IDs `0`/`""`, flags выключены; это безопасно, но не monetization launch. | Реальные SKU, PolicyService, receipt/reconnect/refund matrix и staged rollout. |
| P2 | Финальные animation/audio passes неполны | Game feel использует procedural/local feedback и modular fallback; лицензированный набор отсутствует. | Сначала измерить core fun, затем добавить компактный authored pack. |

## Не считать багом

- Commerce safe-off до настройки SKU.
- Read-only Studio profile в unpublished local universe.
- Capability fallback для новых NotScriptable Workspace properties в локальной
  Studio; canonical build tokens проверяются отдельно.
- Отсутствие обещания «много игроков»: это результат дистрибуции и retention data,
  а не свойство исходного кода.
- Отсутствие production staff access при пустом `OwnerUserIds`/`GroupId`: это
  безопасный default до отдельной защищённой конфигурации.
