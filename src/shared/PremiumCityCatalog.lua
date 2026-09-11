--!strict

-- Data-only contract for the Remix City premium hub. The catalog deliberately
-- keeps all player-facing copy authored and Russian-first; runtime systems never
-- generate free-form text for signs or HUD.
local PremiumCityCatalog = {}

local districts = {
	{
		id = "prism_metro",
		nameRu = "Призма-метро",
		hintRu = "Скорость · сигналы",
		symbol = "01",
		accentHex = "38E8FF",
		angleDegrees = 0,
	},
	{
		id = "cloud_bazaar",
		nameRu = "Облачный квартал",
		hintRu = "Дуэты · мягкий ритм",
		symbol = "02",
		accentHex = "FFC8DD",
		angleDegrees = 60,
	},
	{
		id = "moonlit_greenhouse",
		nameRu = "Лунная оранжерея",
		hintRu = "Свет · живые ветви",
		symbol = "03",
		accentHex = "94D2BD",
		angleDegrees = 120,
	},
	{
		id = "orbital_boardwalk",
		nameRu = "Орбитальная набережная",
		hintRu = "Прыжки · фестиваль",
		symbol = "04",
		accentHex = "FFD166",
		angleDegrees = 180,
	},
	{
		id = "velvet_archive",
		nameRu = "Бархатный архив",
		hintRu = "Кадры · тайные страницы",
		symbol = "05",
		accentHex = "E0AAFF",
		angleDegrees = 240,
	},
	{
		id = "solar_cathedral",
		nameRu = "Солнечный собор",
		hintRu = "Луч · большой финал",
		symbol = "06",
		accentHex = "FF9F1C",
		angleDegrees = 300,
	},
}

local pulsePads = {
	{
		id = "flow",
		nameRu = "ПУТЬ",
		cueRu = "Проведи импульс",
		accentHex = "38E8FF",
		angleDegrees = 225,
	},
	{
		id = "beat",
		nameRu = "БИТ",
		cueRu = "Попади в пульс",
		accentHex = "FF6B8B",
		angleDegrees = 315,
	},
	{
		id = "color",
		nameRu = "ЦВЕТ",
		cueRu = "Добавь оттенок",
		accentHex = "FFF06A",
		angleDegrees = 45,
	},
	{
		id = "frame",
		nameRu = "КАДР",
		cueRu = "Закрепи момент",
		accentHex = "B58CFF",
		angleDegrees = 135,
	},
}

local pulseEvents = {
	{
		id = "neon_acceleration",
		nameRu = "Неоновый разгон",
		cueRu = "Наступай на плиты вместе с другими — разбудите Сердце города.",
		accentHex = "38E8FF",
		preferredPadId = "flow",
	},
	{
		id = "shared_beat",
		nameRu = "Общий бит",
		cueRu = "Соберите четыре роли в один ритм. Любая плита двигает волну.",
		accentHex = "FF6B8B",
		preferredPadId = "beat",
	},
	{
		id = "color_shift",
		nameRu = "Цветовой сдвиг",
		cueRu = "Подсветите площадь до старта следующего забега.",
		accentHex = "FFF06A",
		preferredPadId = "color",
	},
	{
		id = "city_frame",
		nameRu = "Городской кадр",
		cueRu = "Соберитесь у Сердца — каждый шаг добавляет часть общего кадра.",
		accentHex = "B58CFF",
		preferredPadId = "frame",
	},
	{
		id = "prism_wave",
		nameRu = "Призма-волна",
		cueRu = "Передайте сигнал по кругу и откройте все шесть цветов.",
		accentHex = "8C6CFF",
		preferredPadId = "flow",
	},
	{
		id = "warm_bloom",
		nameRu = "Тёплое сияние",
		cueRu = "Заполните шкалу без соревнования: здесь важен вклад каждого.",
		accentHex = "FF9F1C",
		preferredPadId = "color",
	},
}

-- One authored secret belongs to every district. The frames live in the shared
-- hub, so discovery never depends on a particular round winning a random vote.
-- They are optional, permanent and never time-gated.
local secretFrames = {
	{
		id = "metro_afterimage",
		worldId = "prism_metro",
		nameRu = "След экспресса",
		hintRu = "Загляни за холодный пилон",
		side = -1,
		accentHex = "38E8FF",
	},
	{
		id = "cloud_silhouette",
		worldId = "cloud_bazaar",
		nameRu = "Тень облака",
		hintRu = "Свет прячется сбоку от ворот",
		side = 1,
		accentHex = "FFC8DD",
	},
	{
		id = "lunar_leaf",
		worldId = "moonlit_greenhouse",
		nameRu = "Лунный лист",
		hintRu = "Ищи тихое зелёное мерцание",
		side = -1,
		accentHex = "94D2BD",
	},
	{
		id = "orbit_echo",
		worldId = "orbital_boardwalk",
		nameRu = "Эхо орбиты",
		hintRu = "Обойди фестивальную арку",
		side = 1,
		accentHex = "FFD166",
	},
	{
		id = "velvet_margin",
		worldId = "velvet_archive",
		nameRu = "Поля архива",
		hintRu = "Страница спрятана за рамой",
		side = -1,
		accentHex = "E0AAFF",
	},
	{
		id = "solar_flare",
		worldId = "solar_cathedral",
		nameRu = "Солнечный блик",
		hintRu = "Поймай свет с внешней стороны",
		side = 1,
		accentHex = "FF9F1C",
	},
}

local performanceBudget = {
	hubBaseParts = 480,
	worldBaseParts = 2600,
	pointLights = 24,
	hubTransparentParts = 72,
	districtTransparentParts = 100,
	transparentParts = 320,
	maximumPulseUpdatesPerSecond = 12,
}

local pulseRules = {
	baseTarget = 10,
	targetPerAdditionalPlayer = 2,
	maximumTarget = 28,
	minimumContributorsWhenAvailable = 2,
	actionCooldownSeconds = 0.8,
	eventDurationSeconds = 75,
	celebrationSeconds = 7,
	preferredPadBonus = 1,
}

for _, definition in districts do
	table.freeze(definition)
end
for _, definition in pulsePads do
	table.freeze(definition)
end
for _, definition in pulseEvents do
	table.freeze(definition)
end
for _, definition in secretFrames do
	table.freeze(definition)
end
table.freeze(districts)
table.freeze(pulsePads)
table.freeze(pulseEvents)
table.freeze(secretFrames)
table.freeze(performanceBudget)
table.freeze(pulseRules)

PremiumCityCatalog.Version = 7
PremiumCityCatalog.Districts = districts
PremiumCityCatalog.PulsePads = pulsePads
PremiumCityCatalog.PulseEvents = pulseEvents
PremiumCityCatalog.SecretFrames = secretFrames
PremiumCityCatalog.PerformanceBudget = performanceBudget
PremiumCityCatalog.PulseRules = pulseRules

function PremiumCityCatalog.GetDistrict(districtId: string): any
	for _, definition in districts do
		if definition.id == districtId then
			return definition
		end
	end
	return nil
end

function PremiumCityCatalog.GetPulseEvent(eventId: string): any
	for _, definition in pulseEvents do
		if definition.id == eventId then
			return definition
		end
	end
	return nil
end

function PremiumCityCatalog.GetSecretFrame(frameId: string): any
	for _, definition in secretFrames do
		if definition.id == frameId then
			return definition
		end
	end
	return nil
end

function PremiumCityCatalog.GetSecretFrameForWorld(worldId: string): any
	for _, definition in secretFrames do
		if definition.worldId == worldId then
			return definition
		end
	end
	return nil
end

return table.freeze(PremiumCityCatalog)
