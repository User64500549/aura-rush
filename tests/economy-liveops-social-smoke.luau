--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local shared = ReplicatedStorage:WaitForChild("AuraRushShared")
local servicesRoot = ServerScriptService:WaitForChild("AuraRushServer"):WaitForChild("Services")

local Config = require(shared:WaitForChild("Config"))
local LiveOpsManifest = require(shared:WaitForChild("LiveOpsManifest"))
local ProductCatalog = require(shared:WaitForChild("ProductCatalog"))
local EconomyService = require(servicesRoot:WaitForChild("EconomyService"))
local RewardService = require(servicesRoot:WaitForChild("RewardService"))
local QuestService = require(servicesRoot:WaitForChild("QuestService"))
local CommunityBloomService = require(servicesRoot:WaitForChild("CommunityBloomService"))
local SocialCreationService = require(servicesRoot:WaitForChild("SocialCreationService"))

local checks = 0
local function check(condition: boolean, message: string): ()
	assert(condition, "economy/liveops/social smoke failure: " .. message)
	checks += 1
end

local manifestOk, manifestReason = LiveOpsManifest.Validate(Config)
check(manifestOk, "built-in manifest rejected: " .. tostring(manifestReason))
check(
	LiveOpsManifest.version == Config.LiveOps.ManifestVersion,
	"manifest and config versions drifted"
)
local mismatchOk = LiveOpsManifest.Validate({
	ClientVersion = Config.ClientVersion,
	LiveOps = { ManifestVersion = LiveOpsManifest.version + 1 },
})
check(mismatchOk == false, "manifest version mismatch was accepted")
local oldClientOk = LiveOpsManifest.Validate({
	ClientVersion = LiveOpsManifest.minimumClientVersion - 1,
	LiveOps = { ManifestVersion = LiveOpsManifest.version },
})
check(oldClientOk == false, "obsolete client version was accepted")
check(
	type(ProductCatalog.RetiredDeveloperProducts) == "table"
		and type(ProductCatalog.GetRetiredDeveloperProductById) == "function",
	"retired receipt tombstone contract is missing"
)

local profiles: { [any]: any } = {}
local function newProfile(): any
	return {
		glowDust = 0,
		economyStats = { earned = 0, spent = 0 },
		ledgers = {
			paidReceipts = {},
			grants = { rounds = {}, events = {}, quests = {}, mastery = {}, system = {} },
			spends = {},
		},
		purchaseReceipts = {},
		grantedRounds = {},
		progression = { creativeRank = 1 },
		stats = {
			roundsPlayed = 0,
			finalesCompleted = 0,
			bestBeatScore = 0,
			threadsCollected = 0,
		},
		postcards = {},
		atelier = nil,
	}
end

local Data = {}
function Data.GetProfile(player: any): any
	return profiles[player]
end
function Data.GetClientView(player: any): any
	return profiles[player]
end
function Data.IsLoaded(player: any): boolean
	return profiles[player] ~= nil
end
function Data.IsReadOnly(_player: any): boolean
	return false
end
function Data.Update(player: any, mutator: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile)
	profile.purchaseReceipts = profile.ledgers.paidReceipts
	return true
end
function Data.Save(_player: any): boolean
	return true
end
function Data.HasGrant(player: any, grantKind: string, grantId: string): boolean
	local profile = profiles[player]
	return profile ~= nil
		and profile.ledgers.grants[grantKind] ~= nil
		and profile.ledgers.grants[grantKind][grantId] ~= nil
end

EconomyService.Init({ Services = { Data = Data } })

local analytics = {
	Log = function(_player: any, _name: string, _value: number, _fields: any): () end,
	Economy = function(
		_player: any,
		_isSource: boolean,
		_amount: number,
		_balance: number,
		_transactionType: string,
		_itemSku: string,
		_fields: any
	): ()
	end,
	ProgressionComplete = function(
		_player: any,
		_progressionName: string,
		_level: number,
		_itemId: string,
		_fields: any
	): ()
	end,
	Funnel = function(
		_player: any,
		_funnelName: string,
		_occurrenceId: string,
		_step: number,
		_stepName: string,
		_fields: any
	): ()
	end,
}
local questCalls = 0
RewardService.Init({
	Config = Config,
	Services = {
		Data = Data,
		Analytics = analytics,
		Economy = EconomyService,
		Progression = {
			ApplyRoundProgress = function(_profile: any, _progress: any): any
				return {
					creativeXp = 40,
					creativeRank = 1,
					schoolGains = {},
					schoolLevels = {},
					schoolLevelsBefore = {},
					unlockedItemIds = {},
				}
			end,
		},
		Quest = {
			RecordRound = function(_player: any, _roundId: string, _progress: any): any
				questCalls += 1
				return { result = { glowDust = 0 } }
			end,
		},
	},
})

local idlePlayer = { UserId = 101, Name = "Idle" } :: any
profiles[idlePlayer] = newProfile()
local idleResult = RewardService.GrantRound(idlePlayer, "idle-round", {
	threads = 0,
	beatHits = 0,
	beatPerfects = 0,
	prismSteps = 0,
	prismAttempts = 0,
	prismComplete = false,
	styleReady = false,
}, 1)
check(idleResult.qualified == false and idleResult.glowDust == 0, "idle round earned currency")
check(profiles[idlePlayer].stats.roundsPlayed == 0, "idle round advanced completion stats")
check(questCalls == 0, "idle round advanced quests")
check(
	profiles[idlePlayer].ledgers.grants.system["qualified_round:idle-round"] == nil,
	"idle round received a qualification marker"
)

local activePlayer = { UserId = 102, Name = "Active" } :: any
profiles[activePlayer] = newProfile()
local activeResult = RewardService.GrantRound(activePlayer, "active-round", {
	threads = 1,
	beatHits = 0,
	beatPerfects = 0,
	prismSteps = 0,
	prismAttempts = 0,
	prismComplete = false,
	styleReady = false,
}, 1)
check(activeResult.qualified == true and activeResult.glowDust > 0, "active round was rejected")
check(questCalls == 1, "qualified round did not advance quests exactly once")
check(
	profiles[activePlayer].ledgers.grants.system["qualified_round:active-round"] ~= nil,
	"qualified round marker is missing"
)

local latePlayer = { UserId = 103, Name = "Late" } :: any
profiles[latePlayer] = newProfile()
local lateResult = RewardService.GrantRound(latePlayer, "late-round", {
	threads = 0,
	beatHits = 0,
	beatPerfects = 0,
	prismSteps = 0,
	prismAttempts = 0,
	prismComplete = false,
	styleReady = false,
	backstageApprentice = true,
	participationRatio = 0.2,
}, 1)
check(
	lateResult.qualified == true and lateResult.qualificationReason == "late_join",
	"late join accessibility fallback was rejected"
)

local receiptPlayer = { UserId = 104, Name = "Receipt" } :: any
profiles[receiptPlayer] = newProfile()
local receiptMutations = 0
local firstReceipt = EconomyService.ApplyPaidReceipt(
	receiptPlayer,
	"receipt-smoke",
	function(profile)
		receiptMutations += 1
		profile.glowDust += 25
	end
)
local replayReceipt = EconomyService.ApplyPaidReceipt(
	receiptPlayer,
	"receipt-smoke",
	function(_profile)
		receiptMutations += 1
	end
)
check(firstReceipt.ok == true and replayReceipt.alreadyApplied == true, "receipt replay failed")
check(receiptMutations == 1 and profiles[receiptPlayer].glowDust == 25, "receipt granted twice")

local day = math.floor(os.time() / 86_400)
local week = math.floor(day / 7)
local questPlayer = { UserId = 105, Name = "Quest" } :: any
local questProfile = newProfile()
questProfile.quests = {
	daily = {
		day = day,
		items = {
			{
				id = "daily:current:beat",
				kind = "hit_beats",
				target = 8,
				progress = 0,
				reward = 20,
				completed = false,
				claimed = false,
			},
		},
		bank = {
			{
				day = day - 1,
				expiresDay = day + 4,
				completed = false,
				items = {
					{
						id = "daily:bank:beat",
						kind = "hit_beats",
						target = 8,
						progress = 0,
						reward = 20,
						completed = false,
						claimed = false,
					},
				},
			},
		},
		rerollsUsed = 0,
		completed = false,
	},
	weekly = { week = week, items = {}, completed = false },
	streak = { count = 0, lifetimeDays = 0, lastCompletedDay = 0, graceCredits = 1 },
	totals = { dailyCompleted = 0, weeklyCompleted = 0, glowDustEarned = 0 },
}
profiles[questPlayer] = questProfile
QuestService.Init({ Services = { Data = Data, Economy = EconomyService } })
local questTransaction =
	QuestService.RecordProgress(questPlayer, "bank-budget-smoke", { hit_beats = 8 }, os.time())
check(questTransaction.ok == true, "quest transaction failed")
check(questProfile.quests.daily.items[1].progress == 8, "current daily did not consume actions")
check(questProfile.quests.daily.bank[1].items[1].progress == 0, "banked daily copied actions")
check(questProfile.glowDust == 20, "banked daily duplicated its reward")

local claimedOverride: any = "unset"
local liveOps = {
	GetActiveEvents = function(): { any }
		return {}
	end,
	GetManifest = function(): any
		return LiveOpsManifest
	end,
	Contribute = function(
		_player: any,
		_eventId: string,
		_contributionId: string,
		amount: number
	): any
		return { ok = true, alreadyApplied = false, result = { contributed = amount } }
	end,
	ClaimMilestone = function(
		_player: any,
		_eventId: string,
		_milestoneId: string,
		override: number?
	): any
		claimedOverride = override
		return { ok = true }
	end,
}
CommunityBloomService.Init({
	Config = Config,
	LiveOpsManifest = LiveOpsManifest,
	Services = {
		Data = Data,
		Economy = EconomyService,
		Flags = {
			IsEnabled = function(_key: string): boolean
				return true
			end,
		},
		LiveOps = liveOps,
	},
})
local idleContribution =
	CommunityBloomService.Contribute(idlePlayer, "community_canvas_genesis", "idle-round", 10)
check(idleContribution.reason == "participation_unqualified", "idle Community Bloom accepted")
local activeContribution =
	CommunityBloomService.Contribute(activePlayer, "community_canvas_genesis", "active-round", 10)
check(
	activeContribution.ok == true and activeContribution.globalTotal == 10,
	"qualified Bloom failed"
)
CommunityBloomService.ClaimMilestone(activePlayer, "community_canvas_genesis", "first_stroke")
check(claimedOverride == nil, "personal milestone used global progress")
CommunityBloomService.Stop()

local boundEvents: { [string]: (any, any) -> () } = {}
local socialPlayer = { UserId = 106, Name = "Social", DisplayName = "Social" } :: any
profiles[socialPlayer] = newProfile()
SocialCreationService.Init({
	Config = Config,
	StyleCatalog = {
		GetById = function(_id: string): any
			return nil
		end,
	},
	Services = {
		Data = Data,
		Economy = EconomyService,
		Flags = {
			IsEnabled = function(_key: string): boolean
				return true
			end,
		},
		Remote = {
			BindEvent = function(name: string, _rate: number, handler: (any, any) -> ())
				boundEvents[name] = handler
			end,
			FireClient = function(_name: string, _player: any, _payload: any): () end,
			FireAll = function(_name: string, _payload: any): () end,
		},
		Analytics = analytics,
		Round = {
			GetSnapshot = function(_player: any): any
				return {
					state = "Finale",
					isParticipant = true,
					roundId = "social-round",
					brief = { Id = "brief", WorldId = "prism_metro" },
				}
			end,
			GetParticipantUserIds = function(): { number }
				return { socialPlayer.UserId, 200, 300 }
			end,
		},
		Style = {
			GetLoadout = function(_player: any): any
				return {
					palette = "palette_prism",
					material = "material_smooth",
					aura = "aura_spark",
					pose = "pose_hero",
					accent = "accent_orbit",
				}
			end,
			SetChoice = function(_player: any, _category: string, _itemId: string): boolean
				return false
			end,
		},
	},
})
check(boundEvents.PostcardAction ~= nil, "PostcardAction was not bound")
boundEvents.PostcardAction(socialPlayer, { action = "create" })
local savedPostcard = profiles[socialPlayer].postcards[1]
check(savedPostcard ~= nil and savedPostcard.participantCount == 3, "postcard count missing")
check(
	#savedPostcard.participants == 1 and savedPostcard.participants[1] == socialPlayer.UserId,
	"postcard stored non-consenting participant IDs"
)
local publicPostcard = SocialCreationService.GetRecent()[1]
check(publicPostcard ~= nil and publicPostcard.participants == nil, "public postcard leaked IDs")

print(string.format("AURA_RUSH_ECONOMY_" .. "LIVEOPS_SOCIAL_PASS (%d checks)", checks))
