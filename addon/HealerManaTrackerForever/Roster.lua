local _, addon = ...
local Config, Mana = addon.Config, addon.Mana
local isSecret = issecretvalue

local healingClasses = { DRUID = true, PALADIN = true, PRIEST = true, SHAMAN = true }
local partyUnitTokens = { "party1", "party2", "party3", "party4" }
local partyUnitAliases = { player = true }
for _, unitToken in ipairs(partyUnitTokens) do
    partyUnitAliases[unitToken] = true
end
local raidUnitTokens = {}
for index = 1, 40 do
    raidUnitTokens[index] = "raid" .. index
end

local Roster = {
    manaUsers = {},
    trackedMembers = {},
    groupUnitTokens = {},
    manaUsersByUnit = {},
    groupType = "solo",
}
addon.Roster = Roster

local function ReadCharacterIdentity(unitToken)
    local name, realm = UnitFullName(unitToken)
    if isSecret(name) or not name or name == "" or name == UNKNOWNOBJECT or name == UNKNOWN then
        return
    end
    if isSecret(realm) then
        return name
    end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName()
    end
    if realm and realm ~= "" then
        return name, realm, realm .. "/" .. name
    end
    return name
end

local function GetHealerStatus(unitToken, override)
    if override == "include" then
        return "healer"
    elseif override == "exclude" then
        return
    end

    local assignedRole = UnitGroupRolesAssigned(unitToken)
    if not isSecret(assignedRole) then
        if assignedRole == "HEALER" then
            return "healer"
        elseif assignedRole == "TANK" or assignedRole == "DAMAGER" then
            return
        end
    end

    local _, classToken = UnitClass(unitToken)
    if not isSecret(classToken) and healingClasses[classToken] then
        return "candidate"
    end
end

local function AddGroupMember(unitToken)
    Roster.groupUnitTokens[unitToken] = true
    if not UnitExists(unitToken) or not Mana.HasMana(unitToken) then
        return
    end

    local name, realm, characterKey = ReadCharacterIdentity(unitToken)
    local override = characterKey and Config.values.overrides[characterKey]
    local healerStatus = GetHealerStatus(unitToken, override)
    local trackAllManaUsers = Config.values.tracking == "allMana"
    local member = {
        unitToken = unitToken,
        name = name,
        realm = realm,
        characterKey = characterKey,
        isHealerCandidate = healerStatus == "candidate" and not trackAllManaUsers,
    }
    Roster.manaUsers[#Roster.manaUsers + 1] = member
    Roster.manaUsersByUnit[unitToken] = member
    if healerStatus then
        Roster.hasTrackedHealer = true
    end
    if healerStatus or (trackAllManaUsers and override ~= "exclude") then
        Roster.trackedMembers[#Roster.trackedMembers + 1] = member
    end
end

function Roster.Rebuild()
    wipe(Roster.manaUsers)
    wipe(Roster.trackedMembers)
    wipe(Roster.groupUnitTokens)
    wipe(Roster.manaUsersByUnit)
    Roster.hasTrackedHealer = false

    if IsInRaid() then
        Roster.groupType = "raid"
        for index = 1, math.min(GetNumGroupMembers(), #raidUnitTokens) do
            AddGroupMember(raidUnitTokens[index])
        end
    elseif IsInGroup() then
        Roster.groupType = "party"
        AddGroupMember("player")
        for index = 1, math.min(GetNumSubgroupMembers(), #partyUnitTokens) do
            AddGroupMember(partyUnitTokens[index])
        end
    else
        Roster.groupType = "solo"
        AddGroupMember("player")
    end
end

function Roster.ResolveUnitToken(eventUnitToken)
    if isSecret(eventUnitToken) then
        return
    end
    if Roster.groupUnitTokens[eventUnitToken] then
        return eventUnitToken
    end
    if Roster.groupType == "raid" and partyUnitAliases[eventUnitToken] then
        local raidIndex = UnitInRaid(eventUnitToken)
        if not isSecret(raidIndex) then
            local raidUnitToken = raidUnitTokens[raidIndex]
            if Roster.groupUnitTokens[raidUnitToken] then
                return raidUnitToken
            end
        end
    end
end

function Roster.SetOverride(characterKey, choice)
    for _, member in ipairs(Roster.manaUsers) do
        if member.characterKey and member.characterKey == characterKey then
            Config.values.overrides[characterKey] = choice
            return true
        end
    end
end
