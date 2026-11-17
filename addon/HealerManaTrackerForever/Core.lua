local _, addon = ...
local Config, Display, Mana = addon.Config, addon.Display, addon.Mana
local Options, Roster, Locale = addon.Options, addon.Roster, addon.Locale
local isSecret = issecretvalue

local previewEnabled = false
local restrictionRefreshPending = false

local function RenderPanel()
    Display.Render(Roster, previewEnabled)
end

function addon.RefreshRoster()
    Roster.Rebuild()
    Options.RefreshMembers()
    if not previewEnabled then
        RenderPanel()
    end
end

function addon.ChangeOption(settingKey, value)
    Config.SetOption(settingKey, value)
    if settingKey == "tracking" then
        addon.RefreshRoster()
    elseif settingKey == "visibility" or settingKey == "hideWithoutHealers" or settingKey == "showPercent" then
        RenderPanel()
    else
        if settingKey == "scale" then
            Display.ApplyPosition()
        end
        Display.ApplyLayout()
    end
end

local function PrintMessage(message)
    print(addon.title .. " — " .. message)
end

local function HandleSlashCommand(input)
    if isSecret(input) then
        return
    end
    local command = (input or ""):match("^%s*(.-)%s*$"):lower()
    if command == "" or command == "members" then
        Options.Open(command == "members")
    elseif command == "preview" then
        previewEnabled = not previewEnabled
        RenderPanel()
        PrintMessage(previewEnabled and Locale.previewOn or Locale.previewOff)
    elseif command == "position" then
        Config.ResetPosition()
        Display.ApplyPosition()
        PrintMessage(Locale.resetPosition)
    elseif command == "reset" then
        previewEnabled = false
        Config.Load(nil)
        Display.ApplyPosition()
        Options.UpdateControls()
        addon.RefreshRoster()
        PrintMessage(Locale.resetAll)
    else
        PrintMessage(Locale.help)
    end
end

local rosterChangeEvents = {
    PLAYER_ENTERING_WORLD = true,
    GROUP_ROSTER_UPDATE = true,
    PLAYER_ROLES_ASSIGNED = true,
    ROLE_CHANGED_INFORM = true,
}

local unitUpdateEvents = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE",
    "UNIT_CONNECTION",
    "UNIT_FLAGS",
    "UNIT_HEALTH",
}

local function OnPlayerLogin(eventFrame)
    eventFrame:UnregisterEvent("PLAYER_LOGIN")
    Config.Load(HealerManaTrackerForeverDB)
    Display.Initialize()
    Display.ApplyPosition()
    Options.Register()
    SLASH_HEALERMANATRACKERFOREVER1 = "/hmtracker"
    SlashCmdList.HEALERMANATRACKERFOREVER = HandleSlashCommand

    for event in pairs(rosterChangeEvents) do
        eventFrame:RegisterEvent(event)
    end
    for _, event in ipairs(unitUpdateEvents) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:RegisterEvent("UI_SCALE_CHANGED")
    eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    addon.RefreshRoster()
end

local function RefreshAfterRestrictionChange()
    restrictionRefreshPending = false
    addon.RefreshRoster()
end

local function HandleUnitEvent(event, eventUnitToken, powerToken)
    if (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER")
        and (isSecret(powerToken) or powerToken ~= "MANA") then
        return
    end

    local unitToken = Roster.ResolveUnitToken(eventUnitToken)
    if not unitToken then
        return
    end

    if event == "UNIT_POWER_UPDATE" then
        Display.UpdateUnitMana(unitToken)
        return
    end
    if event == "UNIT_NAME_UPDATE" then
        addon.RefreshRoster()
        return
    end
    if event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_CONNECTION" then
        if UnitExists(unitToken) and UnitIsConnected(unitToken) then
            local wasManaUser = Roster.manaUsersByUnit[unitToken] ~= nil
            if Mana.HasMana(unitToken) ~= wasManaUser then
                addon.RefreshRoster()
                return
            end
        end
    end

    if event == "UNIT_FLAGS" or event == "UNIT_HEALTH" or event == "UNIT_CONNECTION" then
        Display.UpdateUnitStatus(unitToken)
    else
        Display.UpdateUnitMana(unitToken)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, unitToken, powerToken)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin(self)
    elseif rosterChangeEvents[event] then
        addon.RefreshRoster()
    elseif event == "UI_SCALE_CHANGED" then
        Display.ApplyPosition()
        Display.ApplyLayout()
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        if not restrictionRefreshPending then
            -- Restrictions can still be activating during this event.
            restrictionRefreshPending = true
            C_Timer.After(0, RefreshAfterRestrictionChange)
        end
    else
        HandleUnitEvent(event, unitToken, powerToken)
    end
end)
