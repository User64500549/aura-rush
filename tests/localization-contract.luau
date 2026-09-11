--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("AuraRushShared")

local Config = require(shared:WaitForChild("Config"))
local Localization = require(shared:WaitForChild("Localization"))
local BriefCatalog = require(shared:WaitForChild("BriefCatalog"))
local StyleCatalog = require(shared:WaitForChild("StyleCatalog"))

assert(Config.GameName == "AURA RUSH: СТИЛЬ-РЕЙД", "Russian product title changed")
assert(Config.UI.DefaultLocale == "ru", "Config UI default must be Russian")
assert(Localization.DefaultLocale == "ru", "Localization default must be Russian")
assert(Localization.NormalizeLocale(nil) == "ru", "nil locale must use the product default")
assert(Localization.NormalizeLocale("de-de") == "ru", "unsupported locale must use Russian")
assert(Localization.NormalizeLocale("en-us") == "en", "explicit English locale must stay English")

for key, value in Localization.Strings.ru do
	assert(Localization.Strings.en[key] ~= nil, "missing English fallback for " .. key)
	assert(value ~= key, "raw localization key leaked into Russian copy: " .. key)
end
for key in Localization.Strings.en do
	assert(Localization.Strings.ru[key] ~= nil, "missing Russian source copy for " .. key)
end

for _, item in StyleCatalog.GetAll() do
	assert(Localization.Has("ru", item.displayNameKey), "missing Russian item name: " .. item.id)
	assert(Localization.Has("en", item.displayNameKey), "missing English item name: " .. item.id)
	assert(
		item.Name == Localization.GetIdentifier("ru", "style", item.id),
		"unsafe legacy item name"
	)
end

for kind, entries in BriefCatalog.Axes do
	local namespace = if kind == "worlds"
		then "world"
		else if kind == "occasions"
			then "occasion"
			else if kind == "aesthetics" then "aesthetic" else "twist"
	for _, entry in entries do
		assert(Localization.Has("ru", entry.displayNameKey), "missing Russian brief axis name")
		assert(
			Localization.Has("ru", entry.descriptionKey),
			"missing Russian brief axis description"
		)
		local value = Localization.GetIdentifier("ru", namespace, entry.id)
		assert(value ~= entry.id and value ~= entry.displayNameKey, "brief axis leaked a raw ID")
	end
end

for _, id in { "kinetic_cascade", "precision_atelier", "wild_remix" } do
	assert(Localization.GetIdentifier("ru", "route", id) ~= id, "route leaked a raw ID")
	assert(Localization.GetIdentifier("ru", "route_description", id) ~= id, "route detail missing")
end
for _, id in { "mirror_current", "soft_gravity", "chromatic_echo", "living_runway" } do
	assert(Localization.GetIdentifier("ru", "modifier", id) ~= id, "modifier leaked a raw ID")
	assert(
		Localization.GetIdentifier("ru", "modifier_description", id) ~= id,
		"modifier detail missing"
	)
end
for _, id in
	{ "thread_run", "material_surf", "beat_lab", "light_loom", "prism_puzzle", "bloom_rescue" }
do
	assert(Localization.GetIdentifier("ru", "act", id) ~= id, "act leaked a raw ID")
	assert(Localization.GetIdentifier("ru", "act_instruction", id) ~= id, "act instruction missing")
end

local hostileId = "raw_server_identifier"
local safeFallback = Localization.GetIdentifier("ru", "route", hostileId)
assert(safeFallback ~= hostileId, "unknown identifier reached player UI")
assert(not string.find(safeFallback, "raw_server", 1, true), "unknown identifier was prettified")
assert(
	Localization.GetPlayerText("ru", "missing.localization.key") == "Нет данных",
	"missing player text must use an authored fallback"
)

local forbiddenRussianPhrases = {
	"раскрой потенциал",
	"погрузись",
	"стань легендой",
	"glowdust",
	"world bloom",
	"vibe contract",
	"datastore",
	"feature flag",
	"raw id",
}
for key, value in Localization.Strings.ru do
	-- Interpolation tokens are implementation details, not copy rendered to players.
	local visibleValue = string.gsub(value, "{[%w_]+}", "")
	local normalized = string.lower(visibleValue)
	for _, phrase in forbiddenRussianPhrases do
		assert(
			not string.find(normalized, phrase, 1, true),
			`forbidden player copy "{phrase}" in {key}`
		)
	end
end

print("AURA_RUSH_LOCALIZATION_" .. "CONTRACT_PASS")
