--!strict

-- Authored, catalog-only content for Remix City v6. Nothing in this registry is
-- user supplied, which keeps route sharing deterministic and moderation-safe.
local RemixCatalog = {}

local roles = {
	{
		id = "navigator",
		nameRu = "Навигатор",
		cueRu = "Читает маршрут и открывает следующий сигнал",
		accentHex = "38E8FF",
	},
	{
		id = "rhythmer",
		nameRu = "Ритмер",
		cueRu = "Держит общий пульс команды",
		accentHex = "FF6B8B",
	},
	{
		id = "colorist",
		nameRu = "Колорист",
		cueRu = "Собирает цветовую логику сцены",
		accentHex = "FFF06A",
	},
	{
		id = "director",
		nameRu = "Постановщик",
		cueRu = "Закрепляет лучшие моменты клипа",
		accentHex = "B58CFF",
	},
}

local guardians = {
	{
		id = "metro_conductor",
		worldId = "prism_metro",
		nameRu = "Дирижёр шума",
		verbRu = "Поймайте волну и сбейте помеху",
		pattern = "pulse_train",
		accentHex = "38E8FF",
	},
	{
		id = "cloud_colossus",
		worldId = "cloud_bazaar",
		nameRu = "Облачный колосс",
		verbRu = "Свяжите мягкие арки в один ритм",
		pattern = "soft_arc",
		accentHex = "FFC8DD",
	},
	{
		id = "moon_root",
		worldId = "moonlit_greenhouse",
		nameRu = "Лунный корень",
		verbRu = "Проведите свет по живым ветвям",
		pattern = "living_branch",
		accentHex = "94D2BD",
	},
	{
		id = "orbit_breaker",
		worldId = "orbital_boardwalk",
		nameRu = "Сбой орбиты",
		verbRu = "Сведите кольца в общую точку",
		pattern = "orbit_lock",
		accentHex = "FFD166",
	},
	{
		id = "archive_echo",
		worldId = "velvet_archive",
		nameRu = "Эхо архива",
		verbRu = "Соберите страницы в один кадр",
		pattern = "page_spiral",
		accentHex = "E0AAFF",
	},
	{
		id = "solar_prism",
		worldId = "solar_cathedral",
		nameRu = "Солнечная призма",
		verbRu = "Разверните лучи к центру сцены",
		pattern = "ray_fan",
		accentHex = "FF9F1C",
	},
}

local cellTemplates = {
	{
		id = "signal_gate",
		titleRu = "Сигнальные ворота",
		semantic = "collect",
		mechanicTag = "signal_gate",
		shape = "gate",
	},
	{
		id = "duet_platform",
		titleRu = "Дуэт-платформа",
		semantic = "rhythm",
		mechanicTag = "duet_lock",
		shape = "duet",
	},
	{
		id = "palette_switch",
		titleRu = "Смена палитры",
		semantic = "memory",
		mechanicTag = "palette_shift",
		shape = "prism",
	},
}

local worldOrder = {
	"prism_metro",
	"cloud_bazaar",
	"moonlit_greenhouse",
	"orbital_boardwalk",
	"velvet_archive",
	"solar_cathedral",
}

local encounterCells = {}
for worldIndex, worldId in worldOrder do
	for slot, template in cellTemplates do
		table.insert(encounterCells, {
			id = `{worldId}:{template.id}`,
			worldId = worldId,
			slot = slot,
			titleRu = template.titleRu,
			semantic = template.semantic,
			mechanicTag = template.mechanicTag,
			shape = template.shape,
			variant = worldIndex,
		})
	end
end

local seasonNodes = {}
local seasonFreeCosmetics = {
	"palette_candy_voltage",
	"material_cloud_foam",
	"aura_prism_rain",
	"pose_duo_mirror",
	"accent_flower_crown",
	"palette_aurora_ice",
	"aura_sunbeam",
	"pose_zero_g",
}
local seasonPremiumCosmetics = {
	"palette_solar_flare",
	"material_starlight",
	"aura_glitch_halo",
	"pose_editorial_turn",
	"accent_glitch_cape",
	"palette_velvet_night",
	"aura_moon_mist",
	"accent_prism_wings",
}
for node = 1, 40 do
	local week = math.ceil(node / 5)
	table.insert(seasonNodes, {
		id = `remix_city_s1_{node}`,
		week = week,
		position = node,
		xpTarget = node * 120,
		freeReward = {
			kind = if node % 5 == 0 then "style_item" else "glow_dust",
			itemId = if node % 5 == 0 then seasonFreeCosmetics[week] else nil,
			amount = if node % 5 == 0 then 1 else 25 + week * 5,
		},
		premiumReward = {
			kind = if node % 5 == 0 then "style_item" else "glow_dust",
			itemId = if node % 5 == 0 then seasonPremiumCosmetics[week] else nil,
			amount = if node % 5 == 0 then 1 else 40 + week * 5,
		},
	})
end

local roleById = {}
for _, role in roles do
	roleById[role.id] = role
	table.freeze(role)
end
local guardianByWorld = {}
for _, guardian in guardians do
	guardianByWorld[guardian.worldId] = guardian
	table.freeze(guardian)
end
local cellsByWorld = {}
for _, cell in encounterCells do
	cellsByWorld[cell.worldId] = cellsByWorld[cell.worldId] or {}
	table.insert(cellsByWorld[cell.worldId], cell)
	table.freeze(cell)
end
for _, cells in cellsByWorld do
	table.freeze(cells)
end
for _, node in seasonNodes do
	table.freeze(node.freeReward)
	table.freeze(node.premiumReward)
	table.freeze(node)
end

table.freeze(roles)
table.freeze(guardians)
table.freeze(encounterCells)
table.freeze(seasonNodes)
table.freeze(roleById)
table.freeze(guardianByWorld)
table.freeze(cellsByWorld)

RemixCatalog.Version = 6
RemixCatalog.Roles = roles
RemixCatalog.Guardians = guardians
RemixCatalog.EncounterCells = encounterCells
RemixCatalog.SeasonNodes = seasonNodes

function RemixCatalog.GetRole(roleId: string): any
	return roleById[roleId]
end

function RemixCatalog.GetGuardian(worldId: string): any
	return guardianByWorld[worldId] or guardianByWorld.prism_metro
end

function RemixCatalog.GetCellsForWorld(worldId: string): { any }
	return cellsByWorld[worldId] or cellsByWorld.prism_metro
end

return table.freeze(RemixCatalog)
