--!strict

export type RoundState =
	"Waiting"
	| "Intermission"
	| "BriefChoice"
	| "ThreadRun"
	| "BeatLab"
	| "PrismPuzzle"
	| "MixLab"
	| "Finale"
	| "Results"
	| "Cleanup"

export type StyleCategory = "palette" | "material" | "aura" | "pose" | "accent"
export type StyleRarity = "Common" | "Uncommon" | "Rare" | "Epic"
export type StyleUnlockKind = "Default" | "GlowDust" | "Mastery" | "Milestone"

export type FirstMiracleStatus = "NotStarted" | "PaletteChoice" | "Actions" | "Bloom" | "Complete"

export type FirstMiracleProfileState = {
	version: number,
	status: FirstMiracleStatus,
	sessionId: string,
	paletteId: string,
	actionIndex: number,
	startedAt: number,
	choiceExpiresAt: number,
	expiresAt: number,
	bloomStartedAt: number,
	completedAt: number,
	completionReason: string,
	skipped: boolean,
	rewardClaimed: boolean,
}

export type FirstMiracleActionRequest = {
	action: "Start" | "ChoosePalette" | "PerformAction" | "Skip",
	paletteId: string?,
	actionId: string?,
}

export type FirstMiracleState = {
	enabled: boolean,
	required: boolean,
	status: FirstMiracleStatus,
	sessionId: string,
	paletteId: string,
	actionIndex: number,
	actionTarget: number,
	remainingSeconds: number,
	choices: { any },
	actions: { any },
	bloom: any?,
	rewards: any,
	readOnly: boolean,
}

export type StyleItem = {
	Id: string,
	Category: StyleCategory,
	NameKey: string,
	Name: string,
	IsStarter: boolean,
	UnlockCost: number,
	Variant: string,
	ColorHex: string?,
	Material: string?,
	id: string,
	category: StyleCategory,
	displayNameKey: string,
	descriptionKey: string,
	rarity: StyleRarity,
	sortOrder: number,
	tags: { string },
	unlockKind: StyleUnlockKind,
	price: number?,
	masteryRequired: number?,
	colors: { string }?,
	materialName: string?,
	auraPreset: string?,
	posePreset: string?,
	accentPreset: string?,
}

export type StyleLoadout = {
	palette: string,
	material: string,
	aura: string,
	pose: string,
	accent: string,
}

export type BriefAxisKind = "world" | "occasion" | "aesthetic" | "twist"

export type BriefAxisEntry = {
	id: string,
	displayNameKey: string,
	descriptionKey: string,
	tags: { string },
}

export type Brief = {
	Id: string,
	WorldId: string,
	OccasionId: string,
	AestheticId: string,
	TwistId: string,
	TitleKey: string,
	Title: string,
	AccentHex: string,
	WorldNameKey: string,
	OccasionNameKey: string,
	AestheticNameKey: string,
	TwistNameKey: string,
	Tags: { string },
	id: string,
	worldId: string,
	occasionId: string,
	aestheticId: string,
	twistId: string,
	title: string,
	accentHex: string,
	worldName: string,
	occasionName: string,
	aestheticName: string,
	twistName: string,
	worldNameKey: string,
	occasionNameKey: string,
	aestheticNameKey: string,
	twistNameKey: string,
	tags: { string },
}

export type PlayerProgress = {
	threadCheckpoints: number,
	threadsCollected: number,
	beatHits: number,
	beatCombo: number,
	beatScore: number,
	prismSolved: boolean,
	prismAttempts: number,
	styleReady: boolean,
}

export type PlayerSettings = {
	language: string,
	reducedMotion: boolean,
	lowVfx: boolean,
	noFlashes: boolean,
	highContrast: boolean,
	largeText: boolean,
	captions: boolean,
	haptics: boolean,
	cameraShake: number,
	musicVolume: number,
	sfxVolume: number,
	ambienceVolume: number,
	onboardingComplete: boolean,
}

export type SavedLook = {
	id: string,
	name: string,
	createdAt: number,
	loadout: StyleLoadout,
}

export type ChallengeProgress = {
	threads: number,
	beatHits: number,
	beatPerfects: number,
	prismSteps: number,
	prismComplete: boolean,
	actId: string?,
	participationRatio: number?,
	backstageApprentice: boolean?,
}

export type ClientProfile = {
	glowDust: number,
	unlocks: { [StyleCategory]: { string } },
	equipped: StyleLoadout,
	savedLooks: { SavedLook },
	auraAtlas: { [string]: number },
	auraAtlasXp: { [string]: number }?,
	progression: { [string]: any }?,
	quests: { [string]: any }?,
	liveOps: { [string]: any }?,
	activationTokens: { [string]: number }?,
	postcards: { any }?,
	atelier: { [string]: any }?,
	firstMiracle: FirstMiracleProfileState?,
	remixCity: { [string]: any }?,
	photoModeUnlocks: { string }?,
	seasonProgress: number?,
	economyStats: { [string]: number }?,
	stats: { [string]: number },
	settings: { [string]: boolean | number | string },
	readOnly: boolean,
}

export type RoundResult = {
	alreadyGranted: boolean,
	glowDust: number,
	totalGlowDust: number,
	medals: { string }?,
	unlockedItemId: string?,
}

export type RoundSnapshot = {
	roundId: string,
	stateVersion: number,
	state: RoundState,
	startedAt: number,
	endsAt: number,
	serverNow: number?,
	seed: number?,
	isParticipant: boolean,
	participantCount: number?,
	participantUserIds: { number }?,
	briefChoices: { Brief },
	brief: Brief?,
	profile: ClientProfile?,
	result: RoundResult?,
	challengeProgress: ChallengeProgress?,
	briefOptions: { Brief }?,
	selectedBrief: Brief?,
	progress: ChallengeProgress?,
	loadout: StyleLoadout?,
	participationRole: string?,
	backstageApprentice: any?,
	runPlan: any?,
	currentAct: any?,
	currentActIndex: number?,
	routeChoices: { any }?,
	modifier: any?,
	auraGenome: any?,
	bloomRecipe: any?,
	requeueRequested: boolean?,
	remix: any?,
}

export type BeatSetupUpdate = {
	kind: "BeatSetup",
	startTime: number,
	interval: number,
	count: number,
	lanes: { number },
}

export type PrismSetupUpdate = {
	kind: "PrismSetup",
	sequence: { number },
	maxAttempts: number?,
}

export type ThreadProgressUpdate = {
	kind: "Thread",
	value: number,
	target: number,
}

export type BeatProgressUpdate = {
	kind: "Beat",
	value: number,
	target: number,
	quality: string?,
}

export type PrismProgressUpdate = {
	kind: "Prism",
	value: number,
	target: number,
	complete: boolean,
	reset: boolean?,
	attempts: number?,
	maxAttempts: number?,
}

export type ProfileProgressUpdate = {
	kind: "Profile",
	profile: ClientProfile,
	data: ClientProfile?,
}

export type ResultProgressUpdate = {
	kind: "Result",
	result: RoundResult,
	profile: ClientProfile,
}

export type ProgressUpdate =
	BeatSetupUpdate
	| PrismSetupUpdate
	| ThreadProgressUpdate
	| BeatProgressUpdate
	| PrismProgressUpdate
	| ProfileProgressUpdate
	| ResultProgressUpdate

export type VoteBriefRequest = {
	briefId: string,
}

export type BeatHitRequest = {
	beatIndex: number,
	sampleTime: number,
	lane: number,
}

export type SubmitPrismRequest = {
	index: number,
}

export type SetStyleRequest = {
	category: StyleCategory,
	itemId: string,
}

export type SetStyleReadyRequest = {
	ready: boolean,
}

export type UnlockStyleRequest = {
	category: string,
	itemId: string,
}

export type UpdateSettingsRequest = {
	settings: { [string]: boolean | number | string },
}

export type NominateRequest = {
	targetUserId: number,
}

export type LocalizationArgs = { [string]: string | number }
export type ToastTone = "Info" | "Success" | "Warning" | "Error"

export type ToastPayload = {
	key: string,
	tone: ToastTone?,
	args: LocalizationArgs?,
	detail: string?,
	from: string?,
}

export type BloomStartedPayload = {
	roundId: string,
	startTime: number,
	startsAt: number?,
	duration: number?,
	worldId: string,
	color: Color3,
	loadouts: { [string]: StyleLoadout },
	twistId: string?,
	aestheticId: string?,
	occasionId: string?,
	accentHex: string?,
}

export type ProfileStats = {
	roundsPlayed: number,
	finalesCompleted: number,
	bestBeatScore: number,
	threadCollectibles: number,
}

export type Profile = {
	schemaVersion: number,
	glowDust: number,
	unlocks: { [StyleCategory]: { string } },
	savedLooks: { SavedLook },
	equipped: StyleLoadout,
	auraAtlas: { [string]: number },
	auraAtlasXp: { [string]: number },
	progression: any,
	quests: any,
	liveOps: any,
	activationTokens: { [string]: number },
	postcards: { any },
	atelier: any,
	firstMiracle: FirstMiracleProfileState,
	remixCity: any,
	economyStats: { [string]: number },
	ledgers: any,
	purchaseReceipts: { [string]: boolean },
	grantLedger: { [string]: any },
	settings: PlayerSettings,
	stats: ProfileStats,
	grantedRounds: { string },
	livingCityContribution: number,
	fusedAuras: { FusedAura },
	photoModeUnlocks: { string },
	raidStats: { clears: number, bestScore: number },
	lastSeenAt: number,
}

export type LivingCityBloomTier = "Dormant" | "Stirring" | "Blooming" | "Radiant"

export type LivingCityDistrictState = {
	districtId: string,
	bloomMemory: number,
	tier: LivingCityBloomTier,
	lastContributionAt: number,
}

export type LivingCityState = {
	version: number,
	updatedAt: number,
	totalBloom: number,
	districts: { LivingCityDistrictState },
	cityBloomProgress: number,
}

export type RemoteClassName = "RemoteEvent" | "RemoteFunction"
export type RemoteDirection = "ClientToServer" | "ServerToClient"

export type RateLimitDefinition = {
	capacity: number,
	refillPerSecond: number,
}

export type RemoteDefinition = {
	name: string,
	className: RemoteClassName,
	direction: RemoteDirection,
	rateLimit: RateLimitDefinition?,
}

export type DeveloperProductGrant =
	{ kind: "GlowDust", amount: number }
	| { kind: "ServerEffect", effectId: string }
	| { kind: "ActivationToken", tokenId: string, amount: number }
	| {
		kind: "CosmeticBundle",
		bundleId: string,
		itemIds: { string },
		duplicateGlowDustPerItem: number,
	}

export type DeveloperProductDefinition = {
	key: string,
	id: number,
	displayNameKey: string,
	descriptionKey: string,
	grant: DeveloperProductGrant,
}

export type PassDefinition = {
	key: string,
	id: number,
	displayNameKey: string,
	descriptionKey: string,
	benefits: { string },
}

export type SubscriptionDefinition = {
	key: string,
	id: string,
	displayNameKey: string,
	descriptionKey: string,
	benefits: { string },
}

local Types = {}

return table.freeze(Types)
