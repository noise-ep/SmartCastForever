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
    friendAssist = L["Friend, enemy's target or me"],
    self = L["Always myself"],
    skip = L["Don't touch"],
}

local function Conditions(template, kind)
    if template == "enemyAssist" then
        -- the last, empty condition: no match, so it does what a plain button does
        -- (an error with no target, or the game's own auto-targeting)
        return "[@target,harm,nodead][@targettarget,harm,nodead][]"
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
    oldRank = "ask",   -- a button with an older rank than you know: "ask" | "max" | "keep"
    autoUpgrade = true, -- plain spells on the bars follow the highest rank you learn
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

-- how far the spell reaches; 0 for spells that need no target (Arcane Explosion,
-- Frost Nova, armors), nil when the game doesn't say
local function MaxRange(id)
    local info = Try(C_Spell and C_Spell.GetSpellInfo, id)
    if type(info) == "table" then return info.maxRange end
    if GetSpellInfo then
        local ok, _, _, _, _, _, maxRange = pcall(GetSpellInfo, id)
        if ok then return maxRange end
    end
end

function ns.SpellKind(id)
    -- a spell cast around or on yourself has no target to choose: it counts as
    -- "other", so the default rules leave it alone
    if MaxRange(id) == 0 then return "other" end
    if Try(C_Spell and C_Spell.IsSpellHarmful, id) or Try(IsHarmfulSpell, ns.SpellName(id) or id) then
        return "harmful"
    end
    if Try(C_Spell and C_Spell.IsSpellHelpful, id) or Try(IsHelpfulSpell, ns.SpellName(id) or id) then
        return "helpful"
    end
    return "other"
end

-- every rank of `name` in your spellbook: { { id = , rank = "Rank 1" }, ... } lowest first
local rankCache = {}
function ns.ClearRankCache() wipe(rankCache) end

local ScanRanks
function ns.KnownRanks(name)
    local list = rankCache[name]
    if not list then
        list = ScanRanks(name)
        rankCache[name] = list
    end
    return list
end

ScanRanks = function(name)
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

function ns.IsOurSlot(slot)
    local s = ns.ReadSlot(slot)
    return s and s.kind == "ours" or false
end

-- Everything SmartCast decides about one button
function ns.Plan(slot)
    if ns.demoMode then return ns.demo and ns.demo[slot] end
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
        -- "none" | "channel" | "all"; older settings saved a plain true for "all"
        stopMode = o and (o.stopMode or (o.stopCasting and "all")) or "none",
        noToggle = db.noToggle and true or false,
    }
    -- ranks: does the button hold an older rank than the best one you know?
    if p.rank then
        local ranks = ns.KnownRanks(name)
        local best = ranks[#ranks]
        if best and best.n > (tonumber(p.rank:match("%d+")) or 0) then
            p.best, p.outdated = best, true
        end
    end
    p.decided = o and (o.rankDecided or o.rank ~= nil) and true or false
    -- a macro that already follows the highest rank is up to date, whatever rank it replaced
    if p.outdated and s.kind == "ours" and p.decided and not p.fixedRank then
        p.outdated, p.best = nil, nil
    end
    p.needsDecision = p.outdated and not p.decided or false

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
    -- the spell named in #showtooltip: the button keeps its icon and tooltip even when
    -- no condition matches (no target yet), instead of a question mark
    -- /stopcasting first: cuts a wand shot (or anything else being cast) so this spell goes out now
    -- "all": cuts anything being cast (a wand shot too); "channel": only a channeled
    -- spell, so a spell with a cast time never cuts itself on a second press
    local stop = (p.stopMode == "all" and "/stopcasting\n")
        or (p.stopMode == "channel" and "/stopcasting [channeling]\n") or ""
    return ("#showtooltip %s\n%s/cast %s %s%s"):format(spell, stop, cond, p.noToggle and "!" or "", spell)
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
    if ns.RefreshButtonNames then ns.RefreshButtonNames() end
end
local function Changed()
    if redrawQueued then return end
    redrawQueued = true
    if C_Timer and C_Timer.After then C_Timer.After(0.05, Redraw) else Redraw() end
end
ns.Changed = Changed

---------------------------------------------------------------------------
-- Older ranks on the bars
---------------------------------------------------------------------------
local function Say(text) print("|cff66ccffSmartCast:|r " .. text) end

-- remember for this button: keep `rank` (a "Rank 3" text), or nil = always the highest
local function Decide(slot, name, rank)
    local o = ns.char.slots[slot]
    if not o or o.spell ~= name then
        o = { spell = name }
        ns.char.slots[slot] = o
    end
    o.rankDecided, o.rank = true, rank
end

-- Buttons already at their highest rank are marked "keep it at the highest", so a rank
-- learned later counts as an upgrade, not as a question. Older ranks follow the
-- "older ranks" setting; with "ask" they wait for you. Returns how many still wait.
function ns.ResolveRanks()
    if not ns.char or ns.demoMode then return 0 end
    local waiting = 0
    for slot = 1, ns.MAX_SLOT do
        local p = ns.Plan(slot)
        if p and p.name and p.rank and not p.decided then
            if not p.outdated then
                Decide(slot, p.name, nil)
            elseif ns.char.oldRank == "max" then
                Decide(slot, p.name, nil)
            elseif ns.char.oldRank == "keep" then
                Decide(slot, p.name, p.rank)
            else
                waiting = waiting + 1
            end
        end
    end
    return waiting
end

-- the buttons waiting for a decision that it matters for: ones being converted,
-- and plain spells when they are kept at the highest rank
local function Waiting()
    local list = {}
    for slot = 1, ns.MAX_SLOT do
        local p = ns.Plan(slot)
        if p and p.needsDecision and (p.template ~= "skip" or (p.current == "spell" and ns.char.autoUpgrade)) then
            list[#list + 1] = p
        end
    end
    return list
end
ns.WaitingRanks = Waiting

function ns.DecideAll(list, keep)
    for _, p in ipairs(list) do Decide(p.slot, p.name, keep and p.rank or nil) end
end

function ns.DecideSlot(slot, keep)
    if ns.demoMode then
        local d = ns.demo[slot]
        if d then d.needsDecision, d.decided = false, true; if keep then d.fixedRank = d.rank end end
        ns.Changed()
        return
    end
    local p = ns.Plan(slot)
    if p and p.name then Decide(slot, p.name, keep and p.rank or nil) end
    ns.Changed()
end

-- plain spells on the bars that should follow the highest rank: put the new rank there
local upgradePending
function ns.Upgrade(quiet)
    if not (ns.char and ns.char.autoUpgrade) or ns.demoMode then return 0 end
    if InCombatLockdown() then upgradePending = true return 0 end
    local done, perSpell = 0, {}
    for slot = 1, ns.MAX_SLOT do
        local p = ns.Plan(slot)
        if p and p.current == "spell" and p.outdated and p.decided and not p.fixedRank and p.best then
            if PutSpell(slot, p.best.id) then
                done = done + 1
                local e = perSpell[p.name] or { rank = p.best.rank, count = 0 }
                e.count = e.count + 1
                perSpell[p.name] = e
            end
        end
    end
    if not quiet then
        for name, e in pairs(perSpell) do
            Say((L["%s updated to %s on %d buttons."]):format(name, e.rank, e.count))
        end
    end
    return done
end

StaticPopupDialogs["SMARTCASTFOREVER_OLD_RANKS"] = {
    text = "SmartCast Forever\n\n%s",
    button1 = L["Use the highest"],
    button2 = L["Review"],
    button3 = L["Keep them"],
    OnAccept = function(_, list) ns.DecideAll(list, false); ns.Apply() end,
    OnAlt = function(_, list) ns.DecideAll(list, true); ns.Apply() end,
    OnCancel = function(_, list)
        if ns.ShowSlot and list and list[1] then ns.ShowSlot(list[1].slot) end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function ns.Apply()
    if ns.demoMode then Say(L["Demo mode: your bars are not changed. /scf demo to leave it."]) return end
    if InCombatLockdown() then
        pending = "apply"
        print("|cff66ccffSmartCast:|r " .. L["In combat: it will run when combat ends."])
        return
    end
    ns.ResolveRanks()
    local waiting = Waiting()
    if #waiting > 0 then
        StaticPopup_Show("SMARTCASTFOREVER_OLD_RANKS",
            (L["%d buttons hold an older rank than one you know. Use the highest rank, or keep the one they have?"]):format(#waiting),
            nil, waiting)
        return
    end
    ns.Upgrade()
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
    if ns.demoMode then Say(L["Demo mode: your bars are not changed. /scf demo to leave it."]) return end
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
    if ns.demoMode then
        local d = ns.demo[slot]
        if not (d and d.name) then return end
        if key == "mode" then
            d.mode = value
            d.template = value == "default" and (ns.char.defaults[d.kind] or "skip") or value
            d.state = d.template == "skip" and "skip" or d.state == "skip" and "pending" or d.state
        elseif key == "rank" then
            d.fixedRank = value
        elseif key == "shiftSelf" then
            d.shiftSelf = value
        elseif key == "stopMode" then
            d.stopMode = value
        end
        d.body = d.template ~= "skip" and ns.Body(d) or nil
        ns.Changed()
        return
    end
    local p = ns.Plan(slot)
    if not (p and p.name) then return end
    local o = ns.char.slots[slot]
    if not o or o.spell ~= p.name then
        o = { spell = p.name }
        ns.char.slots[slot] = o
    end
    o[key] = value
    if key == "rank" then o.rankDecided = true end
    Changed()
end

---------------------------------------------------------------------------
-- Demo: a tidy, made-up set of buttons built from your own spells, for screenshots.
-- Your bars are not read or changed while it is on; Apply and Undo do nothing.
---------------------------------------------------------------------------
local function BookSpells()
    local list, byName = {}, {}
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not (book and book.GetNumSpellBookSkillLines and bank) then return list end
    for line = 1, (Try(book.GetNumSpellBookSkillLines) or 0) do
        local info = Try(book.GetSpellBookSkillLineInfo, line)
        if info and not info.isGuild and info.itemIndexOffset and info.numSpellBookItems then
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = Try(book.GetSpellBookItemInfo, i, bank)
                local id = item and (item.actionID or item.spellID)
                if id and item.name and not item.isPassive then
                    local n = tonumber((item.subName or ""):match("%d+")) or 0
                    local e = byName[item.name]
                    if not e then
                        e = { name = item.name }
                        byName[item.name] = e
                        list[#list + 1] = e
                    end
                    if not e.n or n > e.n then
                        e.id, e.n = id, n
                        e.rank = n > 0 and item.subName or nil
                    end
                end
            end
        end
    end
    return list
end

local function DemoPlan(slot, e, template, state)
    local kind = ns.SpellKind(e.id)
    local p = {
        slot = slot, current = state == "converted" and "ours" or "spell",
        id = e.id, name = e.name, kind = kind, icon = ns.SpellIcon(e.id), rank = e.rank,
        mode = "default", template = template, noToggle = ns.char.noToggle and true or false,
        shiftSelf = false, stopMode = "none", state = state, decided = true, needsDecision = false,
    }
    if template ~= (ns.char.defaults[kind] or "skip") then p.mode = template end
    if template ~= "skip" then p.body = ns.Body(p) end
    return p
end

local function ItemIcon(id)
    return Try(C_Item and C_Item.GetItemIconByID, id) or Try(GetItemIcon, id)
end

function ns.BuildDemo()
    local harm, help, other = {}, {}, {}
    for _, e in ipairs(BookSpells()) do
        local kind = ns.SpellKind(e.id)
        local t = kind == "harmful" and harm or kind == "helpful" and help or other
        t[#t + 1] = e
    end
    local demo = {}
    -- Action Bar 1: damage spells, converted; the last two still pending, one of
    -- them with an older rank waiting for your choice
    for i = 1, math.min(#harm, 10) do
        local e = harm[i]
        local p = DemoPlan(i, e, "enemyAssist", i <= math.min(#harm, 10) - 2 and "converted" or "pending")
        if p.state == "pending" and e.n and e.n > 1 and not demo.older then
            demo.older = true
            p.best = { rank = e.rank }
            p.rank = (e.rank:gsub("%d+", "1", 1))
            p.outdated, p.needsDecision, p.decided = true, true, false
        end
        demo[i] = p
    end
    -- Action Bar 2: helping spells, the first ones on "friend, else my enemy's target"
    for i = 1, math.min(#help, 10) do
        demo[60 + i] = DemoPlan(60 + i, help[i], i <= 3 and "friendAssist" or "skip", i <= 3 and "converted" or "skip")
    end
    -- Action Bar 3: everything else, left alone, plus a couple of items SmartCast ignores
    local n = 0
    for i = 1, math.min(#other, 8) do
        n = 48 + i
        demo[n] = DemoPlan(n, other[i], "skip", "skip")
    end
    for _, item in ipairs({ 6948, 159 }) do
        n = n + 1
        if n > 60 then break end
        demo[n] = { slot = n, current = "foreign", icon = ItemIcon(item) }
    end
    demo.older = nil
    ns.demo = demo
end

function ns.ToggleDemo()
    if ns.demoMode then
        ns.demoMode, ns.demo = nil, nil
        Say(L["Demo mode off: showing your real bars again."])
    else
        ns.BuildDemo()
        ns.demoMode = true
        Say(L["Demo mode: your bars are not changed. /scf demo to leave it."])
    end
    if ns.ShowSlot then ns.ShowSlot(nil) end
    ns.Changed()
end

---------------------------------------------------------------------------
-- Events and commands
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("SPELLS_CHANGED")
pcall(events.RegisterEvent, events, "LEARNED_SPELL_IN_TAB")

-- spells change in bursts (a trainer visit, a login): act once, a moment later
local spellsQueued
local function SpellsSettled()
    spellsQueued = nil
    ns.ClearRankCache()
    ns.Upgrade()
    Changed()
end
local resolveQueued
local function ResolveSettled()
    resolveQueued = nil
    ns.ResolveRanks()
    Changed()
end
local function Later(flag, fn, delay)
    if flag then return true end
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
    return true
end
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        SmartCastForeverDB = SmartCastForeverDB or {}
        SmartCastForeverCharDB = SmartCastForeverCharDB or {}
        Fill(SmartCastForeverDB, { minimapAngle = 200, minimapHidden = false, hideNames = true })
        Fill(SmartCastForeverCharDB, DEFAULTS)
        ns.db, ns.char = SmartCastForeverDB, SmartCastForeverCharDB
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
    elseif not ns.char then
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then
            local what = pending
            pending = nil
            if what == "apply" then ns.Apply() else ns.Undo() end
        elseif upgradePending then
            upgradePending = nil
            ns.Upgrade()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                ns.ClearRankCache()
                local waiting = ns.ResolveRanks()
                if waiting > 0 and not ns.toldWaiting then
                    ns.toldWaiting = true
                    Say((L["%d buttons hold an older rank than one you know. Open /scf to choose."]):format(waiting))
                end
                Changed()
            end)
        end
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        spellsQueued = Later(spellsQueued, SpellsSettled, 1)
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        resolveQueued = Later(resolveQueued, ResolveSettled, 0.5)
        Changed()
    end
end)

SLASH_SMARTCASTFOREVER1 = "/scf"
SLASH_SMARTCASTFOREVER2 = "/smartcast"
SlashCmdList.SMARTCASTFOREVER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "apply" then ns.Apply()
    elseif msg == "undo" then ns.Undo()
    elseif msg == "demo" then ns.ToggleDemo()
    elseif msg == "help" then print("|cff66ccffSmartCast:|r " .. L["Commands: /scf (window), /scf apply, /scf undo"])
    elseif ns.ToggleWindow then ns.ToggleWindow() end
end
