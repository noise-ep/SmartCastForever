-- ButtonNames.lua: hide the macro name on buttons that hold a SmartCast macro, so they look
-- like the spell they replaced. Only the name text is faded; the button itself is untouched.
local _, ns = ...

local BAR_BUTTONS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local buttons = {}

local function SlotOf(button)
    local slot = button.action
    if not slot and button.GetAttribute then slot = tonumber(button:GetAttribute("action")) end
    return slot
end

local function Fix(button)
    local name = button.Name
    if not (name and ns.db) then return end
    local slot = SlotOf(button)
    local hide = ns.db.hideNames and slot and ns.IsOurSlot(slot)
    if hide then
        if not button.scfHidName then
            button.scfHidName = true
            name:SetAlpha(0)
        end
    elseif button.scfHidName then
        -- give it back only if we were the ones who hid it
        button.scfHidName = nil
        name:SetAlpha(1)
    end
end

function ns.RefreshButtonNames()
    for _, button in ipairs(buttons) do Fix(button) end
end

function ns.HookButtonNames()
    for _, prefix in ipairs(BAR_BUTTONS) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button and button.Name and not button.scfHooked then
                button.scfHooked = true
                buttons[#buttons + 1] = button
                hooksecurefunc(button.Name, "SetText", function() Fix(button) end)
            end
        end
    end
    ns.RefreshButtonNames()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_ENTERING_WORLD" then ns.HookButtonNames() else ns.RefreshButtonNames() end
end)
