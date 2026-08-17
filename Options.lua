local addonName, ns = ...

local function Print(msg)
	print("|cff8fd3ffSpoils|r: " .. msg)
end

--------------------------------------------------------------------------------
-- Test loot (no item cache required -- this is what /spoils test shows off)
--------------------------------------------------------------------------------

local TEST_LOOT = {
	{ name = "Thunderfury, Blessed Blade of the Windseeker", icon = "Interface\\Icons\\INV_Sword_39",                   quality = 5, count = 1  },
	{ name = "Sulfuras, Hand of Ragnaros",                   icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras",     quality = 5, count = 1  },
	{ name = "Bloodfang Hood",                               icon = "Interface\\Icons\\INV_Helmet_41",                  quality = 4, count = 1  },
	{ name = "Felstriker",                                   icon = "Interface\\Icons\\INV_Sword_48",                   quality = 4, count = 1  },
	{ name = "Band of the Eternal Sage",                     icon = "Interface\\Icons\\INV_Jewelry_Ring_51Naxxramas",   quality = 3, count = 1  },
	{ name = "Six Demon Bag",                                icon = "Interface\\Icons\\INV_Misc_Bag_10",                quality = 3, count = 1  },
	{ name = "Verdant Sphere",                               icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_01",        quality = 2, count = 1  },
	{ name = "Runed Copper Bracers",                         icon = "Interface\\Icons\\INV_Bracer_02",                  quality = 2, count = 1  },
	{ name = "Linen Cloth",                                  icon = "Interface\\Icons\\INV_Fabric_Linen_01",            quality = 1, count = 12 },
	{ name = "Copper Ore",                                   icon = "Interface\\Icons\\INV_Ore_Copper_01",              quality = 1, count = 5  },
	{ name = "Superior Healing Potion",                      icon = "Interface\\Icons\\INV_Potion_54",                  quality = 1, count = 3  },
	{ name = "Broken Fang",                                  icon = "Interface\\Icons\\INV_Misc_Bone_01",               quality = 0, count = 2  },
}

local function RunTest(count)
	count = count or 6
	local order = {}
	for i = 1, #TEST_LOOT do order[i] = TEST_LOOT[i] end

	-- Shuffle so repeat runs look different.
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end

	for i = 1, math.min(count, #order) do
		local entry = order[i]
		C_Timer.After((i - 1) * 0.18, function()
			ns.Cards:Push({
				key     = "test:" .. entry.name,
				name    = entry.name,
				icon    = entry.icon,
				quality = entry.quality,
				count   = entry.count,
				kind    = "loot",
			})
		end)
	end

	if SpoilsDB.showMoney then
		C_Timer.After(count * 0.18, function()
			ns.EmitMoney(math.random(1, 40) * 10000 + math.random(0, 99) * 100 + math.random(0, 99))
		end)
	end
end

--------------------------------------------------------------------------------
-- Screen anchor mover
--------------------------------------------------------------------------------

local mover, moverTicker

local function GetMover()
	if mover then return mover end

	mover = CreateFrame("Frame", "SpoilsAnchorFrame", UIParent)
	mover:SetSize(180, 46)
	mover:SetFrameStrata("HIGH")
	mover:SetMovable(true)
	mover:EnableMouse(true)
	mover:SetClampedToScreen(true)
	mover:RegisterForDrag("LeftButton")
	mover:Hide()

	local bg = mover:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.07, 0.85)

	local edge = mover:CreateTexture(nil, "BORDER")
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	edge:SetColorTexture(0.56, 0.83, 1.0, 0.55)

	-- Crosshair marks the exact point cards will spawn from.
	local hLine = mover:CreateTexture(nil, "OVERLAY")
	hLine:SetSize(22, 1)
	hLine:SetPoint("CENTER")
	hLine:SetColorTexture(0.56, 0.83, 1.0, 0.9)

	local vLine = mover:CreateTexture(nil, "OVERLAY")
	vLine:SetSize(1, 22)
	vLine:SetPoint("CENTER")
	vLine:SetColorTexture(0.56, 0.83, 1.0, 0.9)

	local label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
	label:SetText("Spoils anchor |cff9d9d9d(drag, Esc to close)|r")

	mover:SetScript("OnDragStart", mover.StartMoving)
	mover:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SpoilsDB.anchorX, SpoilsDB.anchorY = self:GetCenter()
	end)

	mover:SetScript("OnHide", function()
		if moverTicker then
			moverTicker:Cancel()
			moverTicker = nil
		end
	end)

	tinsert(UISpecialFrames, "SpoilsAnchorFrame")
	return mover
end

local function ToggleMover()
	local f = GetMover()
	if f:IsShown() then
		f:Hide()
		return
	end

	-- Dragging the anchor does nothing visible in cursor mode, so switch over.
	-- A fan around a fixed point reads worse than a column, so take list with
	-- it -- but only on the way in, so a later style choice is not clobbered.
	if SpoilsDB.anchorMode ~= "screen" then
		SpoilsDB.anchorMode = "screen"
		SpoilsDB.style = "list"
		Print("switched to a |cffffd100fixed anchor|r with the |cffffd100list|r layout.")
		Print("use |cffffd100/spoils style fan|r if you want the fan back.")
	end

	local x, y = ns.GetScreenAnchor()
	f:ClearAllPoints()
	f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	f:Show()

	-- Keep sample loot flowing so you can position it against live cards.
	RunTest(4)
	moverTicker = C_Timer.NewTicker(4, function() RunTest(4) end)
end

--------------------------------------------------------------------------------
-- Settings panel
--------------------------------------------------------------------------------

local category

local function BuildSettings()
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

	category = Settings.RegisterVerticalLayoutCategory("Spoils")

	local function Get(key) return function() return SpoilsDB[key] end end
	local function Set(key) return function(v) SpoilsDB[key] = v end end

	local function Checkbox(key, label, tooltip)
		local setting = Settings.RegisterProxySetting(category, "SPOILS_" .. key,
			Settings.VarType.Boolean, label, ns.defaults[key], Get(key), Set(key))
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	local function Slider(key, label, tooltip, minV, maxV, step, formatter)
		local setting = Settings.RegisterProxySetting(category, "SPOILS_" .. key,
			Settings.VarType.Number, label, ns.defaults[key], Get(key), Set(key))
		local opts = Settings.CreateSliderOptions(minV, maxV, step)
		opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
		Settings.CreateSlider(category, setting, opts, tooltip)
	end

	local function Dropdown(key, label, tooltip, varType, entries)
		local setting = Settings.RegisterProxySetting(category, "SPOILS_" .. key,
			varType, label, ns.defaults[key], Get(key), Set(key))
		Settings.CreateDropdown(category, setting, function()
			local container = Settings.CreateControlTextContainer()
			for _, e in ipairs(entries) do container:Add(e[1], e[2]) end
			return container:GetData()
		end, tooltip)
	end

	Checkbox("enabled", "Enable Spoils", "Show animated loot cards at your cursor.")

	Dropdown("style", "Layout", "How cards arrange themselves around the anchor point.",
		Settings.VarType.String, {
			{ "fan",    "Fan (stack outward)" },
			{ "radial", "Radial burst"        },
			{ "list",   "List (single column)"},
		})

	Dropdown("listGrow", "List grows", "List layout only. Which way new rows push older ones.",
		Settings.VarType.String, {
			{ "up",   "Upward"   },
			{ "down", "Downward" },
		})

	Dropdown("listAlign", "List aligns", "List layout only. Which edge sits on the anchor point.",
		Settings.VarType.String, {
			{ "left",  "Left (icon first)" },
			{ "right", "Right (mirrored)"  },
		})

	Dropdown("anchorMode", "Anchor to", "Where cards spawn from. Use /spoils anchor to place the fixed point.",
		Settings.VarType.String, {
			{ "cursor", "Cursor"                },
			{ "screen", "Fixed screen position" },
		})

	Checkbox("followCursor", "Follow the cursor",
		"Cursor anchor only. Off by default: cards stay where the loot happened, so you can hover them.")

	Checkbox("showTooltips", "Hover for tooltips",
		"Hovering a card shows its item tooltip and holds the card open until you move away.")

	Slider("duration", "Card lifetime", "How long each card stays on screen.",
		1.5, 12, 0.5, function(v) return string.format("%.1fs", v) end)

	Slider("fadeTime", "Fade out over", "How long the card takes to fade away at the end.",
		0.3, 4, 0.05, function(v) return string.format("%.2fs", v) end)

	Slider("scale", "Card scale", "Size of the loot cards.",
		0.6, 2.0, 0.05, function(v) return string.format("%d%%", v * 100) end)

	Slider("maxCards", "Maximum cards", "Oldest cards are retired past this count.",
		3, 16, 1, function(v) return tostring(v) end)

	Dropdown("minQuality", "Minimum quality", "Hide loot below this quality.",
		Settings.VarType.Number, {
			{ 0, ITEM_QUALITY0_DESC or "Poor"      },
			{ 1, ITEM_QUALITY1_DESC or "Common"    },
			{ 2, ITEM_QUALITY2_DESC or "Uncommon"  },
			{ 3, ITEM_QUALITY3_DESC or "Rare"      },
			{ 4, ITEM_QUALITY4_DESC or "Epic"      },
			{ 5, ITEM_QUALITY5_DESC or "Legendary" },
		})

	Checkbox("showMoney",    "Show money",         "Show a card when you loot coin.")
	Checkbox("showCurrency", "Show currency",      "Show a card for currency gains.")
	Checkbox("showCrafted",  "Show crafted items", "Show a card for items you create.")
	Checkbox("playSound",    "Play a chime",       "Play a sound for epic and better loot.")

	Settings.RegisterAddOnCategory(category)
end

function ns.SetupOptions()
	BuildSettings()
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

SLASH_SPOILS1 = "/spoils"
SLASH_SPOILS2 = "/sp"

SlashCmdList.SPOILS = function(input)
	local cmd, arg = input:lower():match("^(%S*)%s*(.-)$")

	if cmd == "test" then
		RunTest(tonumber(arg))

	elseif cmd == "toggle" then
		SpoilsDB.enabled = not SpoilsDB.enabled
		Print(SpoilsDB.enabled and "enabled." or "disabled.")

	elseif cmd == "style" then
		if arg == "fan" or arg == "radial" or arg == "list" then
			SpoilsDB.style = arg
			Print("layout set to " .. arg .. ".")
		else
			Print("usage: /spoils style fan|radial|list")
		end

	elseif cmd == "anchor" then
		ToggleMover()

	elseif cmd == "cursor" then
		SpoilsDB.anchorMode = "cursor"
		if mover then mover:Hide() end
		Print("cards now spawn at your cursor.")

	elseif cmd == "clear" then
		ns.Cards:ClearAll()

	elseif cmd == "reset" then
		wipe(SpoilsDB)
		for k, v in pairs(ns.defaults) do SpoilsDB[k] = v end
		SpoilsDB.dbVersion = ns.DB_VERSION
		Print("settings reset to defaults.")

	elseif cmd == "config" or cmd == "options" then
		if category then
			Settings.OpenToCategory(category:GetID())
		end

	else
		Print("commands:")
		print("  |cffffd100/spoils test [n]|r  - preview with fake loot")
		print("  |cffffd100/spoils anchor|r    - place a fixed screen anchor")
		print("  |cffffd100/spoils cursor|r    - go back to spawning at the cursor")
		print("  |cffffd100/spoils config|r    - open settings")
		print("  |cffffd100/spoils style|r     - fan | radial")
		print("  |cffffd100/spoils toggle|r    - turn on/off")
		print("  |cffffd100/spoils clear|r     - clear cards on screen")
		print("  |cffffd100/spoils reset|r     - restore defaults")
	end
end
