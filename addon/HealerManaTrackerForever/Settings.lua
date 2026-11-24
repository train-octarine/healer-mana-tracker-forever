local _, addon = ...

local defaultSettings = {
    visibility = "grouped",
    hideWithoutHealers = false,
    tracking = "automatic",
    width = 224,
    rowHeight = 22,
    fillOpacity = 80,
    backgroundOpacity = 65,
    scale = 100,
    fontSize = 12,
    showPercent = true,
    showBorder = true,
    locked = true,
    lowManaColorMode = "disabled",
    lowManaColorThreshold = 50,
}

local sliderRanges = {
    width = { minimum = 160, maximum = 400, step = 4 },
    rowHeight = { minimum = 18, maximum = 36, step = 1 },
    fillOpacity = { minimum = 0, maximum = 100, step = 5 },
    backgroundOpacity = { minimum = 0, maximum = 100, step = 5 },
    scale = { minimum = 65, maximum = 155, step = 5 },
    fontSize = { minimum = 9, maximum = 18, step = 1 },
    lowManaColorThreshold = { minimum = 1, maximum = 99, step = 1 },
}

local defaultPosition = { point = "CENTER", relativePoint = "CENTER", x = 250, y = 100 }
local anchorPoints = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local Config = {
    defaultSettings = defaultSettings,
    sliderRanges = sliderRanges,
    choices = {
        visibility = { "always", "party", "raid", "grouped" },
        tracking = { "automatic", "allMana" },
        lowManaColorMode = { "disabled", "party", "grouped" },
    },
}
addon.Config = Config

local function ValidateSetting(settingKey, value)
    local defaultValue = defaultSettings[settingKey]
    if type(value) ~= type(defaultValue) then
        return defaultValue
    end

    local choices = Config.choices[settingKey]
    if choices then
        for _, choice in ipairs(choices) do
            if value == choice then
                return value
            end
        end
        return defaultValue
    end

    local range = sliderRanges[settingKey]
    if range then
        if value >= range.minimum and value <= range.maximum then
            local steps = math.floor((value - range.minimum) / range.step + 0.5)
            return range.minimum + steps * range.step
        end
        return defaultValue
    end
    return value
end

local function IsValidOffset(offset)
    return type(offset) == "number" and math.abs(offset) <= 8192
end

function Config.ResetPosition()
    Config.values.position = {
        point = defaultPosition.point, relativePoint = defaultPosition.relativePoint,
        x = defaultPosition.x, y = defaultPosition.y,
    }
end

function Config.SetPosition(point, relativePoint, offsetX, offsetY)
    if hasanysecretvalues(point, relativePoint, offsetX, offsetY) then
        return
    end
    if anchorPoints[point] and anchorPoints[relativePoint] and IsValidOffset(offsetX) and IsValidOffset(offsetY) then
        Config.values.position = { point = point, relativePoint = relativePoint, x = offsetX, y = offsetY }
        return true
    end
end

function Config.Load(savedSettings)
    savedSettings = type(savedSettings) == "table" and savedSettings or {}
    local settings = { overrides = {} }
    for settingKey in pairs(defaultSettings) do
        settings[settingKey] = ValidateSetting(settingKey, savedSettings[settingKey])
    end

    if type(savedSettings.overrides) == "table" then
        for characterKey, choice in pairs(savedSettings.overrides) do
            if type(characterKey) == "string" and #characterKey <= 250 and characterKey:match("^[^/]+/[^/]+$")
                and (choice == "include" or choice == "exclude") then
                settings.overrides[characterKey] = choice
            end
        end
    end

    HealerManaTrackerForeverDB = settings
    Config.values = settings
    local position = savedSettings.position
    if type(position) == "table" then
        Config.SetPosition(position.point, position.relativePoint, position.x, position.y)
    end
    if not settings.position then
        Config.ResetPosition()
    end
end

function Config.SetOption(settingKey, value)
    Config.values[settingKey] = ValidateSetting(settingKey, value)
end

function Config.ShouldShowPanel(groupType, hasTrackedHealer)
    if Config.values.hideWithoutHealers and groupType ~= "solo" and not hasTrackedHealer then
        return false
    end
    local visibility = Config.values.visibility
    return visibility == "always" or visibility == groupType or (visibility == "grouped" and groupType ~= "solo")
end
