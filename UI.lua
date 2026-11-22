-- UI.lua: the settings window. Your bars as rows of icons; click one to set it up.
local _, ns = ...
local L = ns.L

local frame
local selected          -- the action slot being edited
local ROW_H, ICON, GAP = 34, 30, 3
local LABEL_W = 170
local EDITOR_W = 250

local COLORS = {
    converted = { 0.20, 0.80, 0.30 },
    pending   = { 1.00, 0.80, 0.10 },
    changed   = { 1.00, 0.50, 0.10 },
    skip      = { 0.35, 0.35, 0.35 },
    foreign   = { 0.15, 0.15, 0.15 },
    empty     = { 0.08, 0.08, 0.08 },
}
local STATE_TEXT = {
    converted = L["Converted"],
    pending = L["Pending: Apply to convert"],
    changed = L["Changed: Apply to update"],
    skip = L["Left as it is"],
}
local KIND_TEXT = { harmful = L["Harmful"], helpful = L["Helpful"], other = L["Other"] }

---------------------------------------------------------------------------
-- Small widgets
---------------------------------------------------------------------------
local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

-- a button that shows the current choice and opens a menu of the others
-- (cycles through them where the game has no menu API)
-- shrink a text's font until it fits `maxWidth`, so long translations stay inside
-- their button or row instead of spilling out
local function Fit(fs, maxWidth)
    if not (fs and fs.GetFont) then return end
    local file, size, flags = fs:GetFont()
    if not file then return end
    fs.scfBase = fs.scfBase or size
    size = fs.scfBase
    fs:SetFont(file, size, flags)
    while fs:GetStringWidth() > maxWidth and size > 7 do
        size = size - 0.5
        fs:SetFont(file, size, flags)
    end
end

local function Choice(parent, width, options, get, set)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetNormalFontObject("GameFontHighlightSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    function b:Refresh()
        local current, text = get(), "?"
        for _, o in ipairs(options()) do
            if o[1] == current then text = o[2] end
        end
        self:SetText(text)
        Fit(self:GetFontString(), width - 14)
    end
    b:SetScript("OnClick", function(self)
        local list = options()
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                for _, o in ipairs(list) do
                    root:CreateRadio(o[2], function() return get() == o[1] end, function() set(o[1]) end)
                end
            end)
        elseif #list > 0 then
            local current, index = get(), 1
            for k, o in ipairs(list) do
                if o[1] == current then index = k end
            end
            set(list[index % #list + 1][1])
        end
    end)
    return b
end

local function Check(parent, text, get, set, maxWidth)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.label = Label(cb, text, "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    if maxWidth then Fit(cb.label, maxWidth) end
    if cb.Text then cb.Text:SetText("") end
    if cb.text then cb.text:SetText("") end
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    function cb:Refresh() self:SetChecked(get() and true or false) end
    return cb
end

local function TemplateOptions(withDefault, defaultName)
    local list = {}
    if withDefault then list[#list + 1] = { "default", (L["Default (%s)"]):format(defaultName or "") } end
    list[#list + 1] = { "skip", ns.TEMPLATE_NAMES.skip }
    for _, key in ipairs(ns.TEMPLATES) do list[#list + 1] = { key, ns.TEMPLATE_NAMES[key] } end
    return list
end

---------------------------------------------------------------------------
-- Slot icons
---------------------------------------------------------------------------
local function ShowTooltip(button)
    local p = button.slot and ns.Plan(button.slot)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if not p then
        GameTooltip:SetText(L["Empty slot"])
    elseif not p.name then
        GameTooltip:SetText(L["Not a spell: SmartCast leaves it alone."], 1, 1, 1, 1, true)
    else
        -- the game's own spell tooltip (icon, cost, description), then SmartCast's lines
        local ok = GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, p.fixedRank and p.id or p.id)
        if not ok then
            GameTooltip:SetText(p.name .. (p.rank and ("  |cff999999" .. p.rank .. "|r") or ""))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff66ccffSmartCast:|r " .. (ns.TEMPLATE_NAMES[p.template] or ""), 1, 1, 1)
        if p.fixedRank then GameTooltip:AddLine(L["Rank"] .. ": " .. p.fixedRank, 1, 1, 1) end
        if p.outdated then
            GameTooltip:AddLine((L["This button holds %s; you know up to %s."]):format(p.rank, p.best.rank), 1, 0.82, 0)
        end
        local c = COLORS[p.state] or COLORS.skip
        GameTooltip:AddLine(STATE_TEXT[p.state] or "", c[1], c[2], c[3])
    end
    GameTooltip:Show()
end

local function SlotButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(ICON, ICON)
    b.selected = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.selected:SetPoint("TOPLEFT", -2, 2)
    b.selected:SetPoint("BOTTOMRIGHT", 2, -2)
    b.selected:SetColorTexture(1, 1, 1, 1)
    b.selected:Hide()
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- an older rank than you know, still waiting for your choice
    b.older = b:CreateTexture(nil, "OVERLAY")
    b.older:SetSize(14, 14)
    b.older:SetPoint("TOPRIGHT", 3, 3)
    b.older:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    b.older:Hide()
    b:SetScript("OnClick", function(self)
        selected = self.slot
        ns.RefreshWindow()
    end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function DrawSlot(b, slot)
    b.slot = slot
    local p = ns.Plan(slot)
    local state = (not p and "empty") or (not p.name and "foreign") or p.state
    local c = COLORS[state] or COLORS.skip
    b.border:SetColorTexture(c[1], c[2], c[3], 1)
    local texture = p and (p.icon or GetActionTexture(slot)) or nil
    b.icon:SetTexture(texture)
    b.icon:SetShown(texture ~= nil)
    b.icon:SetDesaturated(state == "skip" or state == "foreign")
    b.icon:SetAlpha((state == "foreign") and 0.5 or 1)
    b.selected:SetShown(slot == selected)
    b.older:SetShown(p and p.needsDecision and true or false)
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local rows = {}
local editor = {}
local defaultsUI = {}

local function Build()
    frame = CreateFrame("Frame", "SmartCastForeverFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(16 + LABEL_W + 12 * (ICON + GAP) + 20 + EDITOR_W + 16, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "SmartCastForeverFrame")
    local title = frame.TitleText or frame.title or Label(frame, "")
    if not (frame.TitleText or frame.title) then title:SetPoint("TOP", 0, -5) end
    title:SetText("SmartCast Forever")

    -- default rules
    local head = Label(frame, L["Default rules"])
    head:SetPoint("TOPLEFT", 16, -34)
    local x = 16
    for _, kind in ipairs({ "harmful", "helpful", "other" }) do
        local key = kind
        local name = Label(frame, L[kind == "harmful" and "Harmful spells" or kind == "helpful" and "Helpful spells" or "Other spells"], "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", x, -56)
        local choice = Choice(frame, 230, function() return TemplateOptions(false) end,
            function() return ns.char.defaults[key] end,
            function(v) ns.char.defaults[key] = v; ns.Changed() end)
        choice:SetPoint("TOPLEFT", x, -70)
        defaultsUI[#defaultsUI + 1] = choice
        x = x + 240
    end
    local noToggle = Check(frame, L["Don't cancel if already active (!)"],
        function() return ns.char.noToggle end,
        function(v) ns.char.noToggle = v; ns.Changed() end, 205)
    noToggle:SetPoint("TOPLEFT", 12, -96)
    defaultsUI[#defaultsUI + 1] = noToggle
    local hideNames = Check(frame, L["Hide macro names on the buttons"],
        function() return ns.db.hideNames end,
        function(v) ns.db.hideNames = v; if ns.RefreshButtonNames then ns.RefreshButtonNames() end end, 330)
    hideNames:SetPoint("TOPLEFT", 252, -96)
    defaultsUI[#defaultsUI + 1] = hideNames

    local oldLabel = Label(frame, L["Older ranks on a button"], "GameFontHighlightSmall")
    oldLabel:SetPoint("TOPLEFT", 16, -128)
    local oldRank = Choice(frame, 200, function()
            return { { "ask", L["Ask me"] }, { "max", L["Use the highest"] }, { "keep", L["Keep the button's rank"] } }
        end,
        function() return ns.char.oldRank end,
        function(v) ns.char.oldRank = v; ns.ResolveRanks(); ns.Changed() end)
    oldRank:SetPoint("LEFT", oldLabel, "RIGHT", 8, 0)
    defaultsUI[#defaultsUI + 1] = oldRank
    local upgrade = Check(frame, L["Keep the spells on my bars at their highest rank"],
        function() return ns.char.autoUpgrade end,
        function(v) ns.char.autoUpgrade = v; if v then ns.Upgrade() end; ns.Changed() end, 330)
    upgrade:SetPoint("LEFT", oldRank, "RIGHT", 14, 0)
    defaultsUI[#defaultsUI + 1] = upgrade

    -- the bars
    local barsHead = Label(frame, L["Your bars"])
    barsHead:SetPoint("TOPLEFT", 16, -158)
    local hint = Label(frame, L["Click a button to set it up."], "GameFontDisableSmall")
    hint:SetPoint("LEFT", barsHead, "RIGHT", 10, 0)
    for r = 1, #ns.BARS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(LABEL_W + 12 * (ICON + GAP), ROW_H)
        row.label = Label(row, "", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 0, 0)
        row.label:SetWidth(LABEL_W - 8)
        row.buttons = {}
        for i = 1, 12 do
            local b = SlotButton(row)
            b:SetPoint("LEFT", LABEL_W + (i - 1) * (ICON + GAP), 0)
            row.buttons[i] = b
        end
        rows[r] = row
    end

    -- the editor for one button
    local ed = CreateFrame("Frame", nil, frame)
    ed:SetSize(EDITOR_W, 300)
    ed:SetPoint("TOPLEFT", 16 + LABEL_W + 12 * (ICON + GAP) + 20, -158)
    editor.frame = ed
    editor.icon = ed:CreateTexture(nil, "ARTWORK")
    editor.icon:SetSize(36, 36)
    editor.icon:SetPoint("TOPLEFT", 0, 0)
    editor.name = Label(ed, "", "GameFontNormal")
    editor.name:SetPoint("TOPLEFT", editor.icon, "TOPRIGHT", 8, -2)
    editor.name:SetWidth(EDITOR_W - 44)
    editor.sub = Label(ed, "", "GameFontDisableSmall")
    editor.sub:SetPoint("TOPLEFT", editor.name, "BOTTOMLEFT", 0, -3)
    editor.empty = Label(ed, L["Click a button to set it up."], "GameFontDisableSmall")
    editor.empty:SetPoint("TOPLEFT", 0, -4)
    editor.empty:SetWidth(EDITOR_W)

    editor.ruleLabel = Label(ed, L["Rule"], "GameFontHighlightSmall")
    editor.ruleLabel:SetPoint("TOPLEFT", 0, -50)
    editor.rule = Choice(ed, EDITOR_W,
        function()
            local p = selected and ns.Plan(selected)
            local default = p and ns.TEMPLATE_NAMES[ns.char.defaults[p.kind] or "skip"]
            return TemplateOptions(true, default)
        end,
        function() local p = selected and ns.Plan(selected); return p and p.mode or "default" end,
        function(v) ns.SetSlot(selected, "mode", v) end)
    editor.rule:SetPoint("TOPLEFT", 0, -64)

    editor.rankLabel = Label(ed, L["Rank"], "GameFontHighlightSmall")
    editor.rankLabel:SetPoint("TOPLEFT", 0, -94)
    editor.rank = Choice(ed, EDITOR_W,
        function()
            local list = { { "MAX", L["Highest known"] } }
            local p = selected and ns.Plan(selected)
            if p and p.name then
                local seen = {}
                for _, r in ipairs(ns.KnownRanks(p.name)) do
                    list[#list + 1] = { r.rank, r.rank }
                    seen[r.rank] = true
                end
                -- the rank on the button is always offered, so it can be kept as it is
                if p.rank and not seen[p.rank] then list[#list + 1] = { p.rank, p.rank } end
            end
            return list
        end,
        function() local p = selected and ns.Plan(selected); return p and p.fixedRank or "MAX" end,
        function(v) ns.SetSlot(selected, "rank", v ~= "MAX" and v or nil) end)
    editor.rank:SetPoint("TOPLEFT", 0, -108)

    editor.shift = Check(ed, L["Shift: cast on myself"],
        function() local p = selected and ns.Plan(selected); return p and p.shiftSelf end,
        function(v) ns.SetSlot(selected, "shiftSelf", v) end, 220)
    editor.rankInfo = Label(ed, "", "GameFontHighlightSmall")
    editor.rankInfo:SetPoint("TOPLEFT", 0, -136)
    editor.rankInfo:SetWidth(EDITOR_W)
    editor.rankInfo:SetTextColor(1, 0.82, 0)
    editor.useMax = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
    editor.useMax:SetSize(EDITOR_W / 2 - 3, 22)
    editor.useMax:SetPoint("TOPLEFT", 0, -164)
    editor.useMax:SetNormalFontObject("GameFontHighlightSmall")
    editor.useMax:SetText(L["Use the highest"])
    editor.useMax:SetScript("OnClick", function() ns.DecideSlot(selected, false) end)
    editor.keep = CreateFrame("Button", nil, ed, "UIPanelButtonTemplate")
    editor.keep:SetSize(EDITOR_W / 2 - 3, 22)
    editor.keep:SetPoint("LEFT", editor.useMax, "RIGHT", 6, 0)
    editor.keep:SetNormalFontObject("GameFontHighlightSmall")
    editor.keep:SetScript("OnClick", function() ns.DecideSlot(selected, true) end)

    editor.shift:SetPoint("TOPLEFT", -4, -192)

    editor.stopLabel = Label(ed, L["Stop casting"], "GameFontHighlightSmall")
    editor.stopLabel:SetPoint("TOPLEFT", 0, -218)
    Fit(editor.stopLabel, 84)
    editor.stop = Choice(ed, EDITOR_W - 90, function()
            return { { "none", L["Don't stop"] }, { "channel", L["Stop channels"] }, { "all", L["Stop current cast"] } }
        end,
        function() local p = selected and ns.Plan(selected); return p and p.stopMode or "none" end,
        function(v) ns.SetSlot(selected, "stopMode", v) end)
    editor.stop:SetPoint("TOPRIGHT", ed, "TOPLEFT", EDITOR_W, -213)
    editor.stop:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Stop casting"])
        GameTooltip:AddLine(L["Stop channels: cuts a channeled spell (Arcane Missiles, Blizzard...), never this spell itself."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Stop current cast: cuts anything, a wand shot too. Pressing it twice restarts this spell."], 1, 1, 1, true)
        GameTooltip:AddLine(L["When it cuts a cast, the new spell may need a second press."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    editor.stop:HookScript("OnLeave", function() GameTooltip:Hide() end)

    editor.state = Label(ed, "", "GameFontHighlightSmall")
    editor.state:SetPoint("TOPLEFT", 0, -250)
    editor.state:SetWidth(EDITOR_W)
    editor.previewLabel = Label(ed, L["Macro preview"], "GameFontHighlightSmall")
    editor.previewLabel:SetPoint("TOPLEFT", 0, -272)
    editor.preview = Label(ed, "", "GameFontDisableSmall")
    editor.preview:SetPoint("TOPLEFT", 0, -288)
    editor.preview:SetWidth(EDITOR_W)
    editor.preview:SetJustifyV("TOP")
    -- macro conditions have no spaces: let them wrap anywhere instead of being cut with "..."
    if editor.preview.SetNonSpaceWrap then editor.preview:SetNonSpaceWrap(true) end

    -- footer
    local apply = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    apply:SetSize(120, 24)
    apply:SetPoint("BOTTOMRIGHT", -16, 14)
    apply:SetText(L["Apply"])
    apply:SetScript("OnClick", function() ns.Apply() end)
    local undo = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    undo:SetSize(120, 24)
    undo:SetPoint("RIGHT", apply, "LEFT", -8, 0)
    undo:SetText(L["Undo all"])
    undo:SetScript("OnClick", function() ns.Undo() end)
    frame.status = Label(frame, "", "GameFontHighlightSmall")
    frame.status:SetPoint("BOTTOMLEFT", 18, 20)

    frame:SetScript("OnShow", function() ns.RefreshWindow() end)
end

local function DrawEditor()
    local p = selected and ns.Plan(selected)
    local show = p and p.name and true or false
    for _, w in ipairs({ editor.icon, editor.name, editor.sub, editor.ruleLabel, editor.rule, editor.state,
            editor.previewLabel, editor.preview, editor.shift, editor.stop, editor.stopLabel }) do
        w:SetShown(show)
    end
    editor.empty:SetShown(not show)
    if not show then
        editor.rankLabel:Hide(); editor.rank:Hide()
        editor.rankInfo:Hide(); editor.useMax:Hide(); editor.keep:Hide()
        editor.empty:SetText((p and L["Not a spell: SmartCast leaves it alone."]) or (selected and L["Empty slot"])
            or L["Click a button to set it up."])
        return
    end
    editor.icon:SetTexture(p.icon)
    editor.name:SetText(p.name)
    editor.sub:SetText((p.rank and (p.rank .. "  ·  ") or "") .. (KIND_TEXT[p.kind] or ""))
    editor.rule:Refresh()
    local hasRanks = p.rank ~= nil
    editor.rankLabel:SetShown(hasRanks)
    editor.rank:SetShown(hasRanks)
    if hasRanks then editor.rank:Refresh() end
    editor.rankInfo:SetShown(p.outdated and true or false)
    if p.outdated then
        editor.rankInfo:SetText((L["This button holds %s; you know up to %s."]):format(p.rank, p.best.rank))
    end
    editor.useMax:SetShown(p.needsDecision and true or false)
    editor.keep:SetShown(p.needsDecision and true or false)
    editor.keep:SetText((L["Keep %s"]):format(p.rank or ""))
    editor.shift:Refresh()
    editor.shift:SetShown(p.template ~= "skip" and p.template ~= "self")
    editor.stop:Refresh()
    editor.stop:SetShown(p.template ~= "skip")
    editor.stopLabel:SetShown(p.template ~= "skip")
    local c = COLORS[p.state] or COLORS.skip
    editor.state:SetText(STATE_TEXT[p.state] or "")
    editor.state:SetTextColor(c[1], c[2], c[3])
    editor.preview:SetText(p.body or "—")
end

function ns.RefreshWindow()
    if not (frame and frame:IsShown() and ns.char) then return end
    for _, w in ipairs(defaultsUI) do w:Refresh() end

    local shown = 0
    for r, bar in ipairs(ns.BARS) do
        local row = rows[r]
        local any = false
        for i = 0, 11 do
            if ns.Plan(bar.first + i) then any = true break end
        end
        if any or r == 1 then
            shown = shown + 1
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 16, -178 - (shown - 1) * ROW_H)
            row.label:SetText(bar.name)
            for i = 1, 12 do DrawSlot(row.buttons[i], bar.first + i - 1) end
            row:Show()
        else
            row:Hide()
        end
    end
    frame:SetHeight(math.max(178 + shown * ROW_H + 60, 178 + 350 + 60))

    DrawEditor()
    local converted, todo = ns.Counts()
    frame.status:SetText((L["Converted: %d   Pending: %d   Character macros: %d / %d"]):format(
        converted, todo, ns.CharacterMacroCount(), ns.MaxCharacterMacros()))
end

function ns.ShowSlot(slot)
    if not frame then Build() end
    selected = slot
    frame:Show()
    ns.RefreshWindow()
end

function ns.ToggleWindow()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
