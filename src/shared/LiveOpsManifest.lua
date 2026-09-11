--!strict

-- The genesis canvas is intentionally evergreen. Production can replace this
-- manifest through Experience Configs after staged validation and rollback tests.
local MANIFEST_VERSION = 2
local MINIMUM_CLIENT_VERSION = 1

local milestones = table.freeze({
	table.freeze({ id = "first_stroke", scope = "personal", target = 30, glowDust = 60 }),
	table.freeze({ id = "color_wave", scope = "personal", target = 100, glowDust = 140 }),
	table.freeze({ id = "living_canvas", scope = "personal", target = 250, glowDust = 300 }),
})

local districtRotation = table.freeze({
	"prism_metro",
	"cloud_bazaar",
	"moonlit_greenhouse",
	"orbital_boardwalk",
	"velvet_archive",
	"solar_cathedral",
})

local events = table.freeze({
	table.freeze({
		id = "community_canvas_genesis",
		displayNameKey = "liveops.community_canvas_genesis.name",
		descriptionKey = "liveops.community_canvas_genesis.description",
		startsAt = 0,
		endsAt = 0,
		briefModifier = "living_canvas",
		worldModifier = "chromatic_tide",
		contributionPerRound = 10,
		maximumDailyContribution = 150,
		rotationPeriodDays = 7,
		districtRotation = districtRotation,
		weeklyGoal = 50,
		milestones = milestones,
	}),
})

local function validate(config: any): (boolean, string?)
	local expectedVersion = if type(config) == "table" and type(config.LiveOps) == "table"
		then math.floor(tonumber(config.LiveOps.ManifestVersion) or MANIFEST_VERSION)
		else MANIFEST_VERSION
	if expectedVersion ~= MANIFEST_VERSION then
		return false, "manifest_version_mismatch"
	end
	local clientVersion = if type(config) == "table"
		then math.floor(tonumber(config.ClientVersion) or 0)
		else 0
	if clientVersion < MINIMUM_CLIENT_VERSION then
		return false, "client_version_too_old"
	end

	local eventIds: { [string]: boolean } = {}
	for _, event in events do
		if type(event.id) ~= "string" or event.id == "" or #event.id > 80 then
			return false, "invalid_event_id"
		end
		if eventIds[event.id] then
			return false, "duplicate_event_id"
		end
		eventIds[event.id] = true
		local startsAt = math.floor(tonumber(event.startsAt) or 0)
		local endsAt = math.floor(tonumber(event.endsAt) or 0)
		if startsAt < 0 or endsAt < 0 or (endsAt > 0 and endsAt <= startsAt) then
			return false, "invalid_event_window"
		end
		if
			math.floor(tonumber(event.contributionPerRound) or 0) <= 0
			or math.floor(tonumber(event.maximumDailyContribution) or 0) <= 0
		then
			return false, "invalid_contribution_contract"
		end
		local milestoneIds: { [string]: boolean } = {}
		local previousTarget = 0
		for _, milestone in event.milestones do
			if
				type(milestone.id) ~= "string"
				or milestone.id == ""
				or #milestone.id > 80
				or milestoneIds[milestone.id]
			then
				return false, "invalid_milestone_id"
			end
			milestoneIds[milestone.id] = true
			if milestone.scope ~= "personal" and milestone.scope ~= "global" then
				return false, "invalid_milestone_scope"
			end
			local target = math.floor(tonumber(milestone.target) or 0)
			local reward = math.floor(tonumber(milestone.glowDust) or -1)
			if target <= previousTarget or reward < 0 then
				return false, "invalid_milestone_reward"
			end
			previousTarget = target
		end
	end
	return true, nil
end

local manifest = {
	version = MANIFEST_VERSION,
	minimumClientVersion = MINIMUM_CLIENT_VERSION,
	killSwitch = false,
	events = events,
	Validate = validate,
}

return table.freeze(manifest)
