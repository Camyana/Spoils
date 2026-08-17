local addonName, ns = ...

ns.addonName = addonName
ns.DB_VERSION = 2

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------

ns.defaults = {
	enabled       = true,
	style         = "fan",   -- "fan" | "radial" | "list"
	listGrow      = "up",    -- "up" | "down"
	listAlign     = "left",  -- "left" | "right"
	anchorMode    = "cursor",-- "cursor" | "screen"
	followCursor  = false,   -- pin cards where the loot happened
	duration      = 3.5,
	fadeTime      = 1.25,
	maxCards      = 8,
	scale         = 0.7,
	showTooltips  = true,
	minQuality    = 0,       -- Enum.ItemQuality.Poor
	showMoney     = true,
	showCurrency  = true,
	showCrafted   = true,
	playSound     = false,
	soundQuality  = 4,       -- Epic
}

--------------------------------------------------------------------------------
-- Chat message patterns
--
-- The loot globals look like "You receive loot: %sx%d." -- turn each into a Lua
-- pattern with capture groups so we can pull the link and the stack size out.
--------------------------------------------------------------------------------

local function ToPattern(global)
	if not global then return nil end
	local p = global:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
	p = p:gsub("%%%%s", "(.+)")
	p = p:gsub("%%%%d", "(%%d+)")
	return "^" .. p .. "$"
end

-- Ordered: multi-count variants must be tested before their single-item twins,
-- otherwise "(.+)" happily swallows the trailing "x5".
local ITEM_PATTERNS = {
	{ ToPattern(LOOT_ITEM_SELF_MULTIPLE),         true,  "loot"    },
	{ ToPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE),  true,  "loot"    },
	{ ToPattern(LOOT_ITEM_CREATED_SELF_MULTIPLE), true,  "crafted" },
	{ ToPattern(LOOT_ITEM_SELF),                  false, "loot"    },
	{ ToPattern(LOOT_ITEM_PUSHED_SELF),           false, "loot"    },
	{ ToPattern(LOOT_ITEM_CREATED_SELF),          false, "crafted" },
}

local CURRENCY_PATTERNS = {
	{ ToPattern(CURRENCY_GAINED_MULTIPLE),        true  },
	{ ToPattern(CURRENCY_GAINED_MULTIPLE_BONUS),  true  },
	{ ToPattern(CURRENCY_GAINED),                 false },
}

local function MatchLoot(msg, list)
	for i = 1, #list do
		local entry = list[i]
		local pattern = entry[1]
		if pattern then
			if entry[2] then
				local link, count = msg:match(pattern)
				if link then return link, tonumber(count) or 1, entry[3] end
			else
				local link = msg:match(pattern)
				if link then return link, 1, entry[3] end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Emitters
--------------------------------------------------------------------------------

local function Emit(data)
	if SpoilsDB and SpoilsDB.enabled then
		ns.Cards:Push(data)
	end
end

local QUALITY_COLORS = {
	[0] = { 0.62, 0.62, 0.62 },
	[1] = { 1.00, 1.00, 1.00 },
	[2] = { 0.12, 1.00, 0.00 },
	[3] = { 0.00, 0.44, 0.87 },
	[4] = { 0.64, 0.21, 0.93 },
	[5] = { 1.00, 0.50, 0.00 },
	[6] = { 0.90, 0.80, 0.50 },
	[7] = { 0.00, 0.80, 1.00 },
	[8] = { 0.00, 0.80, 1.00 },
}

-- Screen anchor is stored in UIParent coordinates. Unset means "never placed",
-- so fall back to a spot a little above centre rather than the bottom-left.
function ns.GetScreenAnchor()
	local x, y = SpoilsDB.anchorX, SpoilsDB.anchorY
	if not x or not y then
		x = UIParent:GetWidth() / 2
		y = UIParent:GetHeight() / 2.6
	end
	return x, y
end

function ns.GetQualityColor(quality)
	local c = QUALITY_COLORS[quality or 1] or QUALITY_COLORS[1]
	return c[1], c[2], c[3]
end

function ns.EmitItem(link, count, kind)
	local db = SpoilsDB
	if kind == "crafted" and not db.showCrafted then return end

	local item = Item:CreateFromItemLink(link)
	if item:IsItemEmpty() then return end

	item:ContinueOnItemLoad(function()
		local quality = item:GetItemQuality() or 1
		if quality < (db.minQuality or 0) then return end

		Emit({
			key      = item:GetItemID(),
			name     = item:GetItemName(),
			icon     = item:GetItemIcon(),
			quality  = quality,
			count    = count or 1,
			link     = link,
			kind     = kind or "loot",
		})
	end)
end

function ns.EmitCurrency(link, count)
	if not SpoilsDB.showCurrency then return end

	local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink
		and C_CurrencyInfo.GetCurrencyInfoFromLink(link)
	if not info then return end

	Emit({
		key     = "currency:" .. (info.currencyID or info.name or link),
		name    = info.name,
		icon    = info.iconFileID,
		quality = info.quality or 1,
		count   = count or 1,
		link    = link,
		kind    = "currency",
	})
end

function ns.EmitMoney(copper)
	if not SpoilsDB.showMoney or copper <= 0 then return end

	Emit({
		key     = "money",
		name    = GetCoinTextureString(copper),
		icon    = "Interface\\Icons\\INV_Misc_Coin_02",
		quality = 1,
		count   = 1,
		copper  = copper,
		kind    = "money",
		color   = { 1.00, 0.82, 0.25 },
	})
end

--------------------------------------------------------------------------------
-- Money parsing
--------------------------------------------------------------------------------

local function ParseMoney(msg)
	local g = tonumber(msg:match("(%d+) " .. GOLD))   or 0
	local s = tonumber(msg:match("(%d+) " .. SILVER)) or 0
	local c = tonumber(msg:match("(%d+) " .. COPPER)) or 0
	return g * 10000 + s * 100 + c
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("CHAT_MSG_CURRENCY")
f:RegisterEvent("CHAT_MSG_MONEY")

f:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loaded = ...
		if loaded ~= addonName then return end

		SpoilsDB = SpoilsDB or {}

		-- Migrations run before the default merge, while old values are still
		-- distinguishable from "never set".
		local dbVersion = SpoilsDB.dbVersion or 1
		if dbVersion < 2 then
			-- v2 re-tuned the presentation: smaller cards, pinned instead of
			-- trailing, longer fade. Pull anyone on v1 defaults onto them.
			SpoilsDB.scale        = ns.defaults.scale
			SpoilsDB.followCursor = ns.defaults.followCursor
		end
		SpoilsDB.dbVersion = ns.DB_VERSION

		for k, v in pairs(ns.defaults) do
			if SpoilsDB[k] == nil then SpoilsDB[k] = v end
		end
		ns.SetupOptions()

	elseif event == "CHAT_MSG_LOOT" then
		local msg = ...
		local link, count, kind = MatchLoot(msg, ITEM_PATTERNS)
		if link then ns.EmitItem(link, count, kind) end

	elseif event == "CHAT_MSG_CURRENCY" then
		local msg = ...
		local link, count = MatchLoot(msg, CURRENCY_PATTERNS)
		if link then ns.EmitCurrency(link, count) end

	elseif event == "CHAT_MSG_MONEY" then
		local msg = ...
		ns.EmitMoney(ParseMoney(msg))
	end
end)
