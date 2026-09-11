--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AppModule = require(script.Parent.Parent.UI.App)
local RemoteRegistryModule = require(script.Parent.RemoteRegistry)
local Localization =
	require(ReplicatedStorage:WaitForChild("AuraRushShared"):WaitForChild("Localization"))

type App = AppModule.App
type StyleOption = AppModule.StyleOption
type RemoteRegistry = RemoteRegistryModule.RemoteRegistry
type AnyMap = { [string]: any }
type Change = {
	category: string,
	before: string,
	after: string,
}

local StyleController = {}
StyleController.__index = StyleController

export type StyleController = typeof(setmetatable(
	{} :: {
		App: App,
		Remotes: RemoteRegistry,
		Catalog: { [string]: { StyleOption } },
		Loadout: { [string]: string },
		History: { Change },
		Future: { Change },
		Profile: AnyMap?,
		Random: Random,
	},
	StyleController
))

local CATEGORY_ORDER = { "palette", "material", "aura", "pose", "accent" }
local VALID_CATEGORY = table.freeze({
	palette = true,
	material = true,
	aura = true,
	pose = true,
	accent = true,
})

local DEFAULT_LOADOUT = table.freeze({
	palette = "palette_prism",
	material = "material_smooth",
	aura = "aura_spark",
	pose = "pose_hero",
	accent = "accent_orbit",
})

local FALLBACK: { [string]: { { string } } } = {
	palette = {
		{ "palette_prism", "Призм-поп", "4DEAFF" },
		{ "palette_biolume", "Живой свет", "B9FF66" },
		{ "palette_plush_punk", "Плюш-панк", "FF4FD8" },
		{ "palette_retro_signal", "Ретро-сигнал", "FF9A5A" },
		{ "palette_glass_gothic", "Стеклянная готика", "8C6CFF" },
		{ "palette_cloud_prep", "Облачный преппи", "E9F7FF" },
		{ "palette_solar_utility", "Солнечный утилити", "FFD166" },
		{ "palette_lagoon_night", "Ночная лагуна", "2A9DCE" },
		{ "palette_rose_window", "Розовый витраж", "F497C0" },
		{ "palette_arcade_mint", "Аркадная мята", "5AF2A8" },
		{ "palette_comet_berry", "Кометная ягода", "B46CFF" },
		{ "palette_moon_peach", "Лунный персик", "FFB38A" },
	},
	material = {
		{ "material_smooth", "Гладкая", "AAB4D6" },
		{ "material_prism_glass", "Призм-стекло", "BEEFFF" },
		{ "material_soft_plush", "Мягкий плюш", "F6A9DB" },
		{ "material_signal_chrome", "Сигнальный хром", "D3DCF4" },
		{ "material_cloud_knit", "Облачный трикотаж", "F5F1DB" },
		{ "material_solar_canvas", "Солнечный канвас", "E8A858" },
		{ "material_biolume_leaf", "Светящийся лист", "8FD878" },
		{ "material_cathedral_ink", "Чернильный бархат", "493E72" },
	},
	aura = {
		{ "aura_spark", "Мягкие искры", "4DEAFF" },
		{ "aura_biolume_spores", "Светящаяся пыльца", "B9FF66" },
		{ "aura_prism_ribbons", "Призм-ленты", "8C6CFF" },
		{ "aura_plush_stitches", "Плюшевые стежки", "FF4FD8" },
		{ "aura_signal_scanline", "Скан-линия", "FF9A5A" },
		{ "aura_cathedral_shards", "Витражные осколки", "A991FF" },
		{ "aura_cloud_petals", "Облачные лепестки", "E9F7FF" },
		{ "aura_solar_flares", "Солнечные блики", "FFD166" },
		{ "aura_orbit_sparks", "Орбитальные искры", "5AF2A8" },
		{ "aura_rain_glyphs", "Знаки дождя", "48BFE3" },
		{ "aura_echo_silhouette", "Эхо-силуэт", "D55DFF" },
		{ "aura_constellation", "Созвездие", "F7F8FF" },
	},
	pose = {
		{ "pose_hero", "Главный кадр", "FFD166" },
		{ "pose_prism_poised", "Призм-стойка", "4DEAFF" },
		{ "pose_cloud_lean", "Облачный наклон", "E9F7FF" },
		{ "pose_garden_breathe", "Дыхание сада", "B9FF66" },
		{ "pose_signal_freeze", "Стоп-сигнал", "FF9A5A" },
		{ "pose_frame_snap", "Щелчок кадра", "FF4FD8" },
		{ "pose_orbit_turn", "Разворот", "8C6CFF" },
		{ "pose_bloom_reach", "Шаг к свету", "5AF2A8" },
		{ "pose_coat_flip", "Взмах пальто", "F497C0" },
		{ "pose_pixel_point", "Пиксельный жест", "4DEAFF" },
		{ "pose_stained_salute", "Витражный салют", "A991FF" },
		{ "pose_runway_stride", "Подиумный шаг", "FFD166" },
		{ "pose_zero_g_glide", "Невесомость", "E9F7FF" },
		{ "pose_beat_bounce", "Пружина в бит", "FF4FD8" },
		{ "pose_utility_march", "Утилити-марш", "FF9A5A" },
		{ "pose_mirror_frame", "Зеркальный кадр", "8C6CFF" },
		{ "pose_back_to_back", "Спина к спине", "B9FF66" },
		{ "pose_orbit_highfive", "Орбитальный хай-файв", "FFD166" },
		{ "pose_portal_pass", "Шаг в кадр", "4DEAFF" },
		{ "pose_bloom_spin", "Световой спин", "D55DFF" },
	},
	accent = {
		{ "accent_orbit", "Орбитальные кольца", "FFD166" },
		{ "accent_sprout_crown", "Корона-росток", "B9FF66" },
		{ "accent_stitch_clips", "Заколки-стежки", "FF4FD8" },
		{ "accent_signal_visor", "Сигнальный визор", "4DEAFF" },
		{ "accent_glass_halo", "Стеклянный нимб", "A991FF" },
		{ "accent_cloud_beret", "Облачный берет", "E9F7FF" },
		{ "accent_biolume_bouquet", "Светящийся букет", "5AF2A8" },
		{ "accent_plush_mic", "Плюшевый микрофон", "F497C0" },
		{ "accent_signal_camera", "Сигнальная камера", "FF9A5A" },
		{ "accent_glass_fan", "Стеклянный веер", "BEEFFF" },
		{ "accent_solar_toolkit", "Солнечный набор", "FFD166" },
		{ "accent_moth_wings", "Крылья мотылька", "D55DFF" },
	},
}

local function fromHex(value: any): Color3?
	if type(value) ~= "string" then
		return nil
	end
	local clean = string.gsub(value, "#", "")
	if #clean ~= 6 then
		return nil
	end
	local number = tonumber(clean, 16)
	if not number then
		return nil
	end
	return Color3.fromRGB(
		math.floor(number / 65536) % 256,
		math.floor(number / 256) % 256,
		number % 256
	)
end

local function humanize(value: string): string
	local category = string.match(value, "^([^_]+)_")
	local fallbacks = {
		palette = "Новая палитра",
		material = "Новая фактура",
		aura = "Новый эффект",
		pose = "Новая поза",
		accent = "Новая деталь",
	}
	return fallbacks[category] or "Новый элемент"
end

local function fallbackCatalog(): { [string]: { StyleOption } }
	local result: { [string]: { StyleOption } } = {}
	for category, rows in FALLBACK do
		local options: { StyleOption } = {}
		for _, row in rows do
			table.insert(options, {
				id = row[1],
				label = row[2],
				color = fromHex(row[3]),
				locked = false,
			})
		end
		result[category] = options
	end
	return result
end

local function moduleItems(moduleValue: any): { any }?
	if type(moduleValue) ~= "table" then
		return nil
	end
	for _, key in { "Items", "StyleItems", "items" } do
		if type(moduleValue[key]) == "table" then
			return moduleValue[key]
		end
	end
	if #moduleValue > 0 then
		return moduleValue
	end
	return nil
end

function StyleController.new(app: App, remotes: RemoteRegistry): StyleController
	local self: StyleController = setmetatable({
		App = app,
		Remotes = remotes,
		Catalog = fallbackCatalog(),
		Loadout = table.clone(DEFAULT_LOADOUT),
		History = {},
		Future = {},
		Profile = nil,
		Random = Random.new(),
	}, StyleController)

	self:_loadSharedCatalog()
	self:_pushCatalogToUi()
	self:_applyLoadout(self.Loadout)
	self.App:SetActiveStyleCategory("palette")
	self:_bindUi()
	return self
end

function StyleController._loadSharedCatalog(self: StyleController)
	local shared = ReplicatedStorage:FindFirstChild("AuraRushShared")
	local moduleScript = if shared
		then (shared:FindFirstChild("StyleCatalog") or shared:FindFirstChild("ContentCatalog"))
		else nil
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return
	end
	local ok, value = pcall(require, moduleScript)
	if not ok then
		return
	end
	local items: { any }? = nil
	if type(value) == "table" and type(value.GetAll) == "function" then
		local getOk, getResult = pcall(value.GetAll)
		if getOk and type(getResult) == "table" then
			items = getResult
		end
	end
	items = items or moduleItems(value)
	if not items then
		return
	end

	local starterByCategory: { [string]: { [string]: boolean } } = {}
	if type(value) == "table" and type(value.GetStarterUnlocks) == "function" then
		local starterOk, starterResult = pcall(value.GetStarterUnlocks)
		if starterOk and type(starterResult) == "table" then
			for category, ids in starterResult do
				if type(category) == "string" and type(ids) == "table" then
					starterByCategory[category] = {}
					for _, id in ids do
						if type(id) == "string" then
							starterByCategory[category][id] = true
						end
					end
				end
			end
		end
	end

	if type(value) == "table" and type(value.GetDefaultLoadout) == "function" then
		local defaultOk, defaultResult = pcall(value.GetDefaultLoadout)
		if defaultOk and type(defaultResult) == "table" then
			for _, category in CATEGORY_ORDER do
				if type(defaultResult[category]) == "string" then
					self.Loadout[category] = defaultResult[category]
				end
			end
		end
	end

	local normalized: { [string]: { StyleOption } } = {
		palette = {},
		material = {},
		aura = {},
		pose = {},
		accent = {},
	}
	for _, rawItem in items do
		if type(rawItem) == "table" then
			local category = rawItem.Category or rawItem.category
			local id = rawItem.Id or rawItem.id
			if type(category) == "string" and VALID_CATEGORY[category] and type(id) == "string" then
				local nameKey = `style.{id}.name`
				local localizedName = if Localization.Has(self.App.Locale, nameKey)
					then if type(Localization.GetPlayerText) == "function"
						then Localization.GetPlayerText(self.App.Locale, nameKey)
						else Localization.Get(self.App.Locale, nameKey)
					else nil
				local name = localizedName
				if not name and type(Localization.GetIdentifier) == "function" then
					name = Localization.GetIdentifier(self.App.Locale, "style", id)
				end
				local explicitStarter = rawItem.IsStarter == true or rawItem.isStarter == true
				local listedStarter = starterByCategory[category] ~= nil
					and starterByCategory[category][id] == true
				local unlockCost =
					tonumber(rawItem.UnlockCost or rawItem.unlockCost or rawItem.price)
				if unlockCost and unlockCost <= 0 then
					unlockCost = nil
				end
				table.insert(normalized[category], {
					id = id,
					label = if type(name) == "string" then name else humanize(id),
					color = fromHex(rawItem.ColorHex or rawItem.colorHex),
					locked = not explicitStarter and not listedStarter,
					cost = unlockCost,
				})
			end
		end
	end

	local foundAny = false
	for _, category in CATEGORY_ORDER do
		if #normalized[category] > 0 then
			self.Catalog[category] = normalized[category]
			foundAny = true
		end
	end
	if not foundAny then
		return
	end
end

function StyleController._isProfileUnlocked(
	self: StyleController,
	category: string,
	itemId: string
): boolean
	local profile = self.Profile
	if not profile or type(profile.unlocks) ~= "table" then
		return false
	end
	local categoryUnlocks = profile.unlocks[category]
	if type(categoryUnlocks) ~= "table" then
		return false
	end
	if categoryUnlocks[itemId] == true then
		return true
	end
	for _, unlockedId in categoryUnlocks do
		if unlockedId == itemId then
			return true
		end
	end
	return false
end

function StyleController._refreshUnlocks(self: StyleController)
	for category, options in self.Catalog do
		for _, option in options do
			if option.locked and self:_isProfileUnlocked(category, option.id) then
				option.locked = false
			end
		end
	end
	self:_pushCatalogToUi()
end

function StyleController._pushCatalogToUi(self: StyleController)
	for _, category in CATEGORY_ORDER do
		self.App:SetStyleOptions(category, self.Catalog[category] or {})
	end
end

function StyleController._findOption(
	self: StyleController,
	category: string,
	itemId: string
): StyleOption?
	local options = self.Catalog[category]
	if not options then
		return nil
	end
	for _, option in options do
		if option.id == itemId then
			return option
		end
	end
	return nil
end

function StyleController._sendSelection(self: StyleController, category: string, itemId: string)
	local remote = self.Remotes:GetEvent("SetStyle")
	if not remote then
		self.App:ShowToast("ConnectionUnavailable", "Warning")
		return
	end
	remote:FireServer({
		category = category,
		itemId = itemId,
	})
end

function StyleController._requestUnlock(self: StyleController, category: string, itemId: string)
	local remote = self.Remotes:GetEvent("UnlockStyle")
	if not remote then
		self.App:ShowToast("ConnectionUnavailable", "Warning")
		return
	end
	remote:FireServer({
		category = category,
		itemId = itemId,
	})
end

function StyleController._select(
	self: StyleController,
	category: string,
	itemId: string,
	recordHistory: boolean
)
	if not VALID_CATEGORY[category] then
		return
	end
	local option = self:_findOption(category, itemId)
	if not option or option.locked then
		return
	end
	local previous = self.Loadout[category]
	if previous == itemId then
		return
	end
	if recordHistory then
		table.insert(self.History, {
			category = category,
			before = previous,
			after = itemId,
		})
		if #self.History > 30 then
			table.remove(self.History, 1)
		end
		table.clear(self.Future)
	end
	self.Loadout[category] = itemId
	self.App:SetSelectedStyle(category, itemId, option.label)
	self:_sendSelection(category, itemId)
end

function StyleController._applyLoadout(self: StyleController, loadout: AnyMap)
	for _, category in CATEGORY_ORDER do
		local itemId = loadout[category]
		if type(itemId) == "string" then
			self.Loadout[category] = itemId
			local option = self:_findOption(category, itemId)
			self.App:SetSelectedStyle(
				category,
				itemId,
				if option then option.label else humanize(itemId)
			)
		end
	end
end

function StyleController._bindUi(self: StyleController)
	self.App:On("StyleSelection", function(category: string, itemId: string)
		if type(category) == "string" and type(itemId) == "string" then
			self:_select(category, itemId, true)
		end
	end)

	self.App:On("StyleUnlock", function(category: string, itemId: string)
		if type(category) ~= "string" or type(itemId) ~= "string" then
			return
		end
		local option = self:_findOption(category, itemId)
		if option and option.locked then
			self:_requestUnlock(category, itemId)
		end
	end)

	self.App:On("StyleUndo", function()
		local change = table.remove(self.History)
		if change then
			table.insert(self.Future, change)
			self:_select(change.category, change.before, false)
		end
	end)

	self.App:On("StyleRedo", function()
		local change = table.remove(self.Future)
		if change then
			table.insert(self.History, change)
			self:_select(change.category, change.after, false)
		end
	end)

	self.App:On("StyleRandomize", function()
		local category = self.App.State.ActiveStyleCategory :: string
		local available: { StyleOption } = {}
		for _, option in self.Catalog[category] or {} do
			if not option.locked and option.id ~= self.Loadout[category] then
				table.insert(available, option)
			end
		end
		if #available > 0 then
			local option = available[self.Random:NextInteger(1, #available)]
			self:_select(category, option.id, true)
		end
	end)

	self.App:On("SnapshotApplied", function(snapshot: AnyMap)
		local profile = if type(snapshot.profile) == "table" then snapshot.profile else nil
		if profile then
			self.Profile = profile
			self:_refreshUnlocks()
		end
		local loadout = snapshot.loadout
		if type(loadout) ~= "table" and profile then
			loadout = profile.equipped or profile.loadout or profile.styleLoadout
		end
		if type(loadout) == "table" then
			self:_applyLoadout(loadout)
		end
	end)

	self.App:On("ProfileUpdated", function(profile: AnyMap)
		self.Profile = profile
		self:_refreshUnlocks()
		local loadout = profile.equipped or profile.loadout or profile.styleLoadout
		if type(loadout) == "table" then
			self:_applyLoadout(loadout)
		end
	end)
end

return StyleController
