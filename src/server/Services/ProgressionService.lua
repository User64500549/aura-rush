--!strict

local ProgressionService = {}

local dataService: any = nil
local economyService: any = nil
local styleCatalog: any = nil

local MAX_CREATIVE_RANK = 100
local MAX_SCHOOL_LEVEL = 20

local SCHOOLS = { "Color", "Texture", "Motion", "Camera", "SetDesign" }
local SCHOOL_BY_CATEGORY: { [string]: string } = {
	palette = "Color",
	material = "Texture",
	aura = "Motion",
	pose = "Camera",
	accent = "SetDesign",
}

local function contains(values: { string }, target: string): boolean
	for _, value in values do
		if value == target then
			return true
		end
	end
	return false
end

local function creativeCost(level: number): number
	return 60 + (level - 1) * 20
end

local function schoolCost(level: number): number
	return 60 + (level - 1) * 35
end

local function levelFromTotalXp(
	totalXpValue: any,
	maximumLevel: number,
	costAtLevel: (number) -> number
): (number, number)
	local remaining = math.max(0, math.floor(tonumber(totalXpValue) or 0))
	local level = 1
	while level < maximumLevel do
		local cost = costAtLevel(level)
		if remaining < cost then
			break
		end
		remaining -= cost
		level += 1
	end
	return level, remaining
end

local function totalXpForLevel(levelValue: any, costAtLevel: (number) -> number): number
	local level = math.max(1, math.floor(tonumber(levelValue) or 1))
	local total = 0
	for currentLevel = 1, level - 1 do
		total += costAtLevel(currentLevel)
	end
	return total
end

local function getUnlockKind(item: any): string
	local value = item.UnlockKind or item.unlockKind
	return if type(value) == "string" then value else ""
end

local function getCategory(item: any): string?
	local value = item.Category or item.category
	return if type(value) == "string" then string.lower(value) else nil
end

local function getItemId(item: any): string?
	local value = item.Id or item.id
	return if type(value) == "string" then value else nil
end

local function getMasteryRequired(item: any): number
	return math.clamp(
		math.floor(tonumber(item.MasteryRequired or item.masteryRequired) or 0),
		1,
		MAX_SCHOOL_LEVEL
	)
end

local function ensureProgression(profile: any): ()
	if type(profile.progression) ~= "table" then
		profile.progression = {}
	end
	profile.progression.totalCreativeXp =
		math.max(0, math.floor(tonumber(profile.progression.totalCreativeXp) or 0))
	local creativeRank, creativeXp =
		levelFromTotalXp(profile.progression.totalCreativeXp, MAX_CREATIVE_RANK, creativeCost)
	profile.progression.creativeRank = creativeRank
	profile.progression.creativeXp = creativeXp
	profile.progression.masteryUnlocks =
		math.max(0, math.floor(tonumber(profile.progression.masteryUnlocks) or 0))

	if type(profile.auraAtlas) ~= "table" then
		profile.auraAtlas = {}
	end
	if type(profile.auraAtlasXp) ~= "table" then
		profile.auraAtlasXp = {}
	end
	for _, school in SCHOOLS do
		local existingLevel =
			math.clamp(math.floor(tonumber(profile.auraAtlas[school]) or 1), 1, MAX_SCHOOL_LEVEL)
		local totalXp = math.max(
			math.floor(tonumber(profile.auraAtlasXp[school]) or 0),
			totalXpForLevel(existingLevel, schoolCost)
		)
		profile.auraAtlasXp[school] = totalXp
		local calculatedLevel = levelFromTotalXp(totalXp, MAX_SCHOOL_LEVEL, schoolCost)
		profile.auraAtlas[school] = math.max(existingLevel, calculatedLevel)
	end
end

local function unlockEligibleMasteryItems(profile: any): { string }
	local unlockedItems: { string } = {}
	if type(styleCatalog.GetAll) ~= "function" then
		return unlockedItems
	end
	for _, item in styleCatalog.GetAll() do
		if getUnlockKind(item) == "Mastery" then
			local category = getCategory(item)
			local itemId = getItemId(item)
			local school = if category then SCHOOL_BY_CATEGORY[category] else nil
			if category and itemId and school then
				local values = profile.unlocks[category]
				if type(values) ~= "table" then
					values = {}
					profile.unlocks[category] = values
				end
				if
					profile.auraAtlas[school] >= getMasteryRequired(item)
					and not contains(values, itemId)
				then
					table.insert(values, itemId)
					table.insert(unlockedItems, itemId)
					profile.ledgers.grants.mastery["item:" .. itemId] = os.time()
				end
			end
		end
	end
	profile.progression.masteryUnlocks += #unlockedItems
	return unlockedItems
end

function ProgressionService.Init(context: any): ()
	dataService = context.Services.Data
	economyService = context.Services.Economy
	styleCatalog = context.StyleCatalog
end

function ProgressionService.GetSchoolForCategory(categoryValue: string): string?
	return SCHOOL_BY_CATEGORY[string.lower(categoryValue)]
end

function ProgressionService.GetCreativeRankForXp(totalXp: number): (number, number)
	return levelFromTotalXp(totalXp, MAX_CREATIVE_RANK, creativeCost)
end

function ProgressionService.GetSchoolLevelForXp(totalXp: number): (number, number)
	return levelFromTotalXp(totalXp, MAX_SCHOOL_LEVEL, schoolCost)
end

function ProgressionService.CanUnlockItem(player: Player, item: any): (boolean, string?)
	if type(item) ~= "table" or getUnlockKind(item) ~= "Mastery" then
		return false, "not_mastery_item"
	end
	local category = getCategory(item)
	local school = if category then SCHOOL_BY_CATEGORY[category] else nil
	local profile = dataService.GetProfile(player)
	if not profile or not school then
		return false, "profile_unavailable"
	end
	local level = if type(profile.auraAtlas) == "table"
		then math.clamp(math.floor(tonumber(profile.auraAtlas[school]) or 1), 1, MAX_SCHOOL_LEVEL)
		else 1
	if level < getMasteryRequired(item) then
		return false, "mastery_required"
	end
	return true, nil
end

-- Pure profile mutation used by RewardService inside the same atomic round grant.
function ProgressionService.ApplyRoundProgress(profile: any, progress: any): any
	ensureProgression(profile)
	local threads =
		math.clamp(math.floor(tonumber(progress.threads or progress.threadCollectibles) or 0), 0, 8)
	local beats = math.clamp(math.floor(tonumber(progress.beatHits) or 0), 0, 12)
	local perfects = math.clamp(math.floor(tonumber(progress.beatPerfects) or 0), 0, beats)
	local prismComplete = progress.prismComplete == true or progress.prismSolved == true
	local styleReady = progress.styleReady == true
	local participationRatio = math.clamp(tonumber(progress.participationRatio) or 1, 0.2, 1)
	local participationBase = math.max(8, math.floor(40 * participationRatio + 0.5))
	local schoolBase = math.max(2, math.floor(8 * participationRatio + 0.5))

	local creativeXp = math.clamp(
		participationBase
			+ threads * 2
			+ beats * 2
			+ perfects
			+ (if prismComplete then 15 else 0)
			+ (if styleReady then 5 else 0),
		participationBase,
		120
	)
	local schoolGains = {
		Color = schoolBase + (if prismComplete then 18 else 0),
		Texture = schoolBase + threads * 3,
		Motion = schoolBase + beats + perfects * 2,
		Camera = schoolBase + 2 + (if styleReady then 16 else 0),
		SetDesign = schoolBase + math.floor((threads + beats) / 3) + (if prismComplete
			then 8
			else 0),
	}

	profile.progression.totalCreativeXp += creativeXp
	local creativeRank, currentCreativeXp =
		levelFromTotalXp(profile.progression.totalCreativeXp, MAX_CREATIVE_RANK, creativeCost)
	profile.progression.creativeRank = creativeRank
	profile.progression.creativeXp = currentCreativeXp
	profile.seasonProgress = math.max(0, math.floor(tonumber(profile.seasonProgress) or 0))
		+ creativeXp

	local levelsBefore = {}
	for _, school in SCHOOLS do
		levelsBefore[school] = profile.auraAtlas[school]
		profile.auraAtlasXp[school] += schoolGains[school]
		local level = levelFromTotalXp(profile.auraAtlasXp[school], MAX_SCHOOL_LEVEL, schoolCost)
		profile.auraAtlas[school] = level
	end

	local unlockedItemIds = unlockEligibleMasteryItems(profile)
	return {
		creativeXp = creativeXp,
		creativeRank = creativeRank,
		creativeXpInRank = currentCreativeXp,
		schoolGains = schoolGains,
		schoolLevels = table.clone(profile.auraAtlas),
		schoolLevelsBefore = levelsBefore,
		unlockedItemIds = unlockedItemIds,
	}
end

function ProgressionService.GrantRound(player: Player, roundId: string, progress: any): any
	return economyService.GrantCurrency(
		player,
		"system",
		"progression:" .. roundId,
		0,
		function(profile: any)
			return ProgressionService.ApplyRoundProgress(profile, progress)
		end
	)
end

-- Pure, non-yielding mutation for services that must bundle Atlas XP with another
-- idempotent profile grant in the same transaction.
function ProgressionService.ApplySchoolXp(profile: any, school: string, amountValue: number): any
	if not table.find(SCHOOLS, school) then
		return { ok = false, reason = "invalid_school" }
	end
	local amount = math.clamp(math.floor(tonumber(amountValue) or 0), 0, 10_000)
	ensureProgression(profile)
	profile.auraAtlasXp[school] += amount
	local level, xpInLevel =
		levelFromTotalXp(profile.auraAtlasXp[school], MAX_SCHOOL_LEVEL, schoolCost)
	profile.auraAtlas[school] = level
	return {
		ok = true,
		school = school,
		xp = amount,
		level = level,
		xpInLevel = xpInLevel,
		unlockedItemIds = unlockEligibleMasteryItems(profile),
	}
end

function ProgressionService.GrantSchoolXp(
	player: Player,
	school: string,
	amountValue: number,
	grantId: string
): any
	if not table.find(SCHOOLS, school) then
		return { ok = false, reason = "invalid_school" }
	end
	local amount = math.clamp(math.floor(tonumber(amountValue) or 0), 0, 10_000)
	return economyService.GrantCurrency(
		player,
		"mastery",
		"school:" .. school .. ":" .. grantId,
		0,
		function(profile: any)
			return ProgressionService.ApplySchoolXp(profile, school, amount)
		end
	)
end

function ProgressionService.EnsureMasteryUnlocks(player: Player): { string }
	local unlockedItems: { string } = {}
	dataService.Update(player, function(profile: any)
		ensureProgression(profile)
		unlockedItems = unlockEligibleMasteryItems(profile)
	end)
	return unlockedItems
end

function ProgressionService.GetPlayerView(player: Player): any
	local profile = dataService.GetProfile(player)
	if not profile then
		return nil
	end
	return {
		creativeRank = profile.progression.creativeRank,
		creativeXp = profile.progression.creativeXp,
		totalCreativeXp = profile.progression.totalCreativeXp,
		auraAtlas = table.clone(profile.auraAtlas),
		auraAtlasXp = table.clone(profile.auraAtlasXp),
		masteryUnlocks = profile.progression.masteryUnlocks,
	}
end

return ProgressionService
