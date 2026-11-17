local _, addon = ...
local Locale = addon.Locale
local isSecret = issecretvalue
local manaType = Enum.PowerType.Mana
local percentCurve = CurveConstants and CurveConstants.ScaleTo100

local Mana = {}
addon.Mana = Mana

function Mana.HasMana(unitToken)
    if UnitHasPowerType and UnitHasPowerType(unitToken, manaType) then
        return true
    end

    local maximum = UnitPowerMax(unitToken, manaType)
    return not isSecret(maximum) and type(maximum) == "number" and maximum > 0
end

function Mana.ReadUnitStatus(unitToken)
    if not UnitExists(unitToken) then
        return Locale.unavailable
    elseif not UnitIsConnected(unitToken) then
        return Locale.offline
    elseif UnitIsDeadOrGhost(unitToken) then
        return Locale.dead
    end
end

local function UsePercentRange(bar)
    if not bar.usesPercentRange then
        bar:SetMinMaxValues(0, 100)
        bar.usesPercentRange = true
    end
end

function Mana.ClearBar(bar, status)
    UsePercentRange(bar)
    bar:SetValue(0)
    bar.valueText:SetText(status or Locale.unavailable)
end

function Mana.SetPercent(bar, percent, showPercent)
    UsePercentRange(bar)
    bar:SetValue(percent)
    if showPercent then
        bar.valueText:SetFormattedText(Locale.percentage, percent)
    end
end

function Mana.UpdateBar(bar, unitToken, showPercent)
    if UnitPowerPercent and percentCurve then
        local percent = UnitPowerPercent(unitToken, manaType, false, percentCurve)
        if isSecret(percent) or type(percent) == "number" then
            Mana.SetPercent(bar, percent, showPercent)
            return
        end
    end

    local maximum = UnitPowerMax(unitToken, manaType)
    local current = UnitPower(unitToken, manaType)
    local maximumIsSecret, currentIsSecret = isSecret(maximum), isSecret(current)
    if (not maximumIsSecret and (type(maximum) ~= "number" or maximum <= 0))
        or (not currentIsSecret and type(current) ~= "number") then
        Mana.ClearBar(bar)
        return
    end

    bar:SetMinMaxValues(0, maximum)
    bar.usesPercentRange = false
    bar:SetValue(current)
    if showPercent then
        if maximumIsSecret or currentIsSecret then
            bar.valueText:SetText(Locale.unavailable)
        else
            bar.valueText:SetFormattedText(Locale.percentage, 100 * current / maximum)
        end
    end
end
