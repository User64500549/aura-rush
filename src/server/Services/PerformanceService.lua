--!strict

local RunService = game:GetService("RunService")

local PerformanceService = {}

local MAX_SAMPLES = 240
local heartbeatSamples: { number } = {}
local phaseStarts: { [string]: number } = {}
local phaseSamples: { [string]: { number } } = {}
local connection: RBXScriptConnection? = nil

local function pushSample(samples: { number }, value: number): ()
	table.insert(samples, value)
	while #samples > MAX_SAMPLES do
		table.remove(samples, 1)
	end
end

local function percentile(samples: { number }, fraction: number): number
	if #samples == 0 then
		return 0
	end
	local sorted = table.clone(samples)
	table.sort(sorted)
	local index = math.clamp(math.ceil(#sorted * fraction), 1, #sorted)
	return sorted[index]
end

function PerformanceService.Init(_context: any): ()
	if connection then
		connection:Disconnect()
	end
	table.clear(heartbeatSamples)
	table.clear(phaseStarts)
	table.clear(phaseSamples)
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		pushSample(heartbeatSamples, deltaTime * 1000)
	end)
end

function PerformanceService.BeginPhase(phase: string): ()
	phaseStarts[phase] = os.clock()
end

function PerformanceService.EndPhase(phase: string): ()
	local startedAt = phaseStarts[phase]
	phaseStarts[phase] = nil
	if not startedAt then
		return
	end
	local samples = phaseSamples[phase]
	if not samples then
		samples = {}
		phaseSamples[phase] = samples
	end
	pushSample(samples, (os.clock() - startedAt) * 1000)
end

function PerformanceService.Measure<T>(label: string, callback: () -> T): T
	local startedAt = os.clock()
	local result = callback()
	local samples = phaseSamples[label]
	if not samples then
		samples = {}
		phaseSamples[label] = samples
	end
	pushSample(samples, (os.clock() - startedAt) * 1000)
	return result
end

function PerformanceService.GetSnapshot(): any
	local phases: { [string]: any } = {}
	for phase, samples in phaseSamples do
		phases[phase] = {
			count = #samples,
			p50Milliseconds = percentile(samples, 0.5),
			p95Milliseconds = percentile(samples, 0.95),
		}
	end
	return {
		heartbeatSamples = #heartbeatSamples,
		heartbeatP50Milliseconds = percentile(heartbeatSamples, 0.5),
		heartbeatP95Milliseconds = percentile(heartbeatSamples, 0.95),
		phases = phases,
	}
end

function PerformanceService.Destroy(): ()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	table.clear(heartbeatSamples)
	table.clear(phaseStarts)
	table.clear(phaseSamples)
end

return PerformanceService
