--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local EconomyService = {}

local dataService: any = nil
local receiptStore: any = nil

local MAX_TRANSACTION_AMOUNT = 1_000_000_000
local MAX_TRANSACTION_ID_LENGTH = 160
local MAX_RECEIPT_ARCHIVE_KEY_LENGTH = 48
local RECEIPT_STORE_NAME = "AuraRush_PaidReceipts_v1"

local LEDGER_KEYS: { [string]: string } = {
	round = "rounds",
	rounds = "rounds",
	event = "events",
	events = "events",
	quest = "quests",
	quests = "quests",
	mastery = "mastery",
	system = "system",
}

local function normalizeId(value: any): string?
	if type(value) ~= "string" or value == "" or #value > MAX_TRANSACTION_ID_LENGTH then
		return nil
	end
	return value
end

local function normalizeAmount(value: any): number?
	local amount = tonumber(value)
	if amount == nil or amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil
	end
	amount = math.floor(amount)
	if amount < 0 or amount > MAX_TRANSACTION_AMOUNT then
		return nil
	end
	return amount
end

local function contains(values: { string }, target: string): boolean
	for _, value in values do
		if value == target then
			return true
		end
	end
	return false
end

local function ensureLedger(profile: any, ledgerKey: string): any
	if type(profile.ledgers) ~= "table" then
		profile.ledgers = {}
	end
	if type(profile.ledgers.grants) ~= "table" then
		profile.ledgers.grants = {}
	end
	if type(profile.ledgers.grants[ledgerKey]) ~= "table" then
		profile.ledgers.grants[ledgerKey] = {}
	end
	return profile.ledgers.grants[ledgerKey]
end

local function countKeys(value: any): number
	if type(value) ~= "table" then
		return 0
	end
	local count = 0
	for _ in value do
		count += 1
	end
	return count
end

local function receiptArchiveKey(purchaseId: string): string?
	if #purchaseId > MAX_RECEIPT_ARCHIVE_KEY_LENGTH then
		return nil
	end
	return "r:" .. purchaseId
end

local function readArchivedReceipt(purchaseId: string, userId: number): (boolean, boolean, string?)
	if not receiptStore then
		return true, false, nil
	end
	local key = receiptArchiveKey(purchaseId)
	if not key then
		-- Unusually long legacy IDs stay in the profile ledger. They are never
		-- truncated without a durable replacement.
		return true, false, nil
	end
	local ok, record = pcall(function()
		return receiptStore:GetAsync(key)
	end)
	if not ok then
		return false, false, "receipt_archive_unavailable"
	end
	if record == nil then
		return true, false, nil
	end
	if type(record) ~= "table" or math.floor(tonumber(record.userId) or 0) ~= userId then
		return false, false, "receipt_archive_conflict"
	end
	return true, true, nil
end

local function archiveReceipt(purchaseId: string, userId: number): (boolean, string?)
	if not receiptStore then
		return false, "receipt_archive_disabled"
	end
	local key = receiptArchiveKey(purchaseId)
	if not key then
		return false, "receipt_id_too_long"
	end
	local conflict = false
	local ok = pcall(function()
		receiptStore:UpdateAsync(key, function(current: any)
			if current ~= nil then
				if
					type(current) ~= "table"
					or math.floor(tonumber(current.userId) or 0) ~= userId
				then
					conflict = true
				end
				return current
			end
			return {
				userId = userId,
				processedAt = os.time(),
				version = 1,
			}
		end)
	end)
	if not ok or conflict then
		return false,
			if conflict then "receipt_archive_conflict" else "receipt_archive_write_failed"
	end
	return true, nil
end

local function compactArchivedReceipt(player: Player, purchaseId: string): ()
	local updated = dataService.Update(player, function(profile: any)
		if type(profile.ledgers) ~= "table" or type(profile.ledgers.paidReceipts) ~= "table" then
			return
		end
		profile.ledgers.paidReceipts[purchaseId] = nil
		profile.purchaseReceipts = profile.ledgers.paidReceipts
	end)
	if updated and not dataService.Save(player) then
		warn("[AuraRush/Economy] Archived receipt profile compaction deferred")
	end
end

function EconomyService.Init(context: any): ()
	dataService = context.Services.Data
	receiptStore = nil
	if not RunService:IsStudio() and game.GameId ~= 0 then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(RECEIPT_STORE_NAME)
		end)
		if ok then
			receiptStore = store
		else
			warn("[AuraRush/Economy] Receipt archive unavailable; using profile ledger")
		end
	end
end

function EconomyService.GetBalance(player: Player): number
	local profile = dataService.GetProfile(player)
	return if profile then math.max(0, math.floor(tonumber(profile.glowDust) or 0)) else 0
end

function EconomyService.HasGrant(player: Player, grantKind: string, grantId: string): boolean
	local ledgerKey = LEDGER_KEYS[string.lower(grantKind)]
	if not ledgerKey or not normalizeId(grantId) then
		return false
	end
	return dataService.HasGrant(player, ledgerKey, grantId)
end

-- Applies currency and related progression inside one non-yielding profile mutation.
-- `mutator` is server-only and must not yield. A duplicate grant never calls it.
function EconomyService.GrantCurrency(
	player: Player,
	grantKind: string,
	grantIdValue: string,
	amountValue: number,
	mutator: ((any) -> any)?
): any
	local ledgerKey = LEDGER_KEYS[string.lower(grantKind)]
	local grantId = normalizeId(grantIdValue)
	local amount = normalizeAmount(amountValue)
	if not ledgerKey or not grantId or amount == nil then
		return {
			ok = false,
			reason = "invalid_transaction",
			balance = EconomyService.GetBalance(player),
		}
	end

	local granted = false
	local callbackResult: any = nil
	local updated = dataService.Update(player, function(profile: any)
		local ledger = ensureLedger(profile, ledgerKey)
		if ledger[grantId] ~= nil then
			return
		end
		ledger[grantId] = os.time()
		if ledgerKey == "rounds" then
			if type(profile.grantedRounds) ~= "table" then
				profile.grantedRounds = {}
			end
			if not contains(profile.grantedRounds, grantId) then
				table.insert(profile.grantedRounds, grantId)
			end
		end
		profile.glowDust = math.max(0, math.floor(tonumber(profile.glowDust) or 0)) + amount
		if type(profile.economyStats) ~= "table" then
			profile.economyStats = { earned = 0, spent = 0 }
		end
		profile.economyStats.earned = math.max(
			0,
			math.floor(tonumber(profile.economyStats.earned) or 0)
		) + amount
		if mutator then
			callbackResult = mutator(profile)
		end
		granted = true
	end)

	local balance = EconomyService.GetBalance(player)
	if not updated then
		return { ok = false, reason = "profile_unavailable", balance = balance }
	end
	if not granted then
		return { ok = true, alreadyApplied = true, amount = 0, balance = balance }
	end
	return {
		ok = true,
		alreadyApplied = false,
		amount = amount,
		balance = balance,
		result = callbackResult,
		readOnly = dataService.IsReadOnly(player),
	}
end

function EconomyService.SpendCurrency(
	player: Player,
	transactionIdValue: string,
	amountValue: number,
	mutator: ((any) -> any)?
): any
	local transactionId = normalizeId(transactionIdValue)
	local amount = normalizeAmount(amountValue)
	if not transactionId or amount == nil or amount <= 0 then
		return {
			ok = false,
			reason = "invalid_transaction",
			balance = EconomyService.GetBalance(player),
		}
	end

	local applied = false
	local alreadyApplied = false
	local insufficient = false
	local callbackResult: any = nil
	local updated = dataService.Update(player, function(profile: any)
		if type(profile.ledgers) ~= "table" then
			profile.ledgers = {}
		end
		if type(profile.ledgers.spends) ~= "table" then
			profile.ledgers.spends = {}
		end
		if profile.ledgers.spends[transactionId] ~= nil then
			alreadyApplied = true
			return
		end
		local balance = math.max(0, math.floor(tonumber(profile.glowDust) or 0))
		if balance < amount then
			insufficient = true
			return
		end
		profile.glowDust = balance - amount
		profile.ledgers.spends[transactionId] = os.time()
		if type(profile.economyStats) ~= "table" then
			profile.economyStats = { earned = 0, spent = 0 }
		end
		profile.economyStats.spent = math.max(
			0,
			math.floor(tonumber(profile.economyStats.spent) or 0)
		) + amount
		if mutator then
			callbackResult = mutator(profile)
		end
		applied = true
	end)

	local balance = EconomyService.GetBalance(player)
	if not updated then
		return { ok = false, reason = "profile_unavailable", balance = balance }
	end
	if insufficient then
		return { ok = false, reason = "not_enough_glowdust", balance = balance }
	end
	if alreadyApplied then
		return { ok = true, alreadyApplied = true, amount = 0, balance = balance }
	end
	if not applied then
		return { ok = false, reason = "transaction_rejected", balance = balance }
	end
	return {
		ok = true,
		alreadyApplied = false,
		amount = amount,
		balance = balance,
		result = callbackResult,
		readOnly = dataService.IsReadOnly(player),
	}
end

-- Future PurchaseService integration point. The caller must return
-- NotProcessedYet unless this method reports both `ok` and `persisted`.
function EconomyService.ApplyPaidReceipt(
	player: Player,
	purchaseIdValue: string,
	mutator: (any) -> any
): any
	local purchaseId = normalizeId(purchaseIdValue)
	if not purchaseId or type(mutator) ~= "function" or dataService.IsReadOnly(player) then
		return { ok = false, persisted = false, reason = "invalid_receipt" }
	end
	local current = dataService.GetProfile(player)
	if
		current
		and type(current.ledgers) == "table"
		and type(current.ledgers.paidReceipts) == "table"
		and current.ledgers.paidReceipts[purchaseId] == true
	then
		local persisted = dataService.Save(player)
		local archived = false
		local archiveReason: string? = nil
		if persisted and receiptStore then
			archived, archiveReason = archiveReceipt(purchaseId, player.UserId)
			if archived then
				compactArchivedReceipt(player, purchaseId)
			end
		end
		return {
			ok = persisted,
			persisted = persisted,
			alreadyApplied = true,
			archived = archived,
			archiveReason = archiveReason,
			reason = if persisted then nil else "persist_failed",
		}
	end
	local archiveReadable, archived, archiveReason = readArchivedReceipt(purchaseId, player.UserId)
	if not archiveReadable then
		return { ok = false, persisted = false, reason = archiveReason }
	end
	if archived then
		return { ok = true, persisted = true, alreadyApplied = true, archived = true }
	end

	local applied = false
	local alreadyApplied = false
	local callbackResult: any = nil
	local updated = dataService.Update(player, function(profile: any)
		if type(profile.ledgers.paidReceipts) ~= "table" then
			profile.ledgers.paidReceipts = {}
		end
		if profile.ledgers.paidReceipts[purchaseId] == true then
			alreadyApplied = true
			return
		end
		callbackResult = mutator(profile)
		profile.ledgers.paidReceipts[purchaseId] = true
		profile.purchaseReceipts = profile.ledgers.paidReceipts
		applied = true
	end)
	if not updated then
		return { ok = false, persisted = false, reason = "profile_unavailable" }
	end
	local persisted = dataService.Save(player)
	local receiptArchived = false
	local receiptArchiveReason: string? = nil
	if persisted and applied and receiptStore then
		receiptArchived, receiptArchiveReason = archiveReceipt(purchaseId, player.UserId)
		if receiptArchived then
			compactArchivedReceipt(player, purchaseId)
		else
			warn(
				"[AuraRush/Economy] Receipt remains in profile ledger: "
					.. tostring(receiptArchiveReason)
			)
		end
	end
	return {
		ok = persisted and (applied or alreadyApplied),
		persisted = persisted,
		alreadyApplied = alreadyApplied,
		archived = receiptArchived,
		archiveReason = receiptArchiveReason,
		result = callbackResult,
		reason = if persisted then nil else "persist_failed",
	}
end

function EconomyService.GetAuditView(player: Player): any
	local profile = dataService.GetProfile(player)
	if not profile then
		return nil
	end
	local grants = profile.ledgers.grants
	return {
		balance = EconomyService.GetBalance(player),
		earned = profile.economyStats.earned,
		spent = profile.economyStats.spent,
		grantCounts = {
			rounds = countKeys(grants.rounds),
			events = countKeys(grants.events),
			quests = countKeys(grants.quests),
			mastery = countKeys(grants.mastery),
		},
	}
end

return EconomyService
