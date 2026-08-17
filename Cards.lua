local addonName, ns = ...

local Cards = {}
ns.Cards = Cards

local UIParent, CreateFrame = UIParent, CreateFrame
local GetCursorPosition = GetCursorPosition
local sin, cos, pi, min, max, abs = math.sin, math.cos, math.pi, math.min, math.max, math.abs

--------------------------------------------------------------------------------
-- Layout constants
--------------------------------------------------------------------------------

local ICON_SIZE   = 28
local PAD         = 6
local GAP         = 7
local ROW_H       = 34
local ROW_GAP     = 4
local MAX_NAME_W  = 175
local CURSOR_GAP  = 34   -- how far the inner edge sits from the cursor (fan)
local RADIAL_R    = 52   -- starting orbit radius (radial)
local LIST_PAD    = 8    -- gap between the anchor point and the first row
local LIST_EASE   = 14   -- how hard rows are pulled toward their slot
local INTRO       = 0.30
local MIN_HOLD    = 0.45 -- fade is clamped so a card is never all fade

--------------------------------------------------------------------------------
-- Easing
--------------------------------------------------------------------------------

local function easeOutBack(p)
	local q = p - 1
	return 1 + 2.70158 * q * q * q + 1.70158 * q * q
end

local function easeOutCubic(p)
	local q = 1 - p
	return 1 - q * q * q
end

local function easeOutQuad(p)
	return 1 - (1 - p) * (1 - p)
end

--------------------------------------------------------------------------------
-- Pool / slot bookkeeping
--------------------------------------------------------------------------------

local pool, active = {}, {}
local slots = { [1] = {}, [-1] = {} }
local lastSide = -1
local driver

local function AcquireSlot(side)
	local t = slots[side]
	local i = 1
	while t[i] do i = i + 1 end
	t[i] = true
	return i
end

local function ReleaseSlot(side, index)
	slots[side][index] = nil
end

-- List rows are numbered newest-first, so the freshest loot always sits on the
-- anchor and older rows get pushed away. Re-run after any add or removal; cards
-- ease toward their new target rather than snapping, so gaps close smoothly.
local function ReindexList()
	local n = 0
	for i = #active, 1, -1 do
		local c = active[i]
		if c.listMode then
			n = n + 1
			c.listTarget = n - 1   -- row index; pixels resolved at draw time
		end
	end
end

local function ChooseSide()
	local r, l = 0, 0
	for i = 1, #active do
		if active[i].side == 1 then r = r + 1 else l = l + 1 end
	end
	if r < l then return 1 end
	if l < r then return -1 end
	lastSide = -lastSide
	return lastSide
end

--------------------------------------------------------------------------------
-- Card construction
--------------------------------------------------------------------------------

local CardMixin = {}

-- Hovering holds the card open so the tooltip does not fade out from under you.
local function CardOnEnter(self)
	self.hovered = true

	local fadeStart = self.duration - self.fade
	if self.elapsed > fadeStart then
		self.elapsed = fadeStart
	end

	GameTooltip:SetOwner(self, self.side == 1 and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
	if self.link then
		GameTooltip:SetHyperlink(self.link)
	else
		local r, g, b = unpack(self.color)
		GameTooltip:SetText(self.name:GetText(), r, g, b)
	end
	GameTooltip:Show()
end

local function CardOnLeave(self)
	self.hovered = nil
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local function CreateCard()
	local c = CreateFrame("Frame", nil, UIParent)
	c:SetSize(200, ROW_H)
	c:SetFrameStrata("DIALOG")
	c:SetFrameLevel(600)
	c:Hide()

	-- Motion only: the card reports hover but lets clicks fall through to the
	-- world, so it can never eat a target click or a spell cast.
	c:EnableMouse(true)
	c:SetMouseClickEnabled(false)
	c:SetMouseMotionEnabled(true)
	c:SetScript("OnEnter", CardOnEnter)
	c:SetScript("OnLeave", CardOnLeave)

	c.bg = c:CreateTexture(nil, "BACKGROUND")
	c.bg:SetAllPoints()
	c.bg:SetColorTexture(0.04, 0.04, 0.05, 0.80)

	-- Quality wash: strong on the cursor side, fading out toward the tip.
	c.tint = c:CreateTexture(nil, "BORDER")
	c.tint:SetAllPoints()
	c.tint:SetColorTexture(1, 1, 1, 1)

	c.hairTop = c:CreateTexture(nil, "BORDER", nil, 1)
	c.hairTop:SetPoint("TOPLEFT")
	c.hairTop:SetPoint("TOPRIGHT")
	c.hairTop:SetHeight(1)
	c.hairTop:SetColorTexture(1, 1, 1, 0.10)

	c.hairBottom = c:CreateTexture(nil, "BORDER", nil, 1)
	c.hairBottom:SetPoint("BOTTOMLEFT")
	c.hairBottom:SetPoint("BOTTOMRIGHT")
	c.hairBottom:SetHeight(1)
	c.hairBottom:SetColorTexture(0, 0, 0, 0.55)

	-- Vertical accent bar on whichever edge faces the cursor.
	c.accent = c:CreateTexture(nil, "ARTWORK")
	c.accent:SetWidth(2)

	c.iconBorder = c:CreateTexture(nil, "ARTWORK")
	c.iconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)

	c.icon = c:CreateTexture(nil, "ARTWORK", nil, 1)
	c.icon:SetSize(ICON_SIZE, ICON_SIZE)
	c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	c.burst = c:CreateTexture(nil, "OVERLAY")
	c.burst:SetTexture("Interface\\Cooldown\\star4")
	c.burst:SetBlendMode("ADD")
	c.burst:SetPoint("CENTER", c.icon, "CENTER")
	c.burst:Hide()

	c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local fontPath = c.name:GetFont()
	c.name:SetFont(fontPath, 13, "OUTLINE")
	c.name:SetWordWrap(false)
	c.name:SetJustifyV("MIDDLE")

	c.count = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	c.count:SetFont(fontPath, 12, "OUTLINE")
	c.count:SetTextColor(0.85, 0.85, 0.88)

	for k, v in pairs(CardMixin) do c[k] = v end
	return c
end

--------------------------------------------------------------------------------
-- Card behaviour
--------------------------------------------------------------------------------

function CardMixin:UpdateCount()
	if self.count_ and self.count_ > 1 then
		self.count:SetText("x" .. self.count_)
		self.count:Show()
	else
		self.count:SetText("")
		self.count:Hide()
	end
	self:Relayout()
end

-- Mirror the whole card so the icon always sits on the cursor-facing edge.
function CardMixin:Relayout()
	local nameW = min(self.name:GetUnboundedStringWidth(), MAX_NAME_W)
	self.name:SetWidth(nameW)

	local countW = self.count:IsShown() and (self.count:GetStringWidth() + 5) or 0
	local width = PAD + ICON_SIZE + GAP + nameW + countW + PAD + 2
	self:SetSize(width, ROW_H)

	self.icon:ClearAllPoints()
	self.iconBorder:ClearAllPoints()
	self.accent:ClearAllPoints()
	self.name:ClearAllPoints()
	self.count:ClearAllPoints()

	if self.side == 1 then
		-- Card extends to the right of the cursor: icon hugs the left edge.
		self.accent:SetPoint("TOPLEFT")
		self.accent:SetPoint("BOTTOMLEFT")
		self.icon:SetPoint("LEFT", self, "LEFT", PAD + 2, 0)
		self.name:SetPoint("LEFT", self.icon, "RIGHT", GAP, 0)
		self.name:SetJustifyH("LEFT")
		self.count:SetPoint("LEFT", self.name, "RIGHT", 5, -1)
	else
		self.accent:SetPoint("TOPRIGHT")
		self.accent:SetPoint("BOTTOMRIGHT")
		self.icon:SetPoint("RIGHT", self, "RIGHT", -(PAD + 2), 0)
		self.name:SetPoint("RIGHT", self.icon, "LEFT", -GAP, 0)
		self.name:SetJustifyH("RIGHT")
		self.count:SetPoint("RIGHT", self.name, "LEFT", -5, -1)
	end

	self.iconBorder:SetPoint("CENTER", self.icon, "CENTER")

	local r, g, b = unpack(self.color)
	local from = CreateColor(r, g, b, 0.34)
	local to   = CreateColor(r, g, b, 0.00)
	if self.side == 1 then
		self.tint:SetGradient("HORIZONTAL", from, to)
	else
		self.tint:SetGradient("HORIZONTAL", to, from)
	end
end

function CardMixin:Setup(data, side, slot, listMode)
	self.listMode   = listMode or nil
	self.listY      = 0
	self.listTarget = 0

	self.key      = data.key
	self.count_   = data.count or 1
	self.link     = data.link
	self.kind     = data.kind
	self.side     = side
	self.slot     = slot
	self.elapsed  = 0
	self.pulse    = nil
	self.hovered  = nil
	self.duration = SpoilsDB.duration
	self.fade     = min(SpoilsDB.fadeTime or 1.25, self.duration - MIN_HOLD)

	self:SetMouseMotionEnabled(SpoilsDB.showTooltips and true or false)

	local r, g, b
	if data.color then
		r, g, b = data.color[1], data.color[2], data.color[3]
	else
		r, g, b = ns.GetQualityColor(data.quality)
	end
	self.color = self.color or {}
	self.color[1], self.color[2], self.color[3] = r, g, b

	self.icon:SetTexture(data.icon or 134400)
	self.iconBorder:SetColorTexture(r, g, b, 0.95)
	self.accent:SetColorTexture(r, g, b, 0.95)

	self.name:SetText(data.name or "?")
	self.name:SetTextColor(r, g, b)
	self:UpdateCount()

	-- Fan geometry
	self.baseY     = 12 + (slot - 1) * (ROW_H + ROW_GAP)
	self.driftOut  = 26 + slot * 3
	self.rise      = 22
	self.phase     = slot * 0.8

	-- Radial geometry: alternate above/below, walking outward from horizontal.
	local step = (slot - 1) * 0.42
	self.angle = (side == 1) and (step * ((slot % 2 == 0) and -1 or 1))
	                          or (pi - step * ((slot % 2 == 0) and -1 or 1))
	self.radiusOut = 46

	-- Spawn flourish scales with rarity.
	local q = data.quality or 1
	if q >= 3 or data.kind == "money" then
		self.burstAlpha = (q >= 4) and 0.85 or 0.5
		self.burst:SetVertexColor(r, g, b)
		self.burst:Show()
	else
		self.burst:Hide()
	end

	self:SetAlpha(0)
	self:Show()
end

function CardMixin:Animate(dt, cx, cy)
	local t, dur = self.elapsed, self.duration
	local alpha, scale = 1, 1

	if t < INTRO then
		local p = t / INTRO
		scale = 0.62 + easeOutBack(p) * 0.38
		alpha = min(1, p * 2.5)
	end

	local fadeStart = dur - self.fade
	if t > fadeStart then
		local p = (t - fadeStart) / self.fade
		alpha = alpha * (1 - p * p)
		scale = scale * (1 - 0.14 * p)
	end

	-- Restack pulse when the same item lands again.
	if self.pulse then
		self.pulse = self.pulse + dt
		if self.pulse >= 0.24 then
			self.pulse = nil
		else
			local p = self.pulse / 0.24
			scale = scale * (1 + 0.16 * sin(p * pi))
		end
	end

	local d = easeOutCubic(min(t / dur * 1.6, 1))
	local x, y, anchor

	if self.listMode then
		-- No drift and no bob: a list should sit still and just close ranks.
		self.listY = self.listY + (self.listTarget - self.listY) * min(dt * LIST_EASE, 1)

		-- Row pitch tracks the configured scale, otherwise smaller cards leave
		-- gaps: the frame shrinks but a pixel offset would not.
		local base    = SpoilsDB.scale or 1
		local rowStep = (ROW_H + ROW_GAP) * base
		local halfH   = ROW_H * base / 2

		local grow  = (SpoilsDB.listGrow == "down") and -1 or 1
		local slide = (1 - easeOutCubic(min(t / (INTRO * 1.6), 1))) * 20

		x = cx - self.side * slide
		y = cy + grow * (LIST_PAD + halfH + self.listY * rowStep)
		anchor = (self.side == 1) and "LEFT" or "RIGHT"

	elseif SpoilsDB.style == "radial" then
		local r = RADIAL_R + self.radiusOut * d
		x = cx + cos(self.angle) * r
		y = cy + sin(self.angle) * r + sin((t + self.phase) * 1.7) * 2.5
		anchor = "CENTER"
	else
		local out = CURSOR_GAP + self.driftOut * d
		local up  = self.baseY + self.rise * d + sin((t + self.phase) * 1.8) * 2.5
		x = cx + self.side * out
		y = cy + up
		anchor = (self.side == 1) and "LEFT" or "RIGHT"
	end

	local s = (SpoilsDB.scale or 1) * scale
	self:SetScale(s)
	self:SetAlpha(alpha)
	self:ClearAllPoints()
	self:SetPoint(anchor, UIParent, "BOTTOMLEFT", x / s, y / s)

	if self.burst:IsShown() then
		if t < 0.55 then
			local p = t / 0.55
			local sz = 30 + 52 * easeOutQuad(p)
			self.burst:SetSize(sz, sz)
			self.burst:SetAlpha((1 - p) * self.burstAlpha)
			self.burst:SetRotation(p * 1.1)
		else
			self.burst:Hide()
		end
	end
end

--------------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------------

local function Release(card, index)
	if GameTooltip:GetOwner() == card then
		GameTooltip:Hide()
	end
	card.hovered = nil
	if not card.listMode then
		ReleaseSlot(card.side, card.slot)
	end
	card:Hide()
	card:ClearAllPoints()
	card.key = nil
	table.remove(active, index)
	pool[#pool + 1] = card
	ReindexList()
end

local function OnUpdate(_, dt)
	local cx, cy

	for i = #active, 1, -1 do
		local card = active[i]
		if not card.hovered then
			card.elapsed = card.elapsed + dt
		end
		if card.elapsed >= card.duration then
			Release(card, i)
		else
			local ox, oy = card.originX, card.originY
			if card.follow then
				if not cx then
					local s = UIParent:GetEffectiveScale()
					local mx, my = GetCursorPosition()
					cx, cy = mx / s, my / s
				end
				ox, oy = cx, cy
			end
			card:Animate(dt, ox, oy)
		end
	end

	if #active == 0 then
		driver:SetScript("OnUpdate", nil)
		driver:Hide()
	end
end

local function EnsureDriver()
	if not driver then
		driver = CreateFrame("Frame")
	end
	if not driver:GetScript("OnUpdate") then
		driver:SetScript("OnUpdate", OnUpdate)
		driver:Show()
	end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Cards:Push(data)
	local db = SpoilsDB

	-- Same item landing again? Bump the stack instead of spawning a twin.
	if data.key then
		for i = 1, #active do
			local c = active[i]
			if c.key == data.key and c.elapsed < (c.duration - c.fade) then
				if data.kind == "money" then
					c.copper = (c.copper or 0) + data.copper
					c.name:SetText(GetCoinTextureString(c.copper))
				else
					c.count_ = c.count_ + (data.count or 1)
				end
				c:UpdateCount()
				c.pulse = 0
				c.elapsed = min(c.elapsed, c.duration * 0.30)
				return
			end
		end
	end

	-- Over budget: fast-forward the oldest card into its fade.
	local limit = db.maxCards or 8
	while #active >= limit do
		local oldest, oldestIndex = nil, nil
		for i = 1, #active do
			if not oldest or active[i].elapsed > oldest.elapsed then
				oldest, oldestIndex = active[i], i
			end
		end
		Release(oldest, oldestIndex)
	end

	local listMode = (db.style == "list")
	local side, slot
	if listMode then
		-- One column, no alternating sides; alignment picks which way it mirrors.
		side, slot = (db.listAlign == "right") and -1 or 1, 1
	else
		side = ChooseSide()
		slot = AcquireSlot(side)
	end

	local card = table.remove(pool) or CreateCard()
	card:Setup(data, side, slot, listMode)
	card.copper = data.copper

	if db.anchorMode == "screen" then
		card.originX, card.originY = ns.GetScreenAnchor()
		card.follow = false
	else
		-- Pinned cards keep this forever; followers use it for frame one only.
		local uiScale = UIParent:GetEffectiveScale()
		local mx, my = GetCursorPosition()
		card.originX, card.originY = mx / uiScale, my / uiScale
		card.follow = db.followCursor and true or false
	end

	active[#active + 1] = card
	ReindexList()
	card:Animate(0, card.originX, card.originY)
	EnsureDriver()

	if db.playSound and (data.quality or 0) >= (db.soundQuality or 4) then
		pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST, "Master")
	end
end

function Cards:ClearAll()
	for i = #active, 1, -1 do
		Release(active[i], i)
	end
end
