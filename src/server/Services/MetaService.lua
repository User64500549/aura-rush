--!strict

local MetaService = {}

local services: any = nil

local function resultToast(player: Player, ok: boolean, successKey: string, reason: string?): ()
	services.Remote.FireClient("Toast", player, {
		key = if ok then successKey else (reason or "invalid_action"),
		tone = if ok then "Success" else "Warning",
	})
end

function MetaService.GetView(player: Player): any
	local runView = nil
	if services.Round and type(services.Round.GetSnapshot) == "function" then
		local snapshot = services.Round.GetSnapshot(player)
		if type(snapshot) == "table" then
			runView = snapshot.runPlan
		end
	end
	return {
		profile = services.Data.GetClientView(player),
		progression = if services.Progression
			then services.Progression.GetPlayerView(player)
			else nil,
		quests = if services.Quest then services.Quest.GetPlayerView(player) else nil,
		liveOps = if services.LiveOps then services.LiveOps.GetPlayerView(player) else nil,
		communityBloom = if services.Community then services.Community.GetView() else nil,
		season = if services.Remix and type(services.Remix.GetSeasonView) == "function"
			then services.Remix.GetSeasonView(player)
			else nil,
		secretFrames = if services.SecretFrames
				and type(services.SecretFrames.GetView) == "function"
			then services.SecretFrames.GetView(player)
			else nil,
		productionAssets = if services.ProductionAssets
				and type(services.ProductionAssets.GetView) == "function"
			then services.ProductionAssets.GetView()
			else nil,
		featureFlags = if services.Flags then services.Flags.GetAll() else {},
		party = if services.Party then services.Party.GetClientView(player) else nil,
		recentPostcards = if services.SocialCreation
			then services.SocialCreation.GetRecent()
			else {},
		runPlan = runView,
	}
end

function MetaService.Push(player: Player, kind: string?): ()
	services.Remote.FireClient("MetaUpdate", player, {
		kind = kind or "Snapshot",
		data = MetaService.GetView(player),
	})
end

function MetaService.Init(context: any): ()
	services = context.Services
	services.Remote.BindFunction("RequestMeta", 1, function(player: Player, _payload: any)
		return MetaService.GetView(player)
	end)
	services.Remote.BindEvent("SaveLook", 1, function(player: Player, payload: any)
		local requestedName = if type(payload) == "table"
				and type(payload.name) == "string"
			then string.sub(payload.name, 1, 24)
			else nil
		local ok, reason = services.Style.SaveLook(player, requestedName)
		resultToast(player, ok, "look_saved", reason)
		if ok then
			services.Analytics.Funnel(player, "CreativeJourney", "lookbook", 1, "Look Saved", nil)
			MetaService.Push(player, "Lookbook")
		end
	end)
	services.Remote.BindEvent("DeleteLook", 1, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.lookId) ~= "string" then
			return
		end
		local ok, reason = services.Style.DeleteLook(player, string.sub(payload.lookId, 1, 80))
		resultToast(player, ok, "look_deleted", reason)
		if ok then
			MetaService.Push(player, "Lookbook")
		end
	end)
	services.Remote.BindEvent("EquipLook", 2, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.lookId) ~= "string" then
			return
		end
		local ok, reason = services.Style.EquipSavedLook(player, string.sub(payload.lookId, 1, 80))
		resultToast(player, ok, "look_equipped", reason)
		if ok then
			MetaService.Push(player, "Lookbook")
		end
	end)
	services.Remote.BindEvent("RerollDaily", 1, function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.questId) ~= "string" or not services.Quest then
			return
		end
		local result = services.Quest.RerollDaily(player, string.sub(payload.questId, 1, 100))
		resultToast(player, result.ok == true, "quest_rerolled", result.reason)
		MetaService.Push(player, "Quests")
	end)
	services.Remote.BindEvent("ClaimQuest", 2, function(player: Player, payload: any)
		if
			type(payload) ~= "table"
			or type(payload.eventId) ~= "string"
			or type(payload.milestoneId) ~= "string"
			or not services.LiveOps
		then
			return
		end
		local eventId = string.sub(payload.eventId, 1, 80)
		local milestoneId = string.sub(payload.milestoneId, 1, 80)
		local result = if services.Community
				and type(services.Community.ClaimMilestone) == "function"
			then services.Community.ClaimMilestone(player, eventId, milestoneId)
			else services.LiveOps.ClaimMilestone(player, eventId, milestoneId)
		resultToast(player, result.ok == true, "milestone_claimed", result.reason)
		MetaService.Push(player, "LiveOps")
	end)
	services.Remote.BindEvent("ChooseRoute", 2, function(player: Player, payload: any)
		if
			type(payload) == "table"
			and type(payload.routeId) == "string"
			and services.Round
			and type(services.Round.VoteRoute) == "function"
		then
			services.Round.VoteRoute(player, string.sub(payload.routeId, 1, 80))
		end
	end)
	services.Remote.BindEvent("Requeue", 1, function(player: Player, _payload: any)
		if services.Round and type(services.Round.RequestRequeue) == "function" then
			services.Round.RequestRequeue(player)
		end
	end)
end

return MetaService
