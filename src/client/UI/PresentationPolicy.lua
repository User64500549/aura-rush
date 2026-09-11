--!strict

-- One primary activity owns the screen. Background HUD must never steal its
-- controls, even when a late network snapshot arrives during that activity.
local FOCUSED_SCREENS = table.freeze({
	BriefChoice = true,
	BeatLab = true,
	PrismPuzzle = true,
	MixLab = true,
	Results = true,
})

local PresentationPolicy = {}

function PresentationPolicy.Resolve(screenName: string, modalOpen: boolean, capturing: boolean)
	local introductory = screenName == "Loading" or screenName == "Onboarding"
	local primaryOverlay = introductory or modalOpen or capturing
	return {
		topBarVisible = not primaryOverlay,
		screenVisible = not modalOpen and not capturing,
		suppressSecondaryHud = primaryOverlay or FOCUSED_SCREENS[screenName] == true,
		readOnlyVisible = not primaryOverlay,
		routeRibbonVisible = not primaryOverlay and screenName == "ThreadRun",
	}
end

return table.freeze(PresentationPolicy)
