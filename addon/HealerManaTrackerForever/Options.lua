local addonName, addon = ...
local Config, Roster, Locale = addon.Config, addon.Roster, addon.Locale

local Options = { rows = {} }
addon.Options = Options

local settingOrder = {
    "visibility", "hideWithoutHealers", "tracking", "locked", "showPercent", "showBorder",
    "lowManaColorMode", "lowManaColorThreshold",
    "width", "rowHeight", "fontSize", "scale", "fillOpacity", "backgroundOpacity",
}

local memberRowHeight = 30

local function CreateSettingsControl(category, settingKey)
    local defaultValue = Config.defaultSettings[settingKey]
    local setting = Settings.RegisterProxySetting(category, addonName .. "_" .. settingKey,
        type(defaultValue), Locale[settingKey], defaultValue,
        function() return Config.values[settingKey] end,
        function(value) addon.ChangeOption(settingKey, value) end)
    local choices = Config.choices[settingKey]
    local range = Config.sliderRanges[settingKey]
    if choices then
        Settings.CreateDropdown(category, setting, function()
            local labels = Settings.CreateControlTextContainer()
            for _, choice in ipairs(choices) do
                labels:Add(choice, Locale[choice])
            end
            return labels:GetData()
        end, Locale[settingKey .. "Tip"])
    elseif range then
        local sliderOptions = Settings.CreateSliderOptions(range.minimum, range.maximum, range.step)
        local format = (settingKey == "scale" or settingKey == "fillOpacity" or settingKey == "backgroundOpacity"
            or settingKey == "lowManaColorThreshold")
            and Locale.percentage or "%.0f"
        sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return format:format(value)
        end)
        Settings.CreateSlider(category, setting, sliderOptions)
    else
        Settings.CreateCheckbox(category, setting, settingKey == "locked" and Locale.lockedTip or nil)
    end
end

local function AddTrackingChoice(menu, characterKey, choice, label)
    menu:CreateRadio(label,
        function() return Config.values.overrides[characterKey] == choice end,
        function()
            if Roster.SetOverride(characterKey, choice) then
                addon.RefreshRoster()
            end
        end)
end

local function GetOrCreateMemberRow(index)
    local row = Options.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, Options.content)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * memberRowHeight)
    row:SetPoint("RIGHT", -4, 0)
    row:SetHeight(memberRowHeight)

    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetPoint("RIGHT")
    button:SetSize(182, 24)
    button:SetScript("OnClick", function(self)
        local characterKey = row.characterKey
        MenuUtil.CreateContextMenu(self, function(_, menu)
            AddTrackingChoice(menu, characterKey, nil, Locale.useMode)
            AddTrackingChoice(menu, characterKey, "include", Locale.include)
            AddTrackingChoice(menu, characterKey, "exclude", Locale.exclude)
        end)
    end)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", 4, 0)
    label:SetPoint("RIGHT", button, "LEFT", -10, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetMaxLines(1)

    row.label, row.button = label, button
    Options.rows[index] = row
    return row
end

function Options.RefreshMembers()
    if not Options.panel:IsVisible() then
        return
    end

    local count = 0
    for _, member in ipairs(Roster.manaUsers) do
        if member.characterKey then
            count = count + 1
            local row = GetOrCreateMemberRow(count)
            row.characterKey = member.characterKey
            row.label:SetFormattedText(Locale.memberName, member.name, member.realm)
            row.button:SetText(Locale[Config.values.overrides[member.characterKey] or "useMode"])
            row:Show()
        end
    end
    for index = count + 1, #Options.rows do
        Options.rows[index]:Hide()
    end
    Options.empty:SetShown(count == 0)
    Options.content:SetHeight(math.max(1, count * memberRowHeight))
end

local function CreateMembersPanel()
    local panel = CreateFrame("Frame")
    panel:Hide()

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(Locale.members)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
    hint:SetPoint("RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(Locale.membersHint)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", -34, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", 4, -6)
    empty:SetText(Locale.noMembers)

    Options.panel, Options.content, Options.empty = panel, content, empty
    panel:SetScript("OnShow", Options.RefreshMembers)
    return panel
end

function Options.Register()
    Options.category = Settings.RegisterVerticalLayoutCategory(addon.title)
    for _, settingKey in ipairs(settingOrder) do
        CreateSettingsControl(Options.category, settingKey)
    end
    local membersPanel = CreateMembersPanel()
    Options.membersCategory = Settings.RegisterCanvasLayoutSubcategory(Options.category, membersPanel, Locale.members)
    Settings.RegisterAddOnCategory(Options.category)
end

function Options.Open(showManualTracking)
    local category = showManualTracking and Options.membersCategory or Options.category
    Settings.OpenToCategory(category:GetID())
end

function Options.UpdateControls()
    for _, settingKey in ipairs(settingOrder) do
        Settings.NotifyUpdate(addonName .. "_" .. settingKey)
    end
end
