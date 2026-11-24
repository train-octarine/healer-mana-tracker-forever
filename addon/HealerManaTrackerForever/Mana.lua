local _, addon = ...
local Locale, Config = addon.Locale, addon.Config
local isSecret = issecretvalue
local manaType = Enum.PowerType.Mana
local percentCurve = CurveConstants and CurveConstants.ScaleTo100
local lowManaColorCurve
local colorCurveThreshold

local Mana = {}
addon.Mana = Mana

local function GetLowManaColorCurve()
    if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then
        return
    end
    if not lowManaColorCurve then
        lowManaColorCurve = C_CurveUtil.CreateColorCurve()
        lowManaColorCurve:SetType(Enum.LuaCurveType.Step)
    end
    local threshold = Config.values.lowManaColorThreshold
    if colorCurveThreshold ~= threshold then
        lowManaColorCurve:ClearPoints()
        lowManaColorCurve:AddPoint(0, CreateColor(0.90, 0.20, 0.20))
        lowManaColorCurve:AddPoint(threshold / 100, CreateColor(0.20, 0.52, 0.91))
        lowManaColorCurve:AddPoint(1, CreateColor(0.20, 0.52, 0.91))
        colorCurveThreshold = threshold
    end
    return lowManaColorCurve
end

function Mana.ApplyBarColor(bar)
    local red, green, blue = 0.20, 0.52, 0.91
    if bar.manaColor then
        red, green, blue = bar.manaColor:GetRGB()
    end
    bar:SetStatusBarColor(red, green, blue, Config.values.fillOpacity / 100)
end

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
    bar.manaColor = nil
    Mana.ApplyBarColor(bar)
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

function Mana.SetPreviewPercent(bar, percent, showPercent)
    local curve = bar.useLowManaColor and GetLowManaColorCurve()
    bar.manaColor = curve and curve:Evaluate(percent / 100) or nil
    Mana.ApplyBarColor(bar)
    Mana.SetPercent(bar, percent, showPercent)
end

function Mana.UpdateBar(bar, unitToken, showPercent)
    bar.manaColor = nil
    if bar.useLowManaColor and UnitPowerPercent then
        local curve = GetLowManaColorCurve()
        if curve then
            -- Evaluate the color in the client while mana values may be secret.
            bar.manaColor = UnitPowerPercent(unitToken, manaType, false, curve)
        end
    end
    Mana.ApplyBarColor(bar)
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
