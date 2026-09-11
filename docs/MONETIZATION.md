# Монетизация

Полная спецификация находится в
[ECONOMY_AND_MONETIZATION.md](ECONOMY_AND_MONETIZATION.md).

## Принципы

- Платится за самовыражение, коллекцию и добровольное празднование, не за score.
- Цена и содержимое известны до prompt; случайных наград нет.
- Prompt появляется только после явного действия игрока.
- Mastery progression нельзя купить или обойти платным bundle.
- Paid receipt, earnable grants и spends используют разные ledger.

## Фактический каталог v3

- GlowDust Pocket — 250 GlowDust.
- GlowDust Bundle — 900 GlowDust.
- GlowDust Vault — 3000 GlowDust.
- Glowstorm — один сохраняемый `glowstorm` activation token; игрок сам активирует
  его, сервер проверяет token/cooldown, а клиенты строят локальный доступный эффект.
- Signature Prism Collection — детерминированные `palette_solar_flare`,
  `aura_glitch_halo`, `pose_editorial_turn`.
- Director Pack, Atelier Pro и Prism Patron — заготовки passes без активной продажи.
- Aura Club — заготовка subscription без активной продажи.

Числовые product/pass ID равны `0`, subscription ID — `""`. Флаги `Purchases`,
`Passes` и `Subscriptions` выключены. Store получает локализованную цену у Roblox и
не хранит Robux-цену в коде.

## Безопасный запуск commerce

1. Создать SKU в Creator Dashboard того же universe.
2. Внести ID только в canonical `id`, не меняя `key`.
3. Реализовать и вручную проверить каждую benefit passes/subscription.
4. Проверить purchase, reconnect, crash/retry, duplicate receipt, save failure,
   unknown product и read-only profile в закрытом тесте.
5. Сначала включить `Purchases` для проверенных developer products; `Passes` и
   `Subscriptions` включать независимо и только после полного benefit audit.

До выполнения этих шагов опубликованная монетизация остаётся release gate.
