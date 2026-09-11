--!strict

local TableUtil = {}

function TableUtil.CopyArray<T>(source: { T }): { T }
	return table.clone(source)
end

function TableUtil.CopyMap<K, V>(source: { [K]: V }): { [K]: V }
	return table.clone(source)
end

function TableUtil.Contains<T>(source: { T }, needle: T): boolean
	for _, value in source do
		if value == needle then
			return true
		end
	end
	return false
end

function TableUtil.IndexBy<T>(source: { T }, getKey: (T) -> string): { [string]: T }
	local result: { [string]: T } = {}
	for _, value in source do
		local key = getKey(value)
		assert(result[key] == nil, `Duplicate key: {key}`)
		result[key] = value
	end
	return result
end

function TableUtil.ClampInteger(value: number, minimum: number, maximum: number): number
	assert(minimum <= maximum, "minimum must not exceed maximum")
	if value ~= value then
		return minimum
	end
	return math.clamp(math.floor(value), minimum, maximum)
end

function TableUtil.StableHash(value: string): number
	local hash = 2166136261
	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

return table.freeze(TableUtil)
