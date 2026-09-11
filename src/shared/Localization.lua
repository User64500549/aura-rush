--!strict

local Types = require(script.Parent.Types)
type LocalizationArgs = Types.LocalizationArgs

type LocaleCode = "en" | "ru"
type StringMap = { [string]: string }
type StringTables = { en: StringMap, ru: StringMap }
type CopyEntry = { key: string, en: string, ru: string }
type LocalizedName = { id: string, en: string, ru: string }

local DEFAULT_LOCALE: LocaleCode = "ru"
local english: StringMap = {}
local russian: StringMap = {}

local function addCopy(key: string, en: string, ru: string): ()
	assert(english[key] == nil and russian[key] == nil, `Duplicate localization key: {key}`)
	english[key] = en
	russian[key] = ru
end

local copy: { CopyEntry } = {
	-- Product identity and global UI.
	{
		key = "game.title",
		en = "AURA RUSH: STYLE RAID",
		ru = "AURA RUSH: СТИЛЬ-РЕЙД",
	},
	{
		key = "game.tagline",
		en = "Build a look. Run the district. Repaint the scene.",
		ru = "Собери образ. Пройди район. Перекрась сцену.",
	},
	{ key = "ui.loading", en = "Loading your studio…", ru = "Готовим студию…" },
	{
		key = "ui.waiting_for_round",
		en = "A new raid starts soon",
		ru = "Новый рейд скоро начнётся",
	},
	{
		key = "ui.spectating",
		en = "You will join the next round",
		ru = "Ты войдёшь в следующий раунд",
	},
	{ key = "ui.glowdust", en = "Sparks", ru = "Искры" },
	{ key = "ui.round_timer", en = "{seconds}s", ru = "{seconds} с" },
	{
		key = "ui.brief_selected",
		en = "Round theme selected",
		ru = "Тема раунда выбрана",
	},
	{ key = "ui.base", en = "Before", ru = "До" },
	{ key = "ui.bloom", en = "After", ru = "После" },
	{
		key = "ui.round_complete",
		en = "Scene repainted!",
		ru = "Сцена перекрашена!",
	},
	{ key = "ui.unknown", en = "Not available", ru = "Нет данных" },

	-- First 90 seconds.
	{
		key = "first_miracle.title",
		en = "Your first entrance",
		ru = "Выбери свой цвет",
	},
	{
		key = "first_miracle.intro",
		en = "Pick a palette, complete three quick moves, and repaint your first scene.",
		ru = "Выбери палитру, пройди три коротких шага — и район ответит.",
	},
	{ key = "first_miracle.palette.prism", en = "Prism", ru = "Призма" },
	{ key = "first_miracle.palette.cyan", en = "Fresh blue", ru = "Свежий голубой" },
	{ key = "first_miracle.palette.sunset", en = "Sunset", ru = "Закат" },
	{
		key = "first_miracle.action.collect_thread",
		en = "Catch a style thread",
		ru = "Поймай нить стиля",
	},
	{ key = "first_miracle.action.tune_pulse", en = "Hit the beat", ru = "Попади в бит" },
	{
		key = "first_miracle.action.focus_prism",
		en = "Match the colors",
		ru = "Повтори цвета",
	},
	{
		key = "first_miracle.reward",
		en = "+{glowDust} Sparks · +{atlasXp} style XP · new aura",
		ru = "+{glowDust} искр · +{atlasXp} опыта · новый эффект",
	},
	{
		key = "toast.first_miracle_complete",
		en = "First entrance saved to your Lookbook!",
		ru = "Первый образ сохранён в коллекции!",
	},
	{
		key = "toast.postcard_created",
		en = "Moment card saved!",
		ru = "Карточка момента сохранена!",
	},

	-- Round states and direct instructions.
	{ key = "round.state.Waiting", en = "Waiting", ru = "Ожидание" },
	{ key = "round.state.Intermission", en = "Get ready", ru = "Готовься" },
	{ key = "round.state.BriefChoice", en = "Round theme", ru = "Тема раунда" },
	{ key = "round.state.ThreadRun", en = "Chase", ru = "Погоня" },
	{ key = "round.state.BeatLab", en = "Beat challenge", ru = "Бит-челлендж" },
	{ key = "round.state.PrismPuzzle", en = "Color code", ru = "Цветовой код" },
	{ key = "round.state.MixLab", en = "Dressing room", ru = "Гримёрка" },
	{ key = "round.state.Finale", en = "Repaint", ru = "Перекраска" },
	{ key = "round.state.Results", en = "Results", ru = "Итоги" },
	{
		key = "round.state.Cleanup",
		en = "Preparing the next raid",
		ru = "Готовим новый рейд",
	},
	{
		key = "instruction.brief",
		en = "Choose a district and round theme.",
		ru = "Выбери район и тему раунда.",
	},
	{
		key = "instruction.thread",
		en = "Follow the marks and collect threads.",
		ru = "Беги по меткам и собирай нити.",
	},
	{
		key = "instruction.beat",
		en = "Tap when the pulse hits the center.",
		ru = "Нажми, когда импульс войдёт в центр.",
	},
	{
		key = "instruction.prism",
		en = "Repeat the color sequence.",
		ru = "Повтори цепочку цветов.",
	},
	{
		key = "instruction.mix",
		en = "Build your look, then press Ready.",
		ru = "Собери образ и нажми «Готово».",
	},
	{
		key = "instruction.finale",
		en = "Take a pose and repaint the scene.",
		ru = "Встань в позу и перекрась сцену.",
	},
	{
		key = "instruction.results",
		en = "Check your rewards and team clip.",
		ru = "Забери награды и посмотри командный клип.",
	},

	-- Controls.
	{ key = "button.choose", en = "Choose", ru = "Выбрать" },
	{ key = "button.ready", en = "Ready", ru = "Готово" },
	{ key = "button.edit", en = "Edit look", ru = "Изменить образ" },
	{ key = "button.randomize", en = "New mix", ru = "Новый микс" },
	{ key = "button.play_again", en = "Play again", ru = "Ещё раз" },
	{ key = "button.capture", en = "Save moment", ru = "Сохранить момент" },
	{ key = "button.invite", en = "Invite a friend", ru = "Позвать друга" },
	{ key = "button.shop", en = "Shop", ru = "Магазин" },
	{ key = "button.close", en = "Close", ru = "Закрыть" },
	{ key = "button.equip", en = "Equip", ru = "Надеть" },
	{ key = "button.unlock", en = "Unlock", ru = "Открыть" },

	-- Style catalog labels.
	{ key = "style.category.palette", en = "Palette", ru = "Цвета" },
	{ key = "style.category.material", en = "Material", ru = "Фактура" },
	{ key = "style.category.aura", en = "Aura", ru = "Аура" },
	{ key = "style.category.pose", en = "Pose", ru = "Поза" },
	{ key = "style.category.accent", en = "Accent", ru = "Деталь" },
	{
		key = "style.description.palette",
		en = "Colors for your look and finale.",
		ru = "Цвета образа и финальной сцены.",
	},
	{
		key = "style.description.material",
		en = "The finish on your style details.",
		ru = "Покрытие деталей образа.",
	},
	{
		key = "style.description.aura",
		en = "A cosmetic light trail.",
		ru = "Световой след вокруг героя.",
	},
	{
		key = "style.description.pose",
		en = "Your pose for the team clip.",
		ru = "Поза для командного клипа.",
	},
	{
		key = "style.description.accent",
		en = "One extra detail for the look.",
		ru = "Дополнительная деталь образа.",
	},
	{
		key = "style.locked",
		en = "Unlock for {amount} Sparks",
		ru = "Открыть за {amount} искр",
	},
	{
		key = "style.mastery_locked",
		en = "Requires style level {level}",
		ru = "Нужен {level}-й уровень стиля",
	},
	{ key = "style.rarity.Common", en = "Common", ru = "Обычное" },
	{ key = "style.rarity.Uncommon", en = "Uncommon", ru = "Необычное" },
	{ key = "style.rarity.Rare", en = "Rare", ru = "Редкое" },
	{ key = "style.rarity.Epic", en = "Epic", ru = "Эпическое" },
	{ key = "style.unlock.Default", en = "Included", ru = "В наборе" },
	{ key = "style.unlock.GlowDust", en = "For Sparks", ru = "За искры" },
	{ key = "style.unlock.Mastery", en = "For style level", ru = "За уровень стиля" },
	{ key = "style.unlock.Milestone", en = "For an achievement", ru = "За достижение" },

	-- Progress and timing quality.
	{ key = "progress.thread", en = "Threads {value}/{target}", ru = "Нити {value}/{target}" },
	{ key = "progress.beat", en = "Beats {value}/{target}", ru = "Биты {value}/{target}" },
	{ key = "progress.prism", en = "Colors {value}/{target}", ru = "Цвета {value}/{target}" },
	{
		key = "progress.material_surf",
		en = "Samples {value}/{target}",
		ru = "Образцы {value}/{target}",
	},
	{
		key = "progress.light_loom",
		en = "Light lanes {value}/{target}",
		ru = "Линии света {value}/{target}",
	},
	{
		key = "progress.bloom_rescue",
		en = "Nodes {value}/{target}",
		ru = "Узлы {value}/{target}",
	},
	{ key = "quality.perfect", en = "Perfect", ru = "Точно" },
	{ key = "quality.good", en = "Good", ru = "Хорошо" },
	{ key = "quality.miss", en = "Miss", ru = "Мимо" },

	-- Toasts. Keys mirror stable server reason IDs, but the displayed values never do.
	{
		key = "toast.invalid_action",
		en = "This action is not available now.",
		ru = "Сейчас так сделать нельзя.",
	},
	{
		key = "toast.invalid_style",
		en = "This item is not available yet.",
		ru = "Эта вещь пока недоступна.",
	},
	{ key = "toast.style_equipped", en = "Item equipped!", ru = "Вещь надета!" },
	{
		key = "toast.style_ready",
		en = "Look ready for the finale!",
		ru = "Образ готов к финалу!",
	},
	{ key = "toast.reward_granted", en = "+{amount} Sparks", ru = "+{amount} искр" },
	{
		key = "toast.data_read_only",
		en = "Saving is temporarily unavailable. Purchases are off.",
		ru = "Сохранение временно не работает. Покупки отключены.",
	},
	{
		key = "toast.capture_unavailable",
		en = "A moment cannot be saved on this device.",
		ru = "На этом устройстве нельзя сохранить момент.",
	},
	{
		key = "toast.look_saved",
		en = "Look saved to your Lookbook.",
		ru = "Образ сохранён в Лукбук.",
	},
	{ key = "toast.look_deleted", en = "Look deleted.", ru = "Образ удалён." },
	{
		key = "toast.look_equipped",
		en = "Saved look equipped.",
		ru = "Сохранённый образ надет.",
	},
	{
		key = "toast.quest_rerolled",
		en = "Daily task replaced.",
		ru = "Задание на сегодня заменено.",
	},
	{
		key = "toast.milestone_claimed",
		en = "District reward collected!",
		ru = "Награда района получена!",
	},
	{ key = "toast.vote_saved", en = "Vote counted.", ru = "Голос учтён." },
	{
		key = "toast.positive_nomination",
		en = "{from} gave you a like.",
		ru = "{from} отметил(а) твой образ.",
	},
	{
		key = "toast.capture_ready",
		en = "Moment card is ready.",
		ru = "Карточка момента готова.",
	},
	{
		key = "toast.connection_unavailable",
		en = "Server connection lost. Try again.",
		ru = "Нет связи с сервером. Попробуй ещё раз.",
	},
	{
		key = "toast.secret_frame_found",
		en = "{frame} found · +{amount} Sparks",
		ru = "Найден кадр «{frame}» · +{amount} Искр",
	},
	{
		key = "toast.secret_frame_repeat",
		en = "This frame is already in your collection.",
		ru = "Этот кадр уже есть в коллекции.",
	},
	{
		key = "toast.secret_frame_collection_complete",
		en = "All Secret Frames found · +{amount} Sparks",
		ru = "Все секретные кадры собраны · +{amount} Искр",
	},
	{
		key = "toast.store_not_configured",
		en = "The shop is not ready yet.",
		ru = "Магазин пока не готов.",
	},
	{
		key = "toast.store_read_only",
		en = "Purchases are temporarily off.",
		ru = "Покупки временно отключены.",
	},
	{
		key = "toast.store_prompt_failed",
		en = "Roblox could not open the purchase window.",
		ru = "Roblox не смог открыть окно покупки.",
	},
	{
		key = "toast.store_not_published",
		en = "This offer is not live yet.",
		ru = "Это предложение ещё не опубликовано.",
	},
	{
		key = "toast.server_glowstorm",
		en = "{from} started a district light show!",
		ru = "{from} запустил(а) светошум в районе!",
	},
	{ key = "toast.route_saved", en = "Route selected.", ru = "Маршрут выбран." },
	{
		key = "toast.requeue_saved",
		en = "You are in the next raid.",
		ru = "Ты в очереди на следующий рейд.",
	},
	{
		key = "toast.style_unlocked",
		en = "New item unlocked!",
		ru = "Новая вещь открыта!",
	},
	{
		key = "toast.invalid_category",
		en = "Choose another section.",
		ru = "Выбери другой раздел.",
	},
	{
		key = "toast.invalid_item",
		en = "This item is unavailable.",
		ru = "Эта вещь недоступна.",
	},
	{
		key = "toast.locked",
		en = "Unlock this item first.",
		ru = "Сначала открой эту вещь.",
	},
	{
		key = "toast.style_transaction_rejected",
		en = "Could not unlock the item. Try again.",
		ru = "Не удалось открыть вещь. Попробуй ещё раз.",
	},
	{
		key = "toast.mastery_required",
		en = "Your style level is too low.",
		ru = "Нужен более высокий уровень стиля.",
	},
	{
		key = "toast.profile_unavailable",
		en = "Profile is unavailable. Try again.",
		ru = "Профиль недоступен. Попробуй ещё раз.",
	},
	{
		key = "toast.style_not_purchasable",
		en = "This item is earned another way.",
		ru = "Эта вещь открывается другим способом.",
	},
	{
		key = "toast.lookbook_full",
		en = "Your Lookbook is full.",
		ru = "В Лукбуке нет свободных мест.",
	},
	{
		key = "toast.look_already_saved",
		en = "This look is already saved.",
		ru = "Этот образ уже сохранён.",
	},
	{
		key = "toast.look_save_rejected",
		en = "Could not save the look.",
		ru = "Не удалось сохранить образ.",
	},
	{
		key = "toast.invalid_look",
		en = "This look is unavailable.",
		ru = "Этот образ недоступен.",
	},
	{ key = "toast.look_not_found", en = "Look not found.", ru = "Образ не найден." },
	{
		key = "toast.look_contains_locked_item",
		en = "This look includes a locked item.",
		ru = "В образе есть закрытая вещь.",
	},

	-- Authored run routes, modifiers and acts.
	{
		key = "run.route.kinetic_cascade.name",
		en = "Fast route",
		ru = "Скоростной путь",
	},
	{
		key = "run.route.kinetic_cascade.description",
		en = "More movement and quick choices.",
		ru = "Больше движения и быстрых решений.",
	},
	{
		key = "run.route.precision_atelier.name",
		en = "Precision route",
		ru = "Точный путь",
	},
	{
		key = "run.route.precision_atelier.description",
		en = "Less rush and trickier patterns.",
		ru = "Меньше спешки, но сложнее узоры.",
	},
	{ key = "run.route.wild_remix.name", en = "Mixed route", ru = "Микс-маршрут" },
	{
		key = "run.route.wild_remix.description",
		en = "A mix of speed and precision tasks.",
		ru = "Скорость и точность в одном маршруте.",
	},
	{
		key = "run.modifier.mirror_current.name",
		en = "Mirror flow",
		ru = "Зеркальный поток",
	},
	{
		key = "run.modifier.mirror_current.description",
		en = "Some signals are mirrored.",
		ru = "Часть сигналов отражается зеркально.",
	},
	{
		key = "run.modifier.soft_gravity.name",
		en = "Soft gravity",
		ru = "Мягкая гравитация",
	},
	{
		key = "run.modifier.soft_gravity.description",
		en = "Jumps are longer and landings are softer.",
		ru = "Прыжки длиннее, а приземления мягче.",
	},
	{ key = "run.modifier.chromatic_echo.name", en = "Color echo", ru = "Цветовое эхо" },
	{
		key = "run.modifier.chromatic_echo.description",
		en = "The last color repeats once.",
		ru = "Последний цвет повторяется ещё раз.",
	},
	{ key = "run.modifier.living_runway.name", en = "Moving stage", ru = "Живая сцена" },
	{
		key = "run.modifier.living_runway.description",
		en = "Parts of the route move to the beat.",
		ru = "Части маршрута двигаются в такт биту.",
	},
	{ key = "run.act.thread_run.name", en = "Thread chase", ru = "Погоня за нитями" },
	{
		key = "run.act.thread_run.instruction",
		en = "Collect the glowing threads.",
		ru = "Собери светящиеся нити.",
	},
	{ key = "run.act.material_surf.name", en = "Texture wave", ru = "Волна фактур" },
	{
		key = "run.act.material_surf.instruction",
		en = "Ride the wave and collect samples.",
		ru = "Пройди по волне и собери образцы.",
	},
	{ key = "run.act.beat_lab.name", en = "Beat challenge", ru = "Бит-челлендж" },
	{
		key = "run.act.beat_lab.instruction",
		en = "Hit the beat together.",
		ru = "Попадайте в бит вместе.",
	},
	{ key = "run.act.light_loom.name", en = "Light lanes", ru = "Линии света" },
	{
		key = "run.act.light_loom.instruction",
		en = "Join four lanes into one pattern.",
		ru = "Собери четыре линии в один узор.",
	},
	{ key = "run.act.prism_puzzle.name", en = "Color code", ru = "Цветовой код" },
	{
		key = "run.act.prism_puzzle.instruction",
		en = "Repeat the colors in order.",
		ru = "Повтори цвета по порядку.",
	},
	{ key = "run.act.bloom_rescue.name", en = "District repair", ru = "Ремонт района" },
	{
		key = "run.act.bloom_rescue.instruction",
		en = "Switch the district nodes back on.",
		ru = "Включи узлы района.",
	},

	-- Brief axes: 6 districts x 4 occasions x 4 aesthetics x 2 twists.
	{
		key = "brief.title.generated",
		en = "{world} · {occasion} — {aesthetic}, {twist}",
		ru = "{world} · {occasion} — {aesthetic}, {twist}",
	},
	{ key = "brief.world.prism_metro.name", en = "Prism Metro", ru = "Призм-метро" },
	{
		key = "brief.world.prism_metro.description",
		en = "A night transit district with platforms and light lines.",
		ru = "Ночной транспортный район с платформами и линиями света.",
	},
	{
		key = "brief.world.cloud_bazaar.name",
		en = "Cloud Market",
		ru = "Облачный рынок",
	},
	{
		key = "brief.world.cloud_bazaar.description",
		en = "Floating stalls, glass bridges, and soft canopies.",
		ru = "Парящие лавки, стеклянные мосты и мягкие тенты.",
	},
	{
		key = "brief.world.moonlit_greenhouse.name",
		en = "Moon Greenhouse",
		ru = "Лунная оранжерея",
	},
	{
		key = "brief.world.moonlit_greenhouse.description",
		en = "A garden under glass where plants switch on the lights.",
		ru = "Сад под куполом, где растения включают свет.",
	},
	{
		key = "brief.world.orbital_boardwalk.name",
		en = "Orbital Boardwalk",
		ru = "Орбитальная набережная",
	},
	{
		key = "brief.world.orbital_boardwalk.description",
		en = "A track, rides, and a stage in orbit.",
		ru = "Трасса, аттракционы и сцена на орбите.",
	},
	{
		key = "brief.world.velvet_archive.name",
		en = "Velvet Archive",
		ru = "Бархатный архив",
	},
	{
		key = "brief.world.velvet_archive.description",
		en = "A fashion archive with fabric halls and hidden passages.",
		ru = "Модный архив с тканевыми залами и тайными проходами.",
	},
	{
		key = "brief.world.solar_cathedral.name",
		en = "Solar Pavilion",
		ru = "Солнечный павильон",
	},
	{
		key = "brief.world.solar_cathedral.description",
		en = "A warm glass hall with moving mirrors.",
		ru = "Тёплый стеклянный зал с подвижными зеркалами.",
	},
	{
		key = "brief.occasion.rescue_rehearsal.name",
		en = "Training rescue",
		ru = "Учебная эвакуация",
	},
	{
		key = "brief.occasion.rescue_rehearsal.description",
		en = "Repair the route as one team.",
		ru = "Почините маршрут одной командой.",
	},
	{
		key = "brief.occasion.midnight_festival.name",
		en = "Night festival",
		ru = "Ночной фестиваль",
	},
	{
		key = "brief.occasion.midnight_festival.description",
		en = "Light the route before the music starts.",
		ru = "Зажгите маршрут до старта музыки.",
	},
	{
		key = "brief.occasion.mystery_premiere.name",
		en = "Secret premiere",
		ru = "Тайная премьера",
	},
	{
		key = "brief.occasion.mystery_premiere.description",
		en = "Find clues hidden in color and movement.",
		ru = "Найдите подсказки в цвете и движении.",
	},
	{
		key = "brief.occasion.friendship_parade.name",
		en = "Friends parade",
		ru = "Парад друзей",
	},
	{
		key = "brief.occasion.friendship_parade.description",
		en = "Make sure every teammate gets a moment.",
		ru = "Дайте каждому игроку свой момент в финале.",
	},
	{
		key = "brief.aesthetic.retro_future.name",
		en = "Retro future",
		ru = "Ретрофутуризм",
	},
	{
		key = "brief.aesthetic.retro_future.description",
		en = "Chrome shapes and arcade colors.",
		ru = "Хромовые формы и цвета аркады.",
	},
	{
		key = "brief.aesthetic.soft_gothic.name",
		en = "Soft gothic",
		ru = "Мягкая готика",
	},
	{
		key = "brief.aesthetic.soft_gothic.description",
		en = "Dark silhouettes and soft textures.",
		ru = "Тёмные силуэты и мягкие фактуры.",
	},
	{ key = "brief.aesthetic.bioluminescent.name", en = "Living neon", ru = "Живой неон" },
	{
		key = "brief.aesthetic.bioluminescent.description",
		en = "Deep colors and glowing plant lines.",
		ru = "Глубокие цвета и светящиеся линии растений.",
	},
	{
		key = "brief.aesthetic.toybox_editorial.name",
		en = "Bold cover",
		ru = "Яркая обложка",
	},
	{
		key = "brief.aesthetic.toybox_editorial.description",
		en = "Large shapes, clean type, and playful color.",
		ru = "Крупные формы, чёткие надписи и яркие цвета.",
	},
	{ key = "brief.twist.zero_gravity.name", en = "Zero gravity", ru = "Невесомость" },
	{
		key = "brief.twist.zero_gravity.description",
		en = "Props and players hang in the air longer.",
		ru = "Декор и игроки дольше держатся в воздухе.",
	},
	{
		key = "brief.twist.color_eclipse.name",
		en = "Color eclipse",
		ru = "Цветовое затмение",
	},
	{
		key = "brief.twist.color_eclipse.description",
		en = "The scene dims before the final color burst.",
		ru = "Перед финалом сцена темнеет, затем возвращаются все цвета.",
	},

	-- Live event and ethical cosmetic store.
	{
		key = "liveops.community_canvas_genesis.name",
		en = "Shared District: First Season",
		ru = "Общий район: первый сезон",
	},
	{
		key = "liveops.community_canvas_genesis.description",
		en = "Every completed raid adds color to the shared district.",
		ru = "Каждый завершённый рейд добавляет цвет в общий район.",
	},
	{ key = "shop.title", en = "Style shop", ru = "Магазин стиля" },
	{
		key = "shop.price_loading",
		en = "Checking your price…",
		ru = "Уточняем цену…",
	},
	{
		key = "shop.unavailable",
		en = "This offer is not ready yet.",
		ru = "Это предложение пока не готово.",
	},
	{
		key = "shop.non_pay_to_win",
		en = "Cosmetics only. No score boost.",
		ru = "Только косметика. Без прибавки к очкам.",
	},
	{ key = "product.glowdust_pocket.name", en = "Spark pouch", ru = "Мешочек искр" },
	{
		key = "product.glowdust_pocket.description",
		en = "250 Sparks for the cosmetics you choose.",
		ru = "250 искр на выбранную косметику.",
	},
	{ key = "product.glowdust_bundle.name", en = "Spark box", ru = "Коробка искр" },
	{
		key = "product.glowdust_bundle.description",
		en = "900 Sparks for the cosmetics you choose.",
		ru = "900 искр на выбранную косметику.",
	},
	{ key = "product.glowdust_vault.name", en = "Spark case", ru = "Кейс искр" },
	{
		key = "product.glowdust_vault.description",
		en = "3000 Sparks for the cosmetics you choose.",
		ru = "3000 искр на выбранную косметику.",
	},
	{ key = "product.server_glowstorm.name", en = "District light show", ru = "Светошум" },
	{
		key = "product.server_glowstorm.description",
		en = "Start one temporary light show for the whole server.",
		ru = "Запусти одно световое шоу для всего сервера.",
	},
	{
		key = "product.signature_prism_collection.name",
		en = "Signature prism set",
		ru = "Фирменный призм-набор",
	},
	{
		key = "product.signature_prism_collection.description",
		en = "Three previewed cosmetics. A duplicate gives 400 Sparks.",
		ru = "Три показанных предмета. За дубль вернётся 400 искр.",
	},
	{ key = "pass.director_pack.name", en = "Director pack", ru = "Набор режиссёра" },
	{
		key = "pass.director_pack.description",
		en = "Extra camera angles, transitions, and frames.",
		ru = "Дополнительные камеры, переходы и рамки.",
	},
	{ key = "pass.atelier_pro.name", en = "Studio+", ru = "Студия+" },
	{
		key = "pass.atelier_pro.description",
		en = "More saved looks and studio decorations.",
		ru = "Больше мест для образов и декора студии.",
	},
	{ key = "pass.prism_patron.name", en = "Prism supporter", ru = "Призм-патрон" },
	{
		key = "pass.prism_patron.description",
		en = "Supporter cosmetics and a photo backdrop. No score boost.",
		ru = "Косметика и фон для фото. Без прибавки к очкам.",
	},
	{ key = "subscription.aura_club.name", en = "Aura Club", ru = "Аура-клуб" },
	{
		key = "subscription.aura_club.description",
		en = "A listed monthly set of cosmetics and studio extras.",
		ru = "Ежемесячный набор косметики и декора с полным списком наград.",
	},
	{
		key = "benefit.camera_presets",
		en = "Extra camera angles",
		ru = "Дополнительные ракурсы",
	},
	{
		key = "benefit.transitions",
		en = "Extra scene transitions",
		ru = "Дополнительные переходы",
	},
	{
		key = "benefit.capture_frames",
		en = "Moment card frames",
		ru = "Рамки для карточек",
	},
	{
		key = "benefit.lookbook_slots",
		en = "Extra Lookbook slots",
		ru = "Места в Лукбуке",
	},
	{ key = "benefit.studio_decor", en = "Extra studio decor", ru = "Декор студии" },
	{
		key = "benefit.look_variants",
		en = "Saved color variants",
		ru = "Цветовые варианты образов",
	},
	{
		key = "benefit.cosmetic_nameplate",
		en = "Decorative nameplate",
		ru = "Декоративная подпись",
	},
	{ key = "benefit.vip_lounge", en = "Decorative lounge", ru = "Зона отдыха" },
	{
		key = "benefit.vip_cosmetics",
		en = "Previewed aura and pose set",
		ru = "Показанный набор аур и поз",
	},
	{
		key = "benefit.monthly_cosmetics",
		en = "Guaranteed monthly cosmetic set",
		ru = "Гарантированный ежемесячный набор",
	},
	{
		key = "benefit.monthly_studio_theme",
		en = "Monthly studio theme",
		ru = "Ежемесячная тема студии",
	},
	{
		key = "benefit.color_variants",
		en = "Extra color variants",
		ru = "Дополнительные варианты цветов",
	},
	{
		key = "benefit.celebration_token",
		en = "One district light show",
		ru = "Один светошум",
	},
}

for _, entry in copy do
	addCopy(entry.key, entry.en, entry.ru)
end

local styleNames: { LocalizedName } = {
	{ id = "palette_prism", en = "Prism Pulse", ru = "Призм-импульс" },
	{ id = "palette_cyan", en = "Cyan Current", ru = "Голубой ток" },
	{ id = "palette_sunset", en = "Starter Sunset", ru = "Закат" },
	{ id = "palette_sunset_pop", en = "Sunset Pop", ru = "Закатный поп" },
	{ id = "palette_ocean_glass", en = "Ocean Glass", ru = "Океанское стекло" },
	{ id = "palette_mint_lilac", en = "Mint Lilac", ru = "Мята и сирень" },
	{ id = "palette_ember_gold", en = "Ember Gold", ru = "Золото углей" },
	{ id = "palette_moonberry", en = "Moonberry", ru = "Лунная ягода" },
	{ id = "palette_candy_voltage", en = "Candy Voltage", ru = "Сладкий заряд" },
	{ id = "palette_aurora_ice", en = "Aurora Ice", ru = "Лёд севера" },
	{ id = "palette_solar_flare", en = "Solar Flare", ru = "Солнечная вспышка" },
	{ id = "palette_velvet_night", en = "Velvet Night", ru = "Бархатная ночь" },
	{
		id = "palette_citrus_splash",
		en = "Citrus Splash",
		ru = "Цитрусовый всплеск",
	},
	{ id = "palette_rose_chrome", en = "Rose Chrome", ru = "Розовый хром" },
	{ id = "palette_forest_signal", en = "Forest Signal", ru = "Лесной сигнал" },
	{ id = "palette_bubblegum_void", en = "Bubblegum Void", ru = "Жвачка в космосе" },
	{ id = "palette_cloud_arcade", en = "Cloud Arcade", ru = "Облачная аркада" },
	{ id = "palette_mono_editorial", en = "Mono Editorial", ru = "Чёрно-белый кадр" },
	{ id = "material_smooth", en = "Clean Smooth", ru = "Чистая гладь" },
	{ id = "material_glass", en = "Prism Glass", ru = "Призм-стекло" },
	{ id = "material_neon", en = "Neon Grid", ru = "Неоновая сетка" },
	{ id = "material_fabric", en = "Soft Fabric", ru = "Мягкая ткань" },
	{
		id = "material_marble",
		en = "Polished Marble",
		ru = "Полированный мрамор",
	},
	{ id = "material_metal", en = "Brushed Metal", ru = "Шлифованный металл" },
	{ id = "material_cloud_foam", en = "Cloud Foam", ru = "Облачная пена" },
	{ id = "material_crystal_ice", en = "Crystal Ice", ru = "Кристальный лёд" },
	{ id = "material_starlight", en = "Starlight", ru = "Свет звёзд" },
	{ id = "material_sandstone", en = "Soft Sandstone", ru = "Мягкий песчаник" },
	{ id = "material_ceramic", en = "Studio Ceramic", ru = "Студийная керамика" },
	{ id = "material_hologram", en = "Hologram", ru = "Голограмма" },
	{ id = "aura_spark", en = "Soft Spark", ru = "Мягкая искра" },
	{ id = "aura_pulse", en = "Prism Pulse", ru = "Призм-импульс" },
	{ id = "aura_first_miracle", en = "First Entrance", ru = "Первый выход" },
	{ id = "aura_pixel_burst", en = "Pixel Burst", ru = "Пиксельный всплеск" },
	{ id = "aura_ribbon", en = "Ribbon Orbit", ru = "Орбита лент" },
	{ id = "aura_bubble_pop", en = "Bubble Pop", ru = "Поп-пузыри" },
	{ id = "aura_firefly", en = "Firefly Cloud", ru = "Облако светлячков" },
	{ id = "aura_prism_rain", en = "Prism Rain", ru = "Призм-дождь" },
	{ id = "aura_heart_signal", en = "Heart Signal", ru = "Сигнал-сердце" },
	{ id = "aura_comet_tail", en = "Comet Tail", ru = "Хвост кометы" },
	{ id = "aura_flower_echo", en = "Flower Echo", ru = "Цветочное эхо" },
	{ id = "aura_glitch_halo", en = "Glitch Halo", ru = "Цифровой ореол" },
	{ id = "aura_moon_mist", en = "Moon Mist", ru = "Лунный туман" },
	{ id = "aura_sunbeam", en = "Sunbeam", ru = "Солнечный луч" },
	{ id = "aura_jelly_orbit", en = "Jelly Orbit", ru = "Желейная орбита" },
	{ id = "aura_constellation", en = "Constellation", ru = "Созвездие" },
	{ id = "aura_aurora_crown", en = "Aurora Crown", ru = "Корона севера" },
	{ id = "aura_world_bloom", en = "World Bloom", ru = "Перекраска" },
	{ id = "pose_hero", en = "Open Hero", ru = "Главный кадр" },
	{ id = "pose_wave", en = "Friendly Wave", ru = "Привет" },
	{ id = "pose_peace", en = "Peace Flash", ru = "Знак мира" },
	{ id = "pose_power_step", en = "Power Step", ru = "Шаг вперёд" },
	{ id = "pose_cloud_float", en = "Cloud Float", ru = "Облачный полёт" },
	{ id = "pose_detective", en = "Prism Detective", ru = "Детектив" },
	{ id = "pose_star_point", en = "Star Point", ru = "Звёздный жест" },
	{ id = "pose_duo_mirror", en = "Duo Mirror", ru = "Зеркальный дуэт" },
	{ id = "pose_editorial_turn", en = "Editorial Turn", ru = "Поворот в кадре" },
	{ id = "pose_zero_g", en = "Zero-G Drift", ru = "Полёт в невесомости" },
	{ id = "pose_prism_vogue", en = "Prism Vogue", ru = "Призм-подиум" },
	{ id = "pose_bloom_finale", en = "Bloom Finale", ru = "Финальный выход" },
	{ id = "pose_squad_skyline", en = "Squad Skyline", ru = "Командный горизонт" },
	{ id = "accent_orbit", en = "Orbit Rings", ru = "Кольца орбиты" },
	{ id = "accent_wings", en = "Starter Wings", ru = "Крылья" },
	{ id = "accent_star_pin", en = "Star Pin", ru = "Звёздная брошь" },
	{ id = "accent_prism_wings", en = "Prism Wings", ru = "Призм-крылья" },
	{ id = "accent_cloud_bow", en = "Cloud Bow", ru = "Облачный бант" },
	{ id = "accent_flower_crown", en = "Flower Crown", ru = "Цветочная корона" },
	{ id = "accent_glitch_cape", en = "Glitch Cape", ru = "Цифровой плащ" },
	{ id = "accent_moon_satellites", en = "Moon Satellites", ru = "Лунные спутники" },
	{ id = "accent_bloom_crown", en = "Bloom Crown", ru = "Корона финала" },
}

for _, localizedName in styleNames do
	addCopy(`style.{localizedName.id}.name`, localizedName.en, localizedName.ru)
end

for key in english do
	assert(russian[key] ~= nil, `Missing Russian localization: {key}`)
end
for key in russian do
	assert(english[key] ~= nil, `Missing English localization: {key}`)
end

table.freeze(english)
table.freeze(russian)

local strings: StringTables = table.freeze({
	en = english,
	ru = russian,
})

local identifierPatterns: { [string]: string } = table.freeze({
	style = "style.%s.name",
	style_category = "style.category.%s",
	style_rarity = "style.rarity.%s",
	style_unlock = "style.unlock.%s",
	world = "brief.world.%s.name",
	world_description = "brief.world.%s.description",
	occasion = "brief.occasion.%s.name",
	occasion_description = "brief.occasion.%s.description",
	aesthetic = "brief.aesthetic.%s.name",
	aesthetic_description = "brief.aesthetic.%s.description",
	twist = "brief.twist.%s.name",
	twist_description = "brief.twist.%s.description",
	route = "run.route.%s.name",
	route_description = "run.route.%s.description",
	modifier = "run.modifier.%s.name",
	modifier_description = "run.modifier.%s.description",
	act = "run.act.%s.name",
	act_instruction = "run.act.%s.instruction",
	quality = "quality.%s",
	toast = "toast.%s",
})

local Localization = {
	DefaultLocale = DEFAULT_LOCALE,
	SupportedLocales = table.freeze({ "ru", "en" }),
	Strings = strings,
	IdentifierNamespaces = identifierPatterns,
}

local function formatTemplate(template: string, args: LocalizationArgs?): string
	if args == nil then
		return template
	end
	local formatted = string.gsub(template, "{([%w_]+)}", function(token: string): string
		local replacement = args[token]
		if replacement == nil then
			return "{" .. token .. "}"
		end
		return tostring(replacement)
	end)
	return formatted
end

local function isSafeIdentifier(id: string): boolean
	return #id > 0 and #id <= 80 and string.match(id, "^[a-zA-Z0-9_%-]+$") ~= nil
end

function Localization.NormalizeLocale(localeId: string?): LocaleCode
	if localeId == nil or localeId == "" then
		return DEFAULT_LOCALE
	end
	local prefix = string.sub(string.lower(localeId), 1, 2)
	if prefix == "en" then
		return "en"
	end
	if prefix == "ru" then
		return "ru"
	end
	return DEFAULT_LOCALE
end

function Localization.Has(localeId: string?, key: string): boolean
	local locale = Localization.NormalizeLocale(localeId)
	return strings[locale][key] ~= nil or english[key] ~= nil
end

-- Legacy API: it keeps the historical key fallback for developer diagnostics.
-- Player-facing UI should use GetPlayerText or GetIdentifier instead.
function Localization.Get(localeId: string?, key: string, args: LocalizationArgs?): string
	local locale = Localization.NormalizeLocale(localeId)
	local template = strings[locale][key] or english[key]
	if template == nil then
		return key
	end
	return formatTemplate(template, args)
end

-- Safe UI API. Missing keys resolve to authored copy, never to a raw key or ID.
function Localization.GetPlayerText(
	localeId: string?,
	key: string,
	args: LocalizationArgs?,
	fallbackKey: string?
): string
	local locale = Localization.NormalizeLocale(localeId)
	local template = strings[locale][key] or english[key]
	if template == nil and fallbackKey ~= nil then
		template = strings[locale][fallbackKey] or english[fallbackKey]
	end
	if template == nil then
		template = strings[locale]["ui.unknown"] or english["ui.unknown"]
	end
	return formatTemplate(template :: string, args)
end

-- Converts a stable technical ID into player copy through an allowlisted namespace.
-- Unknown namespaces and IDs deliberately return the generic localized fallback.
function Localization.GetIdentifier(
	localeId: string?,
	namespace: string,
	id: string,
	args: LocalizationArgs?
): string
	local pattern = identifierPatterns[namespace]
	if pattern == nil or not isSafeIdentifier(id) then
		return Localization.GetPlayerText(localeId, "ui.unknown", args)
	end
	local key = string.format(pattern, id)
	return Localization.GetPlayerText(localeId, key, args)
end

function Localization.GetBriefTitle(
	localeId: string?,
	worldId: string,
	occasionId: string,
	aestheticId: string,
	twistId: string
): string
	return Localization.GetPlayerText(localeId, "brief.title.generated", {
		world = Localization.GetIdentifier(localeId, "world", worldId),
		occasion = Localization.GetIdentifier(localeId, "occasion", occasionId),
		aesthetic = Localization.GetIdentifier(localeId, "aesthetic", aestheticId),
		twist = Localization.GetIdentifier(localeId, "twist", twistId),
	})
end

return table.freeze(Localization)
