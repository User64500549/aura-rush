--!strict

local ContentProvider = game:GetService("ContentProvider")

local ProductionAssetService = {}

local manifest: any = nil
local status = {
	version = 0,
	configured = 0,
	total = 0,
	loaded = 0,
	failed = 0,
	ready = false,
	usingProceduralFallback = true,
}

local function normalizedContentId(value: any): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	local numeric = string.match(value, "^rbxassetid://(%d+)$") or string.match(value, "^(%d+)$")
	if not numeric or tonumber(numeric) == nil or tonumber(numeric) == 0 then
		return nil
	end
	return "rbxassetid://" .. numeric
end

local function configuredIds(): { string }
	local result = {}
	local seen: { [string]: boolean } = {}
	if type(manifest) ~= "table" or type(manifest.districts) ~= "table" then
		return result
	end
	for _, district in manifest.districts do
		for _, collection in { district.meshKit, district.surfaces, district.stems } do
			for _, slot in if type(collection) == "table" then collection else {} do
				local contentId = normalizedContentId(slot.assetId)
				if contentId and not seen[contentId] then
					seen[contentId] = true
					table.insert(result, contentId)
				end
			end
		end
	end
	return result
end

local function publishAttributes(root: Instance): ()
	root:SetAttribute("AssetManifestVersion", status.version)
	root:SetAttribute("ProductionAssetsConfigured", status.configured)
	root:SetAttribute("ProductionAssetsTotal", status.total)
	root:SetAttribute("ProductionAssetsLoaded", status.loaded)
	root:SetAttribute("ProductionAssetsFailed", status.failed)
	root:SetAttribute("ProductionAssetsReady", status.ready)
	root:SetAttribute("ProceduralFallbackActive", status.usingProceduralFallback)
end

function ProductionAssetService.Init(context: any): ()
	manifest = context.ProductionAssetManifest
	local readiness = if manifest and type(manifest.GetReadiness) == "function"
		then manifest.GetReadiness()
		else { configured = 0, total = 0, ready = false }
	status.version = math.max(0, math.floor(tonumber(manifest and manifest.version) or 0))
	status.configured = math.max(0, math.floor(tonumber(readiness.configured) or 0))
	status.total = math.max(0, math.floor(tonumber(readiness.total) or 0))
	status.loaded = 0
	status.failed = 0
	status.ready = readiness.ready == true
	status.usingProceduralFallback = status.ready ~= true
end

function ProductionAssetService.Preload(root: Instance?): ()
	if root then
		publishAttributes(root)
	end
	local ids = configuredIds()
	if #ids == 0 then
		return
	end
	task.spawn(function()
		for _, contentId in ids do
			local ok = pcall(ContentProvider.PreloadAsync, ContentProvider, { contentId })
			if ok then
				status.loaded += 1
			else
				status.failed += 1
			end
		end
		status.ready = status.configured == status.total and status.failed == 0
		status.usingProceduralFallback = status.ready ~= true
		if root and root.Parent then
			publishAttributes(root)
		end
	end)
end

function ProductionAssetService.GetView(): any
	return table.clone(status)
end

return ProductionAssetService
