local _, addon = ...
local Locale, Config, Mana = addon.Locale, addon.Config, addon.Mana

local Display = { rows = {}, rowsByUnit = {} }
addon.Display = Display

local panelPadding = 4
local rowGap = 2
local valueTextWidthFactor = 5.3
local statusTextWidthFactor = 7
local previewManaPercentages = { 100, 63, 17 }

local function CreateBorder(frame)
    local sides = {}
    for index, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = frame:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(0.52, 0.43, 0.30, 0.9)
        if edge == "TOP" or edge == "BOTTOM" then
            line:SetPoint(edge .. "LEFT")
            line:SetPoint(edge .. "RIGHT")
            line:SetHeight(1)
        else
            line:SetPoint("TOP" .. edge, 0, -1)
            line:SetPoint("BOTTOM" .. edge, 0, 1)
            line:SetWidth(1)
        end
        sides[index] = line
    end
    return sides
end

local function SaveDragPosition(frame)
    if frame.dragging then
        frame.dragging = nil
        frame:StopMovingOrSizing()
        local point, _, relativePoint, offsetX, offsetY = frame:GetPoint(1)
        if not Config.SetPosition(point, relativePoint, offsetX, offsetY) then
            Display.ApplyPosition()
        end
    end
end

function Display.Initialize()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not Config.values.locked then
            self.dragging = true
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", SaveDragPosition)
    frame:SetScript("OnHide", SaveDragPosition)

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    local border = CreateBorder(frame)

    local viewport = CreateFrame("ScrollFrame", nil, frame)
    viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", panelPadding, -panelPadding)
    local content = CreateFrame("Frame", nil, viewport)
    viewport:SetScrollChild(content)
    local thumb = frame:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.61, 0.52, 0.36, 0.9)
    thumb:SetWidth(2)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        local scrollOffset = self:GetVerticalScroll() - delta * 3 * (Config.values.rowHeight + rowGap)
        Display.ScrollTo(scrollOffset)
    end)

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty:SetPoint("TOPLEFT", 4, 0)
    empty:SetPoint("RIGHT", -4, 0)
    empty:SetText(Locale.empty)

    Display.frame, Display.background, Display.border = frame, background, border
    Display.viewport, Display.content, Display.empty, Display.thumb = viewport, content, empty, thumb
end

function Display.ApplyPosition()
    local frame = Display.frame
    if frame.dragging then
        frame.dragging = nil
        frame:StopMovingOrSizing()
    end
    local position = Config.values.position
    frame:SetScale(Config.values.scale / 100)
    frame:ClearAllPoints()
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

local function GetOrCreateManaRow(index)
    local row = Display.rows[index]
    if row then
        return row
    end

    row = CreateFrame("StatusBar", nil, Display.content)
    if index == 1 then
        row:SetPoint("TOPLEFT", Display.content, "TOPLEFT")
    else
        row:SetPoint("TOPLEFT", Display.rows[index - 1], "BOTTOMLEFT", 0, -rowGap)
    end
    row:EnableMouse(false)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.085, 0.12, 0.94)
    local textureSet = row:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    if not textureSet then
        textureSet = row:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    end
    local fillTexture = textureSet and row:GetStatusBarTexture()
    if fillTexture then
        fillTexture:SetDrawLayer("ARTWORK")
    end

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", 6, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.nameText:SetMaxLines(1)

    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.valueText:SetPoint("RIGHT", -6, 0)
    row.valueText:SetJustifyH("RIGHT")
    row.valueText:SetWordWrap(false)
    row.valueText:SetMaxLines(1)
    Display.rows[index] = row
    return row
end

function Display.ScrollTo(scrollOffset)
    local maxScrollOffset = Display.maxScrollOffset
    scrollOffset = math.max(0, math.min(scrollOffset, maxScrollOffset))
    Display.viewport:SetVerticalScroll(scrollOffset)
    if maxScrollOffset > 0 then
        local thumbTravel = Display.viewport:GetHeight() - Display.thumb:GetHeight()
        Display.thumb:ClearAllPoints()
        Display.thumb:SetPoint("TOPLEFT", Display.viewport, "TOPRIGHT", 1,
            -thumbTravel * scrollOffset / maxScrollOffset)
    end
end

local function LayoutRowText(row, rowWidth, fontSize)
    local showValue = Config.values.showPercent or row.unitStatus ~= nil
    local valueTextWidth = fontSize * (row.unitStatus and statusTextWidthFactor or valueTextWidthFactor)
    local reservedWidth = showValue and valueTextWidth + 13 or 12
    row.nameText:SetWidth(rowWidth - reservedWidth)
    row.valueText:SetWidth(valueTextWidth)
    row.valueText:SetShown(showValue)
end

local function Layout(rowCount)
    local settings = Config.values
    local frame, viewport = Display.frame, Display.viewport
    local rowHeight = settings.rowHeight
    local fontSize = math.min(settings.fontSize, rowHeight - 2)
    local rowStride = rowHeight + rowGap
    local contentHeight = math.max(1, rowCount) * rowStride - rowGap
    local availableHeight = UIParent:GetHeight() * 0.8 / frame:GetScale() - 2 * panelPadding
    local rowsThatFit = math.max(1, math.floor((availableHeight + rowGap) / rowStride))
    local viewportHeight = math.min(contentHeight, rowsThatFit * rowStride - rowGap)
    Display.maxScrollOffset = contentHeight - viewportHeight
    local canScroll = Display.maxScrollOffset > 0
    local viewportWidth = settings.width - (canScroll and 4 or 0)

    frame:SetSize(settings.width + 2 * panelPadding, viewportHeight + 2 * panelPadding)
    if settings.locked then
        SaveDragPosition(frame)
    end
    frame:SetMovable(not settings.locked)
    frame:EnableMouse(not settings.locked)
    Display.background:SetColorTexture(0.024, 0.021, 0.018, settings.backgroundOpacity / 100)
    for _, line in ipairs(Display.border) do
        line:SetShown(settings.showBorder)
    end
    viewport:SetSize(viewportWidth, viewportHeight)
    viewport:EnableMouseWheel(canScroll)
    Display.content:SetSize(viewportWidth, contentHeight)
    Display.thumb:SetShown(canScroll)
    if canScroll then
        Display.thumb:SetHeight(math.min(viewportHeight, math.max(10, viewportHeight ^ 2 / contentHeight)))
    end
    Display.empty:SetHeight(rowHeight)
    Display.empty:SetShown(rowCount == 0)
    for index = 1, rowCount do
        local row = Display.rows[index]
        row:SetSize(viewportWidth, rowHeight)
        row:SetStatusBarColor(0.20, 0.52, 0.91, settings.fillOpacity / 100)
        row.nameText:SetFontHeight(fontSize)
        row.valueText:SetFontHeight(fontSize)
        row.valueText:SetHeight(rowHeight)
        LayoutRowText(row, viewportWidth, fontSize)
    end
    viewport:UpdateScrollChildRect()
    Display.ScrollTo(viewport:GetVerticalScroll())
end

function Display.ApplyLayout()
    if Display.frame:IsShown() then
        Layout(Display.visibleRowCount)
    end
end

local function ShowUnitMana(row, unitToken)
    if row.unitStatus then
        Mana.ClearBar(row, row.unitStatus)
    else
        Mana.UpdateBar(row, unitToken, Config.values.showPercent)
    end
end

function Display.UpdateUnitMana(unitToken)
    local row = Display.rowsByUnit[unitToken]
    if row and not row.unitStatus then
        if UnitExists(unitToken) then
            Mana.UpdateBar(row, unitToken, Config.values.showPercent)
        else
            Display.UpdateUnitStatus(unitToken)
        end
    end
end

function Display.UpdateUnitStatus(unitToken)
    local row = Display.rowsByUnit[unitToken]
    if not row then
        return
    end
    local unitStatus = Mana.ReadUnitStatus(unitToken)
    if unitStatus == row.unitStatus then
        return
    end
    row.unitStatus = unitStatus
    local settings = Config.values
    LayoutRowText(row, row:GetWidth(), math.min(settings.fontSize, settings.rowHeight - 2))
    ShowUnitMana(row, unitToken)
end

function Display.Render(roster, previewEnabled)
    wipe(Display.rowsByUnit)
    if not previewEnabled and not Config.ShouldShowPanel(roster.groupType, roster.hasTrackedHealer) then
        Display.frame:Hide()
        return
    end

    local rowCount = previewEnabled and #previewManaPercentages or #roster.trackedMembers
    if previewEnabled ~= Display.previewEnabled then
        Display.viewport:SetVerticalScroll(0)
        Display.previewEnabled = previewEnabled
    end

    for index = 1, rowCount do
        local row = GetOrCreateManaRow(index)
        if previewEnabled then
            row.unitStatus = nil
            row.nameText:SetText(Locale.sampleNames[index])
            Mana.SetPercent(row, previewManaPercentages[index], Config.values.showPercent)
        else
            local member = roster.trackedMembers[index]
            local name = member.name or Locale.unknown
            row.nameText:SetText(member.isHealerCandidate and Locale.candidate:format(name) or name)
            Display.rowsByUnit[member.unitToken] = row
            row.unitStatus = Mana.ReadUnitStatus(member.unitToken)
            ShowUnitMana(row, member.unitToken)
        end
        row:Show()
    end
    for index = rowCount + 1, #Display.rows do
        Display.rows[index]:Hide()
    end
    Display.visibleRowCount = rowCount
    Layout(rowCount)
    Display.frame:Show()
end
