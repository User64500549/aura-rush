# Русский текст AURA RUSH

Русский — исходный язык продукта. Английский остаётся поддерживаемым переводом, но не определяет названия механик и тон интерфейса.

## Название и обещание

- Название: **AURA RUSH: СТИЛЬ-РЕЙД**.
- Слоган: **«Собери образ. Пройди район. Перекрась сцену.»**
- Игра оценивает вкус, сочетания, прохождение и вклад в команду. Тело, лицо и реальные особенности игрока не оцениваются.

## Словарь игрока

| Stable ID / старое имя | Пишем игроку |
|---|---|
| First Miracle | Первый выход |
| Vibe Contract / Brief | Тема раунда |
| Thread Run | Погоня |
| Beat Lab | Бит-челлендж |
| Prism Puzzle | Цветовой код |
| Mix Lab | Гримёрка |
| World Bloom | Перекраска |
| Aura Genome | Почерк |
| GlowDust | Искры |
| Aura Atlas | Прокачка |
| Creator Hub | Профиль |
| Community Canvas | Общий район |
| Lookbook | Лукбук |
| Atelier / Crew | Команда |
| Postcard | Карточка момента |
| Glowstorm | Светошум |

Stable ID, имя DataStore, remote и enum не переводятся и не показываются игроку.

## Правила текста

1. Одна кнопка — один глагол: «Выбрать», «Надеть», «Сохранить».
2. Инструкция отвечает на вопрос «что сделать сейчас» и занимает не больше двух коротких строк.
3. Заголовки пишутся обычным регистром. Капслок не используется как стиль.
4. Ошибка объясняет результат и следующий шаг: «Нет связи с сервером. Попробуй ещё раз».
5. Не используем псевдопоэзию и рекламные штампы: «раскрой потенциал», «погрузись в мир», «стань легендой», «уникальное путешествие».
6. Не используем технические слова: DataStore, feature flag, kill switch, raw ID, schema, procedural.
7. Английское слово допустимо только как узнаваемое имя платформы Roblox. Внутриигровые механики называются по-русски.
8. Не обещаем случайную или неизвестную награду. До покупки игрок видит предметы, цену и компенсацию за дубль.

## Безопасный вывод

Для обычных ключей player UI использует `Localization.GetPlayerText`. Для stable ID — `Localization.GetIdentifier`. Эти функции никогда не показывают игроку отсутствующий ключ или raw ID.

```luau
local title = Localization.GetIdentifier(locale, "route", route.id)
local detail = Localization.GetIdentifier(locale, "route_description", route.id)
local toast = Localization.GetIdentifier(locale, "toast", serverReason)
local briefTitle = Localization.GetBriefTitle(
	locale,
	brief.worldId,
	brief.occasionId,
	brief.aestheticId,
	brief.twistId
)
```

`Localization.Get` сохранён для совместимости и диагностики. Новый player-facing код не должен использовать его для динамических ключей.
