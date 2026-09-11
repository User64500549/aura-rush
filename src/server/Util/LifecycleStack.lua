--!strict

local LifecycleStack = {}

export type CleanupError = {
	label: string,
	message: string,
}

export type Stack = {
	Add: (self: Stack, label: string, callback: () -> ()) -> (),
	Run: (self: Stack) -> { CleanupError },
	IsComplete: (self: Stack) -> boolean,
}

type Entry = {
	label: string,
	callback: () -> (),
}

function LifecycleStack.new(): Stack
	local entries: { Entry } = {}
	local complete = false
	local running = false
	local cachedErrors: { CleanupError } = {}

	local stack = {} :: any

	function stack:Add(label: string, callback: () -> ()): ()
		assert(not complete and not running, "cannot add cleanup after lifecycle shutdown")
		assert(type(label) == "string" and label ~= "", "cleanup label is required")
		assert(type(callback) == "function", "cleanup callback is required")
		table.insert(entries, {
			label = label,
			callback = callback,
		})
	end

	function stack:Run(): { CleanupError }
		if complete or running then
			return table.clone(cachedErrors)
		end
		running = true
		for index = #entries, 1, -1 do
			local entry = entries[index]
			local ok, message = xpcall(entry.callback, debug.traceback)
			if not ok then
				table.insert(cachedErrors, {
					label = entry.label,
					message = tostring(message),
				})
			end
		end
		table.clear(entries)
		running = false
		complete = true
		return table.clone(cachedErrors)
	end

	function stack:IsComplete(): boolean
		return complete
	end

	return stack :: Stack
end

return LifecycleStack
