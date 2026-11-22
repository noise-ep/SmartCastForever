-- Core.lua: what each action button should become, and putting it there (or back).
local ADDON, ns = ...
local L = ns.L

ns.PREFIX = "SC "             -- every macro SmartCast makes starts with this
ns.MAX_SLOT = 180
local QUESTION_ICON = 134400  -- with #showtooltip the button shows the spell's own icon

---------------------------------------------------------------------------
-- Templates: where the spell goes
---------------------------------------------------------------------------
ns.TEMPLATES = { "enemyAssist", "mouseover", "friendSelf", "friendAssist", "self" }
ns.TEMPLATE_NAMES = {
    enemyAssist = L["Enemy, or my friend's target"],
    mouseover = L["Mouseover, else target"],
    friendSelf = L["Friend, else myself"],
    friendAssist = L["Friend, else my enemy's target, else myself"],
    self = L["Always myself"],
    skip = L["Don't touch"],
}

local function Conditions(template, kind)
    if template == "enemyAssist" then
        return "[@target,harm,nodead][@targettarget,harm,nodead]"
    elseif template == "mouseover" then
        local who = (kind == "helpful" and "help") or (kind == "harmful" and "harm") or "exists"
        return ("[@mouseover,%s,nodead][]"):format(who)
    elseif template == "friendSelf" then
        return "[@target,help,nodead][@player]"
    elseif template == "friendAssist" then
        -- the mirror of enemyAssist: an enemy selected by mistake heals whoever it is hitting
        return "[@target,help,nodead][@targettarget,help,nodead][@player]"
    elseif template == "self" then
        return "[@player]"
    end
    return ""
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
local DEFAULTS = {
    defaults = { harmful = "enemyAssist", helpful = "skip", other = "skip" },
    noToggle = true,   -- "!" in front of the spell: a second press doesn't switch it off
    slots = {},        -- [slot] = { spell = name, mode = "default"|"skip"|template, rank = "Rank 3"|nil, shiftSelf = bool }
    applied = {},      -- [slot] = { id = spellID that was there before }
    macros = {},       -- [macro name] = { id = spellID, body = text }
}

local function Fill(target, source)
    for k, v in pairs(source) do
        if target[k] == nil then
            if type(v) == "table" then target[k] = {}; Fill(target[k], v) else target[k] = v end
        elseif type(v) == "table" and type(target[k]) == "table" then
            Fill(target[k], v)
        end
    end
end

---------------------------------------------------------------------------
-- Spell information (Forever's C_Spell API, with the old globals as a fallback)
---------------------------------------------------------------------------
local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

function ns.SpellName(id)
    return Try(C_Spell and C_Spell.GetSpellName, id) or (Try(GetSpellInfo, id))
end

function ns.SpellIcon(id)
    return Try(C_Spell and C_Spell.GetSpellTexture, id) or Try(GetSpellTexture, id)
end

-- "Rank 3" (in the game's language), or nil for a spell without ranks
function ns.SpellRank(id)
    local text = Try(C_Spell and C_Spell.GetSpellSubtext, id) or Try(GetSpellSubtext, id)
    if type(text) == "string" and text:find("%d") then return text end
end

function ns.SpellKind(id)
    if Try(C_Spell and C_Spell.IsSpellHarmful, id) or Try(IsHarmfulSpell, ns.SpellName(id) or id) then
        return "harmful"
    end
    if Try(C_Spell and C_Spell.IsSpellHelpful, id) or Try(IsHelpfulSpell, ns.SpellName(id) or id) then
        return "helpful"
    end
    return "other"
end

-- every rank of `name` in your spellbook: { { id = , rank = "Rank 1" }, ... } lowest first
function ns.KnownRanks(name)
    local list = {}
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    if not (book and book.GetNumSpellBookSkillLines and bank) then return list end
    for line = 1, (Try(book.GetNumSpellBookSkillLines) or 0) do
        local info = Try(book.GetSpellBookSkillLineInfo, line)
        if info and info.itemIndexOffset and info.numSpellBookItems then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = Try(book.GetSpellBookItemInfo, i, bank)
                if item and item.name == name and (spellType == nil or item.itemType == spellType) then
                    local id = item.actionID or item.spellID
                    local rank = item.subName
                    if (not rank or rank == "") and id then rank = ns.SpellRank(id) end
                    if id and rank and rank:find("%d") then
                        list[#list + 1] = { id = id, rank = rank, n = tonumber(rank:match("%d+")) or 0 }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.n < b.n end)
    return list
end

---------------------------------------------------------------------------
-- Action buttons
---------------------------------------------------------------------------
-- The bars, in the order the window lists them. `first` is the first action slot.
ns.BARS = {
    { first = 1,   name = L["Action Bar 1"] },
    { first = 13,  name = L["Action Bar 1 (page 2)"] },
    { first = 61,  name = (L["Action Bar %d"]):format(2) },
    { first = 49,  name = (L["Action Bar %d"]):format(3) },
    { first = 25,  name = (L["Action Bar %d"]):format(4) },
    { first = 37,  name = (L["Action Bar %d"]):format(5) },
    { first = 145, name = (L["Action Bar %d"]):format(6) },
    { first = 157, name = (L["Action Bar %d"]):format(7) },
    { first = 169, name = (L["Action Bar %d"]):format(8) },
    { first = 73,  name = (L["Form / stance bar %d"]):format(1), optional = true },
    { first = 85,  name = (L["Form / stance bar %d"]):format(2), optional = true },
    { first = 97,  name = (L["Form / stance bar %d"]):format(3), optional = true },
    { first = 109, name = (L["Form / stance bar %d"]):format(4), optional = true },
}

local function MacroNameOn(slot)
    local name = Try(C_ActionBar and C_ActionBar.GetActionText, slot) or Try(GetActionText, slot)
    return type(name) == "string" and name or nil
end

local function IsOurs(name)
    return name and name:sub(1, #ns.PREFIX) == ns.PREFIX
end

-- What is on a button: "spell" (with its id), "ours" (a SmartCast macro), "foreign" or nil when empty
function ns.ReadSlot(slot)
    local kind, id = GetActionInfo(slot)
    if not kind then return nil end
    if kind == "spell" and id then return { kind = "spell", id = id } end
    if kind == "macro" then
        local name = MacroNameOn(slot)
        if IsOurs(name) then return { kind = "ours", name = name } end
    end
    return { kind = "foreign", actionType = kind }
end

-- Everything SmartCast decides about one button
function ns.Plan(slot)
    local db = ns.char
    local s = ns.ReadSlot(slot)
    if not s then return nil end
    if s.kind == "foreign" then return { slot = slot, current = "foreign" } end

    local id
    if s.kind == "spell" then
        id = s.id
    else
        local applied, macro = db.applied[slot], db.macros[s.name]
        id = (applied and applied.id) or (macro and macro.id)
    end
    if not id then return { slot = slot, current = "foreign" } end

    local name = ns.SpellName(id)
    if not name then return { slot = slot, current = "foreign" } end
    local kind = ns.SpellKind(id)
    local o = db.slots[slot]
    if o and o.spell ~= name then o = nil end   -- another spell is there now: its old choice doesn't apply

    local mode = o and o.mode or "default"
    local template = mode == "default" and (db.defaults[kind] or "skip") or mode
    local p = {
        slot = slot, current = s.kind, macroName = s.name,
        id = id, name = name, kind = kind, icon = ns.SpellIcon(id),
        rank = ns.SpellRank(id), mode = mode, template = template,
        fixedRank = o and o.rank or nil,
        shiftSelf = o and o.shiftSelf or false,
        noToggle = db.noToggle and true or false,
    }
    if template ~= "skip" then p.body = ns.Body(p) end
    -- the state the window shows
    if template == "skip" then
        p.state = s.kind == "ours" and "changed" or "skip"
    elseif s.kind == "spell" then
        p.state = "pending"
    else
        local m = db.macros[s.name]
        p.state = (m and m.body == p.body) and "converted" or "changed"
    end
    return p
end

function ns.Body(p)
    local cond = Conditions(p.template, p.kind)
    if p.shiftSelf and p.template ~= "self" then cond = "[mod:shift,@player]" .. cond end
    local spell = p.name .. (p.fixedRank and ("(" .. p.fixedRank .. ")") or "")
    return ("#showtooltip\n/cast %s %s%s"):format(cond, p.noToggle and "!" or "", spell)
end

---------------------------------------------------------------------------
-- Macros
---------------------------------------------------------------------------
local function MaxCharacterMacros()
    local c = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS
    return c or MAX_CHARACTER_MACROS or 18
end
ns.MaxCharacterMacros = MaxCharacterMacros

function ns.CharacterMacroCount()
    local _, character = GetNumMacros()
    return character or 0
end

-- the first `count` characters of a UTF-8 string, without cutting a letter in half
local function Cut(text, count)
    local out, n = {}, 0
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > count then break end
        out[#out + 1] = char
    end
    return table.concat(out)
end

local function MacroExists(name)
    local index = GetMacroIndexByName(name)
    return index and index > 0
end

local function NewMacroName(spell)
    local base = ns.PREFIX .. Cut(spell, 11)
    local name, n = base, 1
    while ns.char.macros[name] or MacroExists(name) do
        n = n + 1
        name = Cut(base, 13) .. " " .. n
    end
    return name
end

-- a SmartCast macro with this text: the one we already have, or a new one
local function EnsureMacro(p)
    for name, m in pairs(ns.char.macros) do
        if m.body == p.body then
            if MacroExists(name) then return name end
            ns.char.macros[name] = nil   -- deleted by hand: forget it
        end
    end
    if ns.CharacterMacroCount() >= MaxCharacterMacros() then return nil end
    local name = NewMacroName(p.name)
    local ok, index = pcall(CreateMacro, name, QUESTION_ICON, p.body, true)
    if not ok or not index then return nil end
    ns.char.macros[name] = { id = p.id, body = p.body }
    return name
end

local function PutMacro(slot, name)
    ClearCursor()
    PickupMacro(name)
    if not GetCursorInfo() then return false end
    PlaceAction(slot)
    ClearCursor()
    return true
end

local function PutSpell(slot, id)
    ClearCursor()
    if C_Spell and C_Spell.PickupSpell then pcall(C_Spell.PickupSpell, id) else pcall(PickupSpell, id) end
    if not GetCursorInfo() then return false end
    PlaceAction(slot)
    ClearCursor()
    return true
end

-- delete SmartCast macros no button uses any more
local function Cleanup()
    local used = {}
    for slot = 1, ns.MAX_SLOT do
        local s = ns.ReadSlot(slot)
        if s and s.kind == "ours" then used[s.name] = true end
    end
    local unused = {}
    for name in pairs(ns.char.macros) do
        if not used[name] then unused[#unused + 1] = name end
    end
    for _, name in ipairs(unused) do
        if MacroExists(name) then pcall(DeleteMacro, name) end
        ns.char.macros[name] = nil
    end
    for slot in pairs(ns.char.applied) do
        local s = ns.ReadSlot(slot)
        if not (s and s.kind == "ours") then ns.char.applied[slot] = nil end
    end
end

---------------------------------------------------------------------------
-- Apply / undo
---------------------------------------------------------------------------
local pending

-- many buttons change at once while applying: redraw once, a moment later
local redrawQueued
local function Redraw()
    redrawQueued = nil
    if ns.RefreshWindow then ns.RefreshWindow() end
    if ns.RefreshMinimap then ns.RefreshMinimap() end
end
local function Changed()
    if redrawQueued then return end
    redrawQueued = true
    if C_Timer and C_Timer.After then C_Timer.After(0.05, Redraw) else Redraw() end
end
ns.Changed = Changed

function ns.Apply()
    if InCombatLockdown() then
        pending = "apply"
        print("|cff66ccffSmartCast:|r " .. L["In combat: it will run when combat ends."])
        return
    end
    local converted, restored, full = 0, 0, 0
    for slot = 1, ns.MAX_SLOT do
        local p = ns.Plan(slot)
        if p and p.id then
            if p.template == "skip" then
                if p.current == "ours" and PutSpell(slot, p.id) then
                    restored = restored + 1
                    ns.char.applied[slot] = nil
                end
            elseif p.state ~= "converted" then
                local name = EnsureMacro(p)
                if name and PutMacro(slot, name) then
                    ns.char.applied[slot] = { id = p.id }
                    converted = converted + 1
                elseif not name then
                    full = full + 1
                end
            end
        end
    end
    Cleanup()
    print("|cff66ccffSmartCast:|r " .. (L["Done: %d converted, %d restored."]):format(converted, restored))
    if full > 0 then
        print("|cff66ccffSmartCast:|r " .. (L["Character macros are full: %d buttons left as they were."]):format(full))
    end
    Changed()
end

function ns.Undo()
    if InCombatLockdown() then
        pending = "undo"
        print("|cff66ccffSmartCast:|r " .. L["In combat: it will run when combat ends."])
        return
    end
    local count = 0
    for slot = 1, ns.MAX_SLOT do
        local s = ns.ReadSlot(slot)
        if s and s.kind == "ours" then
            local applied, macro = ns.char.applied[slot], ns.char.macros[s.name]
            local id = (applied and applied.id) or (macro and macro.id)
            if id and PutSpell(slot, id) then count = count + 1 end
        end
    end
    wipe(ns.char.applied)
    Cleanup()
    print("|cff66ccffSmartCast:|r " .. (L["Undone: %d spells put back."]):format(count))
    Changed()
end

function ns.Counts()
    local converted, todo = 0, 0
    for slot = 1, ns.MAX_SLOT do
        local p = ns.Plan(slot)
        if p and p.state then
            if p.state == "converted" then converted = converted + 1
            elseif p.state == "pending" or p.state == "changed" then todo = todo + 1 end
        end
    end
    return converted, todo
end

-- settings for one button
function ns.SetSlot(slot, key, value)
    local p = ns.Plan(slot)
    if not (p and p.name) then return end
    local o = ns.char.slots[slot]
    if not o or o.spell ~= p.name then
        o = { spell = p.name }
        ns.char.slots[slot] = o
    end
    o[key] = value
    Changed()
end

---------------------------------------------------------------------------
-- Events and commands
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        SmartCastForeverDB = SmartCastForeverDB or {}
        SmartCastForeverCharDB = SmartCastForeverCharDB or {}
        Fill(SmartCastForeverDB, { minimapAngle = 200, minimapHidden = false })
        Fill(SmartCastForeverCharDB, DEFAULTS)
        ns.db, ns.char = SmartCastForeverDB, SmartCastForeverCharDB
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        local what = pending
        pending = nil
        if what == "apply" then ns.Apply() else ns.Undo() end
    elseif event == "ACTIONBAR_SLOT_CHANGED" and ns.char then
        Changed()
    end
end)

SLASH_SMARTCASTFOREVER1 = "/scf"
SLASH_SMARTCASTFOREVER2 = "/smartcast"
SlashCmdList.SMARTCASTFOREVER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "apply" then ns.Apply()
    elseif msg == "undo" then ns.Undo()
    elseif msg == "help" then print("|cff66ccffSmartCast:|r " .. L["Commands: /scf (window), /scf apply, /scf undo"])
    elseif ns.ToggleWindow then ns.ToggleWindow() end
end
