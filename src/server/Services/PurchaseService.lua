--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PurchaseService = {}

local dataService: any = nil
local analyticsService: any = nil
local productCatalog: any = nil
local remoteService: any = nil
local worldService: any = nil
local styleCatalog: any = nil
local economyService: any = nil

local function contains(values: { string }, target: string): boolean
	return table.find(values, target) ~= nil
end

local function getProduct(productId: number): (any, boolean)
	if type(productCatalog) ~= "table" then
		return nil, false
	end
	if type(productCatalog.GetDeveloperProductById) == "function" then
		local active = productCatalog.GetDeveloperProductById(productId)
		if active then
			return active, false
		end
	end
	if type(productCatalog.GetProductById) == "function" then
		local active = productCatalog.GetProductById(productId)
		if active then
			return active, false
		end
	end
	local products = productCatalog.DeveloperProducts
	if type(products) == "table" then
		for _, product in products do
			if product.id == productId and productId > 0 then
				return product, false
			end
		end
	end
	if type(productCatalog.GetRetiredDeveloperProductById) == "function" then
		local retired = productCatalog.GetRetiredDeveloperProductById(productId)
		if retired then
			return retired, true
		end
	end
	return nil, false
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not dataService.IsLoaded(player) or dataService.IsReadOnly(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product, retiredProduct = getProduct(receiptInfo.ProductId)
	if not product then
		warn("[AuraRush/Purchase] Unknown product id " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	local grant = product.grant
	if type(grant) ~= "table" or type(grant.kind) ~= "string" then
		warn("[AuraRush/Purchase] Invalid grant for product " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local kind = grant.kind
	local amount = tonumber(grant.amount) or 0
	local receipt = economyService.ApplyPaidReceipt(player, purchaseId, function(editable: any)
		local currencyDelta = 0
		local itemCount = 0
		local tokenCount = 0
		if kind == "GlowDust" then
			currencyDelta = math.max(0, math.floor(amount))
			editable.glowDust += currencyDelta
			editable.economyStats.earned += currencyDelta
		elseif kind == "ActivationToken" then
			local tokenId = tostring(grant.tokenId or "")
			assert(#tokenId > 0 and #tokenId <= 48, "Invalid activation token")
			editable.activationTokens = editable.activationTokens or {}
			tokenCount = math.max(1, math.floor(amount))
			local current =
				math.max(0, math.floor(tonumber(editable.activationTokens[tokenId]) or 0))
			-- Developer products are repeatable. Tokens therefore deliberately have
			-- no silent inventory cap: every successfully processed receipt adds value.
			editable.activationTokens[tokenId] = current + tokenCount
		elseif kind == "CosmeticBundle" then
			assert(type(grant.itemIds) == "table", "Cosmetic bundle has no item list")
			local duplicateGlowDust =
				math.max(0, math.floor(tonumber(grant.duplicateGlowDustPerItem) or 0))
			for _, itemId in grant.itemIds do
				local item = if styleCatalog and type(styleCatalog.GetById) == "function"
					then styleCatalog.GetById(itemId)
					else nil
				assert(item ~= nil, "Unknown cosmetic bundle item")
				assert(item.unlockKind ~= "Mastery", "Mastery item cannot be sold")
				local values = editable.unlocks[item.category]
				if type(values) ~= "table" then
					values = {}
					editable.unlocks[item.category] = values
				end
				if not contains(values, item.id) then
					table.insert(values, item.id)
					itemCount += 1
				else
					editable.glowDust += duplicateGlowDust
					editable.economyStats.earned += duplicateGlowDust
					currencyDelta += duplicateGlowDust
				end
			end
		elseif kind == "ServerGlowstorm" or kind == "ServerEffect" then
			-- The receipt is still deterministic; LiveOps can consume this marker later.
			editable.achievements.serverGlowstormHost = true
		else
			error("Unsupported deterministic product kind: " .. tostring(kind))
		end
		return {
			kind = kind,
			currencyDelta = currencyDelta,
			itemCount = itemCount,
			tokenCount = tokenCount,
		}
	end)
	if receipt.ok ~= true or receipt.persisted ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.alreadyApplied == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	remoteService.FireClient("ProgressUpdate", player, {
		kind = "Profile",
		profile = dataService.GetClientView(player),
	})
	if kind == "ServerGlowstorm" or kind == "ServerEffect" then
		local effectOk, effectError = pcall(function()
			worldService.TriggerGlowstorm(player.DisplayName)
			remoteService.FireAll("Toast", {
				key = "server_glowstorm",
				tone = "Success",
				from = player.DisplayName,
			})
		end)
		if not effectOk then
			warn("[AuraRush/Purchase] Glowstorm visual failed: " .. tostring(effectError))
		end
	end

	analyticsService.Log(player, "purchase_completed", tonumber(receiptInfo.CurrencySpent) or 0, {
		productKey = tostring(product.key or "unknown"),
		kind = tostring(kind),
		retired = tostring(retiredProduct),
		grantSummary = string.format(
			"currency:%d|items:%d|tokens:%d",
			math.max(0, math.floor(tonumber(receipt.result and receipt.result.currencyDelta) or 0)),
			math.max(0, math.floor(tonumber(receipt.result and receipt.result.itemCount) or 0)),
			math.max(0, math.floor(tonumber(receipt.result and receipt.result.tokenCount) or 0))
		),
	})
	local updatedProfile = dataService.GetProfile(player)
	local currencyDelta = if receipt.result
		then math.max(0, math.floor(tonumber(receipt.result.currencyDelta) or 0))
		else 0
	if type(analyticsService.Economy) == "function" and updatedProfile and currencyDelta > 0 then
		analyticsService.Economy(
			player,
			true,
			currencyDelta,
			updatedProfile.glowDust,
			"IAP",
			tostring(product.key or receiptInfo.ProductId),
			{ grantKind = tostring(kind) }
		)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService.Init(context: any): ()
	dataService = context.Services.Data
	analyticsService = context.Services.Analytics
	productCatalog = context.ProductCatalog
	remoteService = context.Services.Remote
	worldService = context.Services.World
	styleCatalog = context.StyleCatalog
	economyService = context.Services.Economy
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
