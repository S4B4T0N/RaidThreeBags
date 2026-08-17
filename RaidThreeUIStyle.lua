-- ============================================================
-- RaidThreeUIStyle.lua
-- Shared Raid Three visual tokens for WoW 3.3.5a / Lua 5.1.
-- ============================================================

local MODULE_VERSION = "1.0.1"

local function ParseVersion(version)
    local major, minor, patch =
        string.match(tostring(version or ""), "^(%d+)%.(%d+)%.(%d+)$")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

local function IsVersionAtLeast(first, second)
    local firstMajor, firstMinor, firstPatch = ParseVersion(first)
    local secondMajor, secondMinor, secondPatch = ParseVersion(second)
    if firstMajor ~= secondMajor then
        return firstMajor > secondMajor
    end
    if firstMinor ~= secondMinor then
        return firstMinor > secondMinor
    end
    return firstPatch >= secondPatch
end

local existing = rawget(_G, "RaidThreeUIStyle")
if existing
    and type(existing.ApplyText) == "function"
    and IsVersionAtLeast(existing.VERSION, MODULE_VERSION)
then
    return
end

local Style = {}
Style.VERSION = MODULE_VERSION

Style.FONT_OBJECTS = {
    windowTitle = "GameFontNormalLarge",
    sectionHeading = "GameFontNormal",
    controlCaption = "GameFontNormalSmall",
    body = "GameFontHighlight",
    bodySmall = "GameFontHighlightSmall",
    buttonLabel = "GameFontNormalSmall",
    muted = "GameFontHighlightSmall"
}

Style.COLORS = {
    windowBackground = { 0.00, 0.00, 0.00, 0.95 },
    headerBackground = { 0.08, 0.08, 0.12, 0.95 },
    panelBackground = { 0.03, 0.03, 0.05, 0.82 },
    slotBackground = { 0.05, 0.05, 0.07, 0.95 },
    border = { 0.30, 0.40, 0.52, 0.75 },
    borderStrong = { 0.30, 0.40, 0.52, 0.85 },
    separator = { 0.70, 0.85, 1.00, 0.35 },
    separatorSoft = { 0.70, 0.85, 1.00, 0.24 },
    title = { 0.85, 0.92, 1.00, 1.00 },
    accent = { 0.55, 0.75, 1.00, 1.00 },
    section = { 1.00, 0.82, 0.00, 1.00 },
    textPrimary = { 0.90, 0.90, 0.92, 1.00 },
    textSecondary = { 0.72, 0.76, 0.82, 1.00 },
    textMuted = { 0.52, 0.66, 0.80, 1.00 },
    success = { 0.00, 1.00, 0.00, 1.00 },
    danger = { 1.00, 0.20, 0.20, 1.00 },
    warning = { 1.00, 0.78, 0.25, 1.00 },
    rowOdd = { 0.10, 0.13, 0.18, 0.62 },
    rowEven = { 0.06, 0.08, 0.12, 0.62 },
    iconNormal = { 1.00, 1.00, 1.00, 1.00 },
    iconPushed = { 0.75, 0.75, 0.75, 1.00 },
    disabledIcon = { 0.70, 0.70, 0.70, 1.00 },
    cursorValid = { 0.20, 1.00, 0.20, 0.70 },
    highlightSuccess = { 0.00, 1.00, 0.00, 0.70 },
    highlightDanger = { 1.00, 0.12, 0.12, 0.75 }
}

Style.TEXT_ROLES = {
    windowTitle = { font = "windowTitle", color = "title" },
    sectionHeading = { font = "sectionHeading", color = "section" },
    controlCaption = { font = "controlCaption", color = "accent" },
    body = { font = "body", color = "textPrimary" },
    bodySmall = { font = "bodySmall", color = "textSecondary" },
    buttonLabel = { font = "buttonLabel", color = "accent" },
    muted = { font = "muted", color = "textMuted" }
}

Style.BACKDROPS = {
    window = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    },
    panel = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    },
    slot = {
        bgFile = "Interface\\Buttons\\UI-EmptySlot",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    }
}

Style.SURFACE_ROLES = {
    window = {
        backdrop = "window",
        background = "windowBackground"
    },
    panel = {
        backdrop = "panel",
        background = "panelBackground",
        border = "border"
    },
    slot = {
        backdrop = "slot",
        background = "slotBackground"
    }
}

Style.TEXTURES = {
    white = "Interface\\Buttons\\WHITE8X8",
    header = "Interface\\Tooltips\\UI-Tooltip-Background",
    iconBorder = "Interface\\Buttons\\UI-Quickslot2",
    qualityBorder = "Interface\\Buttons\\UI-ActionButton-Border",
    highlight = "Interface\\Buttons\\ButtonHilight-Square",
    resize = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    resizeHighlight =
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
}

Style.METRICS = {
    headerHeight = 30,
    separatorHeight = 2,
    squareControl = 30,
    squareIcon = 16,
    squareBorder = 26,
    controlSpacing = 4,
    iconInset = 3
}

function Style:GetColor(name)
    local color = self.COLORS[name]
    if not color then
        return
    end
    return color[1], color[2], color[3], color[4]
end

function Style:ApplyText(fontString, role)
    local definition = self.TEXT_ROLES[role]
    if not fontString or not definition then
        return false
    end

    local fontName = self.FONT_OBJECTS[definition.font]
    local fontObject = fontName and rawget(_G, fontName)
    if fontObject and fontString.SetFontObject then
        fontString:SetFontObject(fontObject)
    end
    fontString:SetTextColor(self:GetColor(definition.color))
    return true
end

function Style:ApplyBackdrop(frame, role)
    local definition = self.SURFACE_ROLES[role]
    if not frame or not definition then
        return false
    end

    frame:SetBackdrop(self.BACKDROPS[definition.backdrop])
    frame:SetBackdropColor(self:GetColor(definition.background))
    if definition.border and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(self:GetColor(definition.border))
    end
    return true
end

function Style:ApplySquareControl(button)
    if not button then
        return false
    end
    button:SetWidth(self.METRICS.squareControl)
    button:SetHeight(self.METRICS.squareControl)
    return self:ApplyBackdrop(button, "slot")
end

function Style:CreateSquareIconChrome(button, texturePath)
    if not button or not texturePath then
        return false
    end

    self:ApplySquareControl(button)
    button:SetNormalTexture(texturePath)
    local normal = button:GetNormalTexture()
    normal:ClearAllPoints()
    normal:SetWidth(self.METRICS.squareIcon)
    normal:SetHeight(self.METRICS.squareIcon)
    normal:SetPoint("CENTER", button, "CENTER", 0, 0)
    normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button:SetPushedTexture(texturePath)
    local pushed = button:GetPushedTexture()
    pushed:ClearAllPoints()
    pushed:SetWidth(self.METRICS.squareIcon)
    pushed:SetHeight(self.METRICS.squareIcon)
    pushed:SetPoint("CENTER", button, "CENTER", 1, -1)
    pushed:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pushed:SetVertexColor(self:GetColor("iconPushed"))

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(self.METRICS.squareBorder)
    border:SetHeight(self.METRICS.squareBorder)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:SetTexture(self.TEXTURES.iconBorder)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    highlight:SetTexture(self.TEXTURES.highlight)
    highlight:SetBlendMode("ADD")
    button.r3StyleBorder = border
    button.r3StyleHighlight = highlight
    return true
end

RaidThreeUIStyle = Style
