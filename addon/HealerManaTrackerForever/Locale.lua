local _, addon = ...

addon.title = "Healer Mana Tracker Forever"

local english = {
    empty = "No healers to track",
    unknown = "Unknown member",
    candidate = "%s (?)",
    offline = "Offline",
    dead = "Dead",
    unavailable = "—",
    percentage = "%.0f%%",
    sampleNames = { "Rowan", "Marigold", "Ashwood" },
    previewOn = "Preview enabled. Use /hmtracker preview to exit.",
    previewOff = "Preview disabled.",
    visibility = "Show panel",
    always = "Always",
    party = "Party only",
    raid = "Raid only",
    grouped = "Party or raid",
    hideWithoutHealers = "Hide in parties or raids without healers",
    tracking = "Players to track",
    automatic = "Healers (automatic)",
    allMana = "Everyone with mana",
    trackingTip = "Automatic mode uses assigned roles."
        .. " A question mark indicates a player who may be a healer.",
    width = "Bar width",
    rowHeight = "Bar height",
    fillOpacity = "Mana fill opacity",
    backgroundOpacity = "Panel background opacity",
    scale = "Panel scale",
    fontSize = "Font size",
    showPercent = "Show mana percentage",
    showBorder = "Show panel border",
    locked = "Lock panel position",
    lockedTip = "Unlock to drag the panel with the left mouse button.",
    members = "Manual tracking",
    membersHint = "Choose which players to track. Choices are saved by character name and realm"
        .. " and apply in both tracking modes.",
    noMembers = "No players with mana and a known character name.",
    memberName = "%s — %s",
    useMode = "Use tracking mode",
    include = "Include",
    exclude = "Exclude",
    resetPosition = "Panel position reset.",
    resetAll = "Settings reset.",
    help = "/hmtracker — settings, /hmtracker members — manual tracking, /hmtracker preview — toggle preview, "
        .. "/hmtracker position — reset position, /hmtracker reset — reset all settings, /hmtracker help — help.",
}

local russian = {
    empty = "Нет лекарей для отслеживания",
    unknown = "Неизвестный участник",
    candidate = "%s (?)",
    unavailable = "—",
    percentage = "%.0f%%",
    sampleNames = { "Рябина", "Календула", "Ясень" },
    previewOn = "Предпросмотр включён. Для выхода введите /hmtracker preview.",
    previewOff = "Предпросмотр отключён.",
    visibility = "Показывать панель",
    always = "Всегда",
    party = "Только в группе",
    raid = "Только в рейде",
    grouped = "В группе или рейде",
    hideWithoutHealers = "Скрывать панель, если нет лекарей",
    tracking = "Кого отслеживать",
    automatic = "Лекари (автоматически)",
    allMana = "Все с маной",
    trackingTip = "Автоматический режим учитывает назначенные роли."
        .. " Знаком вопроса отмечены возможные лекари.",
    width = "Ширина полосы",
    rowHeight = "Высота полосы",
    fillOpacity = "Непрозрачность заливки маны",
    backgroundOpacity = "Непрозрачность фона панели",
    scale = "Масштаб панели",
    fontSize = "Размер шрифта",
    showPercent = "Показывать процент маны",
    showBorder = "Показывать рамку панели",
    locked = "Закрепить панель",
    lockedTip = "Снимите флажок, чтобы перетащить панель левой кнопкой мыши.",
    members = "Ручное отслеживание",
    membersHint = "Выберите, кого отслеживать. Выбор сохраняется по имени персонажа и игровому миру"
        .. " и действует в обоих режимах.",
    noMembers = "Нет участников с маной, чьи имена известны.",
    memberName = "%s — %s",
    useMode = "По режиму отслеживания",
    include = "Включить",
    exclude = "Исключить",
    resetPosition = "Положение панели сброшено.",
    resetAll = "Настройки сброшены.",
    help = "/hmtracker — настройки, /hmtracker members — ручной выбор, /hmtracker preview — предпросмотр, "
        .. "/hmtracker position — сброс положения, /hmtracker reset — сброс всех настроек, /hmtracker help — справка.",
}

local clientLocale = GetLocale()
local strings = clientLocale == "ruRU" and russian or english
if clientLocale == "enUS" or clientLocale == "ruRU" then
    strings.offline = PLAYER_OFFLINE
    strings.dead = DEAD
end
addon.Locale = strings
