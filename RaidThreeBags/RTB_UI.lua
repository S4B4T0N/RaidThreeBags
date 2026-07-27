-- ============================================================
-- RTB_UI.lua
-- Shared window shell and responsive bag grid.
-- Target: WoW 3.3.5a / Interface 30300 / Lua 5.1.
-- ============================================================

local RTB = RaidThreeBags

local ITEM_SIZE = 36
local ITEM_SPACING = 4
local ITEM_STEP = ITEM_SIZE + ITEM_SPACING
local MAX_COLUMNS = 20
local INVENTORY_BAG_SIZE = 30
local INVENTORY_BAG_SPACING = 4
local WINDOW_MAGNET_DISTANCE = 12
local FOOTER_BRAND_REFERENCE_WIDTH = 480
local FOOTER_BRAND_MIN_FONT_SIZE = 7
local FOOTER_BRAND_MAX_WIDTH = 220
local FOOTER_BRAND_HEIGHT = 32
local FOOTER_BRAND_BOTTOM = 8
local FOOTER_BRAND_COLLISION_GAP = 8
local FOOTER_BRAND_CREDIT = "Made by S4B4T0N"
local FOOTER_BRAND_EDITION = "WotLK 3.3.5a"
local SETTINGS_WIDTH = 520
local SETTINGS_HEIGHT = 550
local SETTINGS_ROW_HEIGHT = 26
local SETTINGS_RESET_BUTTON_WIDTH = 210
local SETTINGS_RESET_BUTTON_GAP = 8
local SETTINGS_CONTENT_SIDE = 22
local SETTINGS_INNER_SIDE = 14
local SETTINGS_CONTENT_TOP = 54
local SETTINGS_CONTENT_BOTTOM = 52
local SETTINGS_LIST_TOP = 168
local SETTINGS_LIST_BOTTOM = 10
local SETTINGS_MIN_VISIBLE_ROWS = 2
local SETTINGS_MIN_WIDTH =
    (SETTINGS_CONTENT_SIDE * 2) +
    (SETTINGS_INNER_SIDE * 2) +
    (SETTINGS_RESET_BUTTON_WIDTH * 2) +
    SETTINGS_RESET_BUTTON_GAP
local SETTINGS_MIN_HEIGHT =
    SETTINGS_CONTENT_TOP +
    SETTINGS_CONTENT_BOTTOM +
    SETTINGS_LIST_TOP +
    SETTINGS_LIST_BOTTOM +
    (SETTINGS_ROW_HEIGHT * SETTINGS_MIN_VISIBLE_ROWS)
local SETTINGS_MAX_WIDTH = 900
local SETTINGS_MAX_HEIGHT = 760
local SETTINGS_TABLE_WIDTH_OVERHEAD =
    (SETTINGS_CONTENT_SIDE * 2) +
    SETTINGS_INNER_SIDE +
    32
local CORNER_LOCK_PAIRS = {
    { "TOPLEFT", "TOPRIGHT" },
    { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPRIGHT", "TOPLEFT" },
    { "BOTTOMRIGHT", "BOTTOMLEFT" },
    { "TOPLEFT", "BOTTOMLEFT" },
    { "TOPRIGHT", "BOTTOMRIGHT" },
    { "BOTTOMLEFT", "TOPLEFT" },
    { "BOTTOMRIGHT", "TOPRIGHT" }
}

local WINDOW_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

local PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local BAG_SLOT_BACKDROP = {
    bgFile = "Interface\\Buttons\\UI-EmptySlot",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local EMPTY_SLOT_COLORS = {
    [0] = { 0.48, 0.48, 0.52 },
    [1] = { 0.70, 0.55, 0.20 },
    [2] = { 0.58, 0.38, 0.18 },
    [4] = { 0.55, 0.28, 0.72 },
    [8] = { 0.72, 0.42, 0.20 },
    [16] = { 0.72, 0.72, 0.72 },
    [32] = { 0.25, 0.68, 0.30 },
    [64] = { 0.25, 0.48, 0.78 },
    [128] = { 0.72, 0.62, 0.22 },
    [512] = { 0.68, 0.30, 0.62 },
    [1024] = { 0.54, 0.38, 0.22 }
}

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

function RTB:HasFooterBrandCollision(brand)
    if not brand
        or not brand.rtbWindow
        or not brand.rtbLeftBoundary
        or not brand.rtbRightBoundary
    then
        return true
    end

    local windowLeft = brand.rtbWindow:GetLeft()
    local windowRight = brand.rtbWindow:GetRight()
    local leftBoundary = brand.rtbLeftBoundary:GetRight()
    local rightBoundary = brand.rtbRightBoundary:GetLeft()
    local creditWidth = brand.rtbCredit:GetStringWidth()
    local editionWidth = brand.rtbEdition:GetStringWidth()
    if not windowLeft
        or not windowRight
        or not leftBoundary
        or not rightBoundary
        or not creditWidth
        or not editionWidth
    then
        return true
    end

    local brandWidth = math.max(creditWidth, editionWidth)
    local brandCenter = (windowLeft + windowRight) / 2
    local brandLeft = brandCenter - (brandWidth / 2)
    local brandRight = brandCenter + (brandWidth / 2)
    return brandLeft <= leftBoundary + FOOTER_BRAND_COLLISION_GAP
        or brandRight >= rightBoundary - FOOTER_BRAND_COLLISION_GAP
end

function RTB:UpdateFooterBrandVisibility(brand)
    if self:HasFooterBrandCollision(brand) then
        brand.rtbCollisionHidden = true
        brand:Hide()
        return false
    end

    brand.rtbCollisionHidden = false
    brand:Show()
    return true
end

function RTB:LayoutFooterBrand(brand)
    if not brand or not brand.rtbWindow then
        return
    end

    local windowWidth = brand.rtbWindow:GetWidth()
        or FOOTER_BRAND_REFERENCE_WIDTH
    local scale = Clamp(
        windowWidth / FOOTER_BRAND_REFERENCE_WIDTH,
        FOOTER_BRAND_MIN_FONT_SIZE
            / math.max(FOOTER_BRAND_MIN_FONT_SIZE, brand.rtbCreditBaseSize),
        1
    )
    local creditSize = Clamp(
        math.floor((brand.rtbCreditBaseSize * scale) + 0.5),
        math.min(FOOTER_BRAND_MIN_FONT_SIZE, brand.rtbCreditBaseSize),
        brand.rtbCreditBaseSize
    )
    local editionSize = Clamp(
        math.floor((brand.rtbEditionBaseSize * scale) + 0.5),
        math.min(FOOTER_BRAND_MIN_FONT_SIZE, brand.rtbEditionBaseSize),
        brand.rtbEditionBaseSize
    )

    brand:SetWidth(math.min(
        FOOTER_BRAND_MAX_WIDTH,
        math.max(1, windowWidth - 48)
    ))
    brand.rtbCredit:SetFont(
        brand.rtbCreditFont,
        creditSize,
        brand.rtbCreditFlags
    )
    brand.rtbEdition:SetFont(
        brand.rtbEditionFont,
        editionSize,
        brand.rtbEditionFlags
    )
    self:UpdateFooterBrandVisibility(brand)
end

function RTB:CreateFooterBrand(window, leftBoundary, rightBoundary)
    local brand = CreateFrame("Frame", nil, window)
    brand:SetHeight(FOOTER_BRAND_HEIGHT)
    brand:SetPoint(
        "BOTTOM",
        window,
        "BOTTOM",
        0,
        FOOTER_BRAND_BOTTOM
    )
    brand.rtbWindow = window
    brand.rtbLeftBoundary = leftBoundary
    brand.rtbRightBoundary = rightBoundary

    local credit = brand:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    credit:SetPoint("BOTTOM", brand, "CENTER", 0, 1)
    credit:SetWidth(FOOTER_BRAND_MAX_WIDTH)
    credit:SetJustifyH("CENTER")
    credit:SetText(FOOTER_BRAND_CREDIT)
    credit:SetTextColor(0.74, 0.74, 0.80)
    brand.rtbCredit = credit

    local edition = brand:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    edition:SetPoint("TOP", brand, "CENTER", 0, -1)
    edition:SetWidth(FOOTER_BRAND_MAX_WIDTH)
    edition:SetJustifyH("CENTER")
    edition:SetText(FOOTER_BRAND_EDITION)
    edition:SetTextColor(0.55, 0.75, 1)
    brand.rtbEdition = edition

    local creditFont, creditSize, creditFlags = credit:GetFont()
    local editionFont, editionSize, editionFlags = edition:GetFont()
    brand.rtbCreditFont =
        creditFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    brand.rtbCreditBaseSize = tonumber(creditSize) or 12
    brand.rtbCreditFlags = creditFlags or ""
    brand.rtbEditionFont =
        editionFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    brand.rtbEditionBaseSize = tonumber(editionSize) or 12
    brand.rtbEditionFlags = editionFlags or ""

    self:LayoutFooterBrand(brand)
    return brand
end

local function GetEmptySlotColor(bagType)
    local color = EMPTY_SLOT_COLORS[tonumber(bagType) or 0]
    if color then
        return color[1], color[2], color[3]
    end
    return EMPTY_SLOT_COLORS[0][1], EMPTY_SLOT_COLORS[0][2], EMPTY_SLOT_COLORS[0][3]
end

local function GetFrameRect(frame)
    if not frame then
        return
    end

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local bottom = frame:GetBottom()
    local top = frame:GetTop()
    if type(left) ~= "number"
        or type(right) ~= "number"
        or type(bottom) ~= "number"
        or type(top) ~= "number"
    then
        return
    end

    return left, right, bottom, top
end

local function GetCornerPosition(frame, corner)
    local left, right, bottom, top = GetFrameRect(frame)
    if not left then
        return
    end

    if corner == "TOPLEFT" then
        return left, top
    elseif corner == "TOPRIGHT" then
        return right, top
    elseif corner == "BOTTOMLEFT" then
        return left, bottom
    elseif corner == "BOTTOMRIGHT" then
        return right, bottom
    end
end

local function IsCompatibleCornerPair(firstCorner, secondCorner)
    local _, pair
    for _, pair in ipairs(CORNER_LOCK_PAIRS) do
        if pair[1] == firstCorner and pair[2] == secondCorner then
            return true
        end
    end
    return false
end

function RTB:GetWindowFrames()
    local frames = {}
    if self.MainFrame then
        table.insert(frames, self.MainFrame)
    end
    if self.PlayerBankFrame then
        table.insert(frames, self.PlayerBankFrame)
    end
    if self.SettingsFrame then
        table.insert(frames, self.SettingsFrame)
    end
    return frames
end

function RTB:GetWindowLocks()
    if type(self.WindowLocks) ~= "table" then
        self.WindowLocks = {}
    end
    return self.WindowLocks
end

function RTB:GetWindowComponent(startFrame)
    local component = {}
    local visited = {}
    local queue = {}
    local first = 1

    if not startFrame then
        return component, visited
    end

    visited[startFrame] = true
    table.insert(queue, startFrame)
    while queue[first] do
        local frame = queue[first]
        first = first + 1
        table.insert(component, frame)

        local _, edge
        for _, edge in ipairs(self:GetWindowLocks()) do
            local neighbour
            if edge.first == frame then
                neighbour = edge.second
            elseif edge.second == frame then
                neighbour = edge.first
            end
            if neighbour and not visited[neighbour] then
                visited[neighbour] = true
                table.insert(queue, neighbour)
            end
        end
    end

    return component, visited
end

function RTB:AreWindowsConnected(firstFrame, secondFrame)
    if not firstFrame or not secondFrame then
        return false
    end
    local _, visited = self:GetWindowComponent(firstFrame)
    return visited[secondFrame] and true or false
end

function RTB:NormalizeWindowFrames(frames)
    local positions = {}
    local _, frame
    for _, frame in ipairs(frames or {}) do
        local left, _, bottom = GetFrameRect(frame)
        if left then
            positions[frame] = { left = left, bottom = bottom }
        end
    end

    local screenLeft = UIParent:GetLeft() or 0
    local screenBottom = UIParent:GetBottom() or 0
    for _, frame in ipairs(frames or {}) do
        local position = positions[frame]
        if position then
            frame:ClearAllPoints()
            frame:SetPoint(
                "BOTTOMLEFT",
                UIParent,
                "BOTTOMLEFT",
                position.left - screenLeft,
                position.bottom - screenBottom
            )
        end
    end
end

function RTB:ReanchorWindowComponent(root)
    local component = self:GetWindowComponent(root)
    self:NormalizeWindowFrames(component)

    local visited = {}
    local queue = {}
    local first = 1
    visited[root] = true
    table.insert(queue, root)

    while queue[first] do
        local frame = queue[first]
        first = first + 1
        local _, edge
        for _, edge in ipairs(self:GetWindowLocks()) do
            local child
            local childCorner
            local parentCorner
            if edge.first == frame then
                child = edge.second
                childCorner = edge.secondCorner
                parentCorner = edge.firstCorner
            elseif edge.second == frame then
                child = edge.first
                childCorner = edge.firstCorner
                parentCorner = edge.secondCorner
            end
            if child and not visited[child] then
                child:ClearAllPoints()
                child:SetPoint(childCorner, frame, parentCorner, 0, 0)
                visited[child] = true
                table.insert(queue, child)
            end
        end
    end
    return component
end

function RTB:IsWindowCornerUsed(frame, corner)
    local _, edge
    for _, edge in ipairs(self:GetWindowLocks()) do
        if (edge.first == frame and edge.firstCorner == corner)
            or (edge.second == frame and edge.secondCorner == corner)
        then
            return true
        end
    end
    return false
end

function RTB:AddWindowLock(firstFrame, firstCorner, secondFrame, secondCorner)
    if not firstFrame
        or not secondFrame
        or firstFrame == secondFrame
        or not IsCompatibleCornerPair(firstCorner, secondCorner)
        or self:AreWindowsConnected(firstFrame, secondFrame)
        or self:IsWindowCornerUsed(firstFrame, firstCorner)
        or self:IsWindowCornerUsed(secondFrame, secondCorner)
    then
        return false
    end

    table.insert(self:GetWindowLocks(), {
        first = firstFrame,
        firstCorner = firstCorner,
        second = secondFrame,
        secondCorner = secondCorner
    })
    return true
end

function RTB:SavePrimaryWindowLock()
    if not self.DB or not self.DB.settings then
        return
    end

    self.DB.settings.primaryWindowLock = nil
    local _, edge
    for _, edge in ipairs(self:GetWindowLocks()) do
        if edge.first == self.MainFrame
            and edge.second == self.PlayerBankFrame
        then
            self.DB.settings.primaryWindowLock = {
                inventoryCorner = edge.firstCorner,
                bankCorner = edge.secondCorner
            }
            return
        elseif edge.first == self.PlayerBankFrame
            and edge.second == self.MainFrame
        then
            self.DB.settings.primaryWindowLock = {
                inventoryCorner = edge.secondCorner,
                bankCorner = edge.firstCorner
            }
            return
        end
    end
end

function RTB:ReanchorAllWindowComponents(frames)
    local visited = {}
    local _, frame
    for _, frame in ipairs(frames or self:GetWindowFrames()) do
        if frame and not visited[frame] then
            local component = self:ReanchorWindowComponent(frame)
            local _, member
            for _, member in ipairs(component) do
                visited[member] = true
            end
        end
    end
end

function RTB:DisconnectWindow(frame)
    if not frame then
        return false
    end

    local oldComponent = self:GetWindowComponent(frame)
    self:NormalizeWindowFrames(oldComponent)
    local retained = {}
    local removed = false
    local _, edge
    for _, edge in ipairs(self:GetWindowLocks()) do
        if edge.first == frame or edge.second == frame then
            removed = true
        else
            table.insert(retained, edge)
        end
    end
    self.WindowLocks = retained
    self:ReanchorAllWindowComponents(oldComponent)
    self:SavePrimaryWindowLock()
    return removed
end

function RTB:ClearWindowLocks()
    self:NormalizeWindowFrames(self:GetWindowFrames())
    self.WindowLocks = {}
    self:SavePrimaryWindowLock()
    self:SavePrimaryWindowStates()
end

function RTB:RestorePrimaryWindowLock()
    if not self:GetWindowLockEnabled()
        or not self.MainFrame
        or not self.PlayerBankFrame
        or not self.MainFrame:IsShown()
        or not self.PlayerBankFrame:IsShown()
        or self:AreWindowsConnected(self.MainFrame, self.PlayerBankFrame)
        or not self.DB
        or not self.DB.settings
    then
        return false
    end

    local saved = self.DB.settings.primaryWindowLock
    if type(saved) ~= "table"
        or not IsCompatibleCornerPair(
            saved.inventoryCorner,
            saved.bankCorner
        )
    then
        return false
    end

    if self:AddWindowLock(
        self.MainFrame,
        saved.inventoryCorner,
        self.PlayerBankFrame,
        saved.bankCorner
    ) then
        self:ReanchorWindowComponent(self.MainFrame)
        return true
    end
    return false
end

function RTB:ApplyScreenMagnet(frame)
    if not self:GetWindowLockEnabled() then
        return false
    end

    local left, right, bottom, top = GetFrameRect(frame)
    local screenLeft, screenRight, screenBottom, screenTop =
        GetFrameRect(UIParent)
    if not left or not screenLeft then
        return false
    end

    local width = right - left
    local height = top - bottom
    local snappedLeft = left
    local snappedBottom = bottom
    local snapped = false
    if math.abs(left - screenLeft) <= WINDOW_MAGNET_DISTANCE then
        snappedLeft = screenLeft
        snapped = true
    elseif math.abs(right - screenRight) <= WINDOW_MAGNET_DISTANCE then
        snappedLeft = screenRight - width
        snapped = true
    end
    if math.abs(bottom - screenBottom) <= WINDOW_MAGNET_DISTANCE then
        snappedBottom = screenBottom
        snapped = true
    elseif math.abs(top - screenTop) <= WINDOW_MAGNET_DISTANCE then
        snappedBottom = screenTop - height
        snapped = true
    end

    if snapped then
        frame:ClearAllPoints()
        frame:SetPoint(
            "BOTTOMLEFT",
            UIParent,
            "BOTTOMLEFT",
            snappedLeft - screenLeft,
            snappedBottom - screenBottom
        )
    end
    return snapped
end

function RTB:ApplyWindowMagnet(frame)
    if not frame
        or not self:GetWindowLockEnabled()
        or (IsShiftKeyDown and IsShiftKeyDown())
    then
        return false
    end

    local component, connected = self:GetWindowComponent(frame)
    local best
    local targets = self:GetWindowFrames()
    local _, target
    for _, target in ipairs(targets) do
        if target
            and target ~= frame
            and target:IsShown()
            and not connected[target]
        then
            local _, pair
            for _, pair in ipairs(CORNER_LOCK_PAIRS) do
                local firstCorner = pair[1]
                local secondCorner = pair[2]
                if not self:IsWindowCornerUsed(frame, firstCorner)
                    and not self:IsWindowCornerUsed(target, secondCorner)
                then
                    local firstX, firstY =
                        GetCornerPosition(frame, firstCorner)
                    local secondX, secondY =
                        GetCornerPosition(target, secondCorner)
                    if firstX and secondX then
                        local deltaX = math.abs(firstX - secondX)
                        local deltaY = math.abs(firstY - secondY)
                        if deltaX <= WINDOW_MAGNET_DISTANCE
                            and deltaY <= WINDOW_MAGNET_DISTANCE
                        then
                            local distance =
                                (deltaX * deltaX) + (deltaY * deltaY)
                            if not best or distance < best.distance then
                                best = {
                                    target = target,
                                    firstCorner = firstCorner,
                                    secondCorner = secondCorner,
                                    distance = distance
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if not best then
        return self:ApplyScreenMagnet(frame)
    end

    local targetComponent = self:GetWindowComponent(best.target)
    local combined = {}
    local _, member
    for _, member in ipairs(component) do
        table.insert(combined, member)
    end
    for _, member in ipairs(targetComponent) do
        table.insert(combined, member)
    end
    self:NormalizeWindowFrames(combined)
    self:AddWindowLock(
        frame,
        best.firstCorner,
        best.target,
        best.secondCorner
    )
    self:ReanchorWindowComponent(best.target)
    self:SavePrimaryWindowLock()
    return true
end

function RTB:StartWindowMove(frame)
    if not frame then
        return
    end

    frame.rtbUnlockMove =
        IsShiftKeyDown and IsShiftKeyDown() and true or false
    if frame.rtbUnlockMove then
        self:DisconnectWindow(frame)
    else
        self:ReanchorWindowComponent(frame)
    end
    frame:StartMoving()
end

function RTB:StartWindowResize(frame, corner)
    if not frame then
        return
    end
    self:ReanchorWindowComponent(frame)
    frame:StartSizing(corner or "BOTTOMRIGHT")
end

function RTB:SavePrimaryWindowStates()
    if self.MainFrame then
        self:SaveWindowState()
    end
    if self.PlayerBankFrame then
        self:SaveBankWindowState()
    end
end

function RTB:StopWindowResize(frame)
    if not frame then
        return
    end
    frame:StopMovingOrSizing()
    self:SavePrimaryWindowStates()
end

function RTB:StopWindowMove(frame)
    if not frame then
        return
    end

    frame:StopMovingOrSizing()
    if not frame.rtbUnlockMove then
        self:ApplyWindowMagnet(frame)
    end
    frame.rtbUnlockMove = nil
    self:SavePrimaryWindowStates()
end

function RTB:CreateWindow(frameName, width, height, titleText)
    local window = CreateFrame("Frame", frameName, UIParent)
    window:SetWidth(width)
    window:SetHeight(height)
    window:SetPoint("CENTER")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetClampedToScreen(true)
    window:SetBackdrop(WINDOW_BACKDROP)
    window:SetBackdropColor(0, 0, 0, 0.95)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:Hide()

    local windowHeader = CreateFrame("Frame", nil, window)
    windowHeader:SetHeight(30)
    windowHeader:SetPoint("TOPLEFT", 12, -12)
    windowHeader:SetPoint("TOPRIGHT", -44, -12)
    windowHeader:SetFrameLevel(window:GetFrameLevel() + 1)
    windowHeader:EnableMouse(true)
    windowHeader:RegisterForDrag("LeftButton")

    local windowHeaderBg = windowHeader:CreateTexture(nil, "BACKGROUND")
    windowHeaderBg:SetAllPoints(windowHeader)
    windowHeaderBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    windowHeaderBg:SetVertexColor(0.08, 0.08, 0.12, 0.95)

    local windowTopLine = window:CreateTexture(nil, "ARTWORK")
    windowTopLine:SetHeight(2)
    windowTopLine:SetPoint("TOPLEFT", 20, -42)
    windowTopLine:SetPoint("TOPRIGHT", -20, -42)
    windowTopLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    windowTopLine:SetVertexColor(0.7, 0.85, 1, 0.35)

    local windowTitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    windowTitle:SetPoint("CENTER", windowHeader, "CENTER", 0, 0)
    windowTitle:SetText(titleText or "")
    windowTitle:SetTextColor(0.85, 0.92, 1)

    window.rtbHeader = windowHeader
    window.rtbTitle = windowTitle
    window.rtbTopLine = windowTopLine
    return window, windowHeader, windowTitle
end

function RTB:CreateSettingsGear(window, context)
    if not window then
        return
    end

    local name
    local existing
    if context == "bank" then
        name = "RaidThreeBagsBankSettingsButton"
        existing = self.BankSettingsButton
    else
        name = "RaidThreeBagsSettingsButton"
        existing = self.InventorySettingsButton
    end

    if existing then
        existing:Show()
        return existing
    end

    local button = CreateFrame("Button", name, window)
    button:SetWidth(30)
    button:SetHeight(30)
    button:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -12)
    button:SetFrameLevel(window:GetFrameLevel() + 20)
    button:SetHitRectInsets(0, 0, 0, 0)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    button:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
    local normal = button:GetNormalTexture()
    normal:ClearAllPoints()
    normal:SetWidth(16)
    normal:SetHeight(16)
    normal:SetPoint("CENTER", button, "CENTER", 0, 0)
    normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button:SetPushedTexture("Interface\\Icons\\Trade_Engineering")
    local pushed = button:GetPushedTexture()
    pushed:ClearAllPoints()
    pushed:SetWidth(16)
    pushed:SetHeight(16)
    pushed:SetPoint("CENTER", button, "CENTER", 1, -1)
    pushed:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pushed:SetVertexColor(0.75, 0.75, 0.75)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(26)
    border:SetHeight(26)
    border:SetPoint("CENTER", button, "CENTER", 0, 0)
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        local ok, err = pcall(RTB.ToggleSettings, RTB, window)
        if not ok then
            RTB:Print("Settings UI error: " .. tostring(err))
        end
    end)
    button:Show()

    if context == "bank" then
        self.BankSettingsButton = button
    else
        self.InventorySettingsButton = button
    end
    return button
end

function RTB:HandleInventoryBagSlotClick(button)
    if not button then
        return
    end

    if CursorHasItem() then
        PutItemInBag(button.rtbInventorySlot)
    end
    self:UpdateInventoryBagSlots()
end

function RTB:HandleInventoryBagSlotDrag(button)
    if not button then
        return
    end

    PlaySound("BAGMENUBUTTONPRESS")
    PickupBagFromSlot(button.rtbInventorySlot)
    self:UpdateInventoryBagSlots()
end

function RTB:UpdateInventoryBagSlotTooltip(button)
    if not button then
        return
    end

    if button:GetRight() and button:GetRight() > (GetScreenWidth() / 2) then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    end

    if not GameTooltip:SetInventoryItem("player", button.rtbInventorySlot) then
        GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1)
    end
    GameTooltip:Show()
end

function RTB:CreateInventoryBagSlot(bagID)
    local index = #self.InventoryBagSlotButtons + 1
    local button = CreateFrame(
        "Button",
        "RaidThreeBagsInventoryBag" .. tostring(index),
        self.InventoryBagBar
    )
    button:SetWidth(INVENTORY_BAG_SIZE)
    button:SetHeight(INVENTORY_BAG_SIZE)
    button:SetID(bagID)
    button:SetBackdrop(BAG_SLOT_BACKDROP)
    button:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    local cursorHighlight = button:CreateTexture(nil, "OVERLAY")
    cursorHighlight:SetAllPoints(button)
    cursorHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    cursorHighlight:SetBlendMode("ADD")
    cursorHighlight:SetVertexColor(0.2, 1, 0.2, 0.7)
    cursorHighlight:Hide()

    button.rtbIcon = icon
    button.rtbCursorHighlight = cursorHighlight
    button.rtbBagID = bagID
    button.rtbInventorySlot = ContainerIDToInventoryID(bagID)

    button:SetScript("OnClick", function(self)
        RTB:HandleInventoryBagSlotClick(self)
    end)
    button:SetScript("OnDragStart", function(self)
        RTB:HandleInventoryBagSlotDrag(self)
    end)
    button:SetScript("OnReceiveDrag", function(self)
        RTB:HandleInventoryBagSlotClick(self)
    end)
    button:SetScript("OnEnter", function(self)
        RTB:UpdateInventoryBagSlotTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)

    self.InventoryBagSlotButtons[index] = button
    return button
end

function RTB:UpdateInventoryBagSlots()
    if not self.InventoryBagSlotButtons then
        return
    end

    local _, button
    for _, button in ipairs(self.InventoryBagSlotButtons) do
        local texture = GetInventoryItemTexture(
            "player",
            button.rtbInventorySlot
        )
        button.rtbIcon:SetTexture(
            texture or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
        )

        if texture then
            button.rtbIcon:SetVertexColor(1, 1, 1)
        else
            button.rtbIcon:SetVertexColor(0.7, 0.7, 0.7)
        end

        local locked = IsInventoryItemLocked(button.rtbInventorySlot)
        if button.rtbIcon.SetDesaturated then
            button.rtbIcon:SetDesaturated(locked and true or false)
        end

        if CursorCanGoInSlot
            and CursorCanGoInSlot(button.rtbInventorySlot)
        then
            button.rtbCursorHighlight:Show()
        else
            button.rtbCursorHighlight:Hide()
        end
    end
end

function RTB:LayoutInventoryBagSlots()
    if not self.InventoryBagBar or not self.InventoryBagSlotButtons then
        return
    end

    local index, button
    for index, button in ipairs(self.InventoryBagSlotButtons) do
        button:ClearAllPoints()
        button:SetPoint(
            "LEFT",
            self.InventoryBagBar,
            "LEFT",
            (index - 1) * (INVENTORY_BAG_SIZE + INVENTORY_BAG_SPACING),
            0
        )
    end
end

function RTB:GetBagParent(bagID)
    local parent = self.BagParents[bagID]
    if parent then
        return parent
    end

    parent = CreateFrame("Frame", nil, self.ItemContent)
    parent:SetAllPoints(self.ItemContent)
    parent:SetID(bagID)
    self.BagParents[bagID] = parent
    return parent
end

function RTB:CreateItemButton()
    local index = #self.ItemButtons + 1
    local parent = self:GetBagParent(0)
    local button = CreateFrame(
        "Button",
        "RaidThreeBagsItem" .. tostring(index),
        parent,
        "ContainerFrameItemButtonTemplate"
    )

    button:SetWidth(ITEM_SIZE)
    button:SetHeight(ITEM_SIZE)
    button:SetScript("OnEvent", nil)
    button:UnregisterAllEvents()

    local qualityBorder = button:CreateTexture(nil, "OVERLAY")
    qualityBorder:SetWidth(62)
    qualityBorder:SetHeight(62)
    qualityBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
    qualityBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    qualityBorder:SetBlendMode("ADD")
    qualityBorder:Hide()

    button.rtbQualityBorder = qualityBorder
    self.ItemButtons[index] = button
    return button
end

function RTB:UpdateItemButton(button, bagID, slotID)
    local bagParent = self:GetBagParent(bagID)
    if button:GetParent() ~= bagParent then
        button:SetParent(bagParent)
    end

    button:SetID(slotID)
    button.rtbBagID = bagID
    button.rtbSlotID = slotID

    local texture, count, locked, quality, readable, _, itemLink =
        GetContainerItemInfo(bagID, slotID)

    button.hasItem = itemLink or nil
    button.readable = readable

    SetItemButtonTexture(button, texture)
    SetItemButtonCount(button, count or 0)
    SetItemButtonDesaturated(button, locked and true or false)

    local _, bagType = GetContainerNumFreeSlots(bagID)
    local normalTexture = button:GetNormalTexture()
    if texture then
        SetItemButtonTextureVertexColor(button, 1, 1, 1)
        if normalTexture then
            normalTexture:SetVertexColor(1, 1, 1)
        end
    else
        local r, g, b = GetEmptySlotColor(bagType)
        SetItemButtonTextureVertexColor(button, r, g, b)
        if normalTexture then
            normalTexture:SetVertexColor(r, g, b)
        end
    end

    if itemLink and quality and quality > 1 then
        local r, g, b = GetItemQualityColor(quality)
        button.rtbQualityBorder:SetVertexColor(r, g, b, 0.65)
        button.rtbQualityBorder:Show()
    else
        button.rtbQualityBorder:Hide()
    end

    ContainerFrame_UpdateCooldown(bagID, button)
end

function RTB:RefreshItems()
    if not self.ItemContent then
        return
    end

    local index
    for index = 1, #self.ItemButtons do
        self.ItemButtons[index]:Hide()
    end

    self.ButtonByBagSlot = {}
    local visibleIndex = 0
    local _, bagID
    for _, bagID in ipairs(self.BAG_IDS) do
        if self:IsInventoryBagVisible(bagID) then
            local slotCount = GetContainerNumSlots(bagID) or 0
            local slotID
            for slotID = 1, slotCount do
                visibleIndex = visibleIndex + 1
                local button =
                    self.ItemButtons[visibleIndex] or self:CreateItemButton()
                self:UpdateItemButton(button, bagID, slotID)
                button.rtbVisibleIndex = visibleIndex
                self.ButtonByBagSlot[
                    tostring(bagID) .. ":" .. tostring(slotID)
                ] = button
                button:Show()
            end
        end
    end

    self.VisibleItemCount = visibleIndex
    self:RequestLayout()
end

function RTB:RefreshItem(bagID, slotID)
    if not self.ButtonByBagSlot then
        return
    end

    local button = self.ButtonByBagSlot[tostring(bagID) .. ":" .. tostring(slotID)]
    if button then
        self:UpdateItemButton(button, bagID, slotID)
    end
end

function RTB:RefreshCooldowns()
    if not self.ItemButtons then
        return
    end

    local index
    for index = 1, #self.ItemButtons do
        local button = self.ItemButtons[index]
        if button:IsShown() and button.rtbBagID ~= nil then
            ContainerFrame_UpdateCooldown(button.rtbBagID, button)
        end
    end
end

function RTB:UpdateFooter()
    if not self.FreeSlotsText or not self.MoneyText then
        return
    end

    local freeSlots = 0
    local totalSlots = 0
    local _, bagID
    for _, bagID in ipairs(self.BAG_IDS) do
        if self:IsInventoryBagVisible(bagID) then
            totalSlots = totalSlots + (GetContainerNumSlots(bagID) or 0)
            freeSlots = freeSlots + (GetContainerNumFreeSlots(bagID) or 0)
        end
    end

    self.FreeSlotsText:SetText(
        "Free: " .. tostring(freeSlots) .. " / " .. tostring(totalSlots)
    )

    if GetCoinTextureString then
        self.MoneyText:SetText(GetCoinTextureString(GetMoney() or 0))
    else
        self.MoneyText:SetText(tostring(GetMoney() or 0) .. " copper")
    end
    self:LayoutFooterBrand(self.FooterBrand)
end

function RTB:LayoutItems()
    self.LayoutPending = false
    if not self.MainFrame or not self.ItemScroll or not self.ItemContent then
        return
    end

    local availableWidth = self.ItemScroll:GetWidth()
    if not availableWidth or availableWidth < ITEM_SIZE then
        availableWidth = self.MainFrame:GetWidth() - 76
    end
    availableWidth = math.max(ITEM_SIZE, availableWidth)

    local columns = math.floor((availableWidth + ITEM_SPACING) / ITEM_STEP)
    columns = Clamp(columns, 1, MAX_COLUMNS)

    local itemCount = self.VisibleItemCount or 0
    local rowCount = 0
    if itemCount > 0 then
        rowCount = math.ceil(itemCount / columns)
    end

    local viewportHeight = self.ItemScroll:GetHeight()
    if not viewportHeight or viewportHeight < ITEM_SIZE then
        viewportHeight = self.MainFrame:GetHeight() - 152
    end
    viewportHeight = math.max(ITEM_SIZE, viewportHeight)

    local gridHeight = ITEM_SIZE
    if rowCount > 0 then
        gridHeight = (rowCount * ITEM_STEP) - ITEM_SPACING
    end

    self.ItemContent:SetWidth(availableWidth)
    self.ItemContent:SetHeight(math.max(viewportHeight, gridHeight))

    local index
    for index = 1, itemCount do
        local button = self.ItemButtons[index]
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            self.ItemContent,
            "TOPLEFT",
            column * ITEM_STEP,
            -(row * ITEM_STEP)
        )
    end

    self.Columns = columns
    if self.ColumnsText then
        self.ColumnsText:SetText(tostring(columns) .. " cols")
    end
    self:LayoutFooterBrand(self.FooterBrand)
end

function RTB:RequestLayout()
    if not self.LayoutDriver or self.LayoutPending then
        return
    end

    self.LayoutPending = true
    self.LayoutDriver:Show()
end

function RTB:RefreshAll()
    if not self.MainFrame then
        return
    end

    self:UpdateInventoryBagSlots()
    self:RefreshItems()
    self:UpdateFooter()
    self:RequestLayout()
end

function RTB:BuildUI()
    self.ItemButtons = {}
    self.BagParents = {}
    self.ButtonByBagSlot = {}
    self.InventoryBagSlotButtons = {}

    local playerName = UnitName("player") or "Player"
    local window, header, title = self:CreateWindow(
        "RaidThreeBagsFrame",
        self.DEFAULT_WIDTH,
        self.DEFAULT_HEIGHT,
        "Raid Three Bags v" .. self.VERSION .. " - " .. playerName
    )
    self.MainFrame = window
    self.Title = title

    window:SetResizable(true)
    window:SetMinResize(self.MIN_WIDTH, self.MIN_HEIGHT)
    if window.SetMaxResize then
        window:SetMaxResize(self.MAX_WIDTH, self.MAX_HEIGHT)
    end

    local closeButton = CreateFrame(
        "Button",
        "RaidThreeBagsCloseButton",
        window,
        "UIPanelCloseButton"
    )
    closeButton:SetWidth(32)
    closeButton:SetHeight(32)
    closeButton:SetFrameLevel(header:GetFrameLevel() + 10)
    closeButton:SetHitRectInsets(0, 0, 0, 0)
    closeButton:EnableMouse(true)
    closeButton:RegisterForClicks("LeftButtonUp")
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        window:Hide()
    end)
    self.CloseButton = closeButton

    local bagBar = CreateFrame("Frame", nil, window)
    bagBar:SetHeight(INVENTORY_BAG_SIZE)
    bagBar:SetPoint("TOPLEFT", window, "TOPLEFT", 24, -54)
    bagBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -24, -54)
    self.InventoryBagBar = bagBar

    local bagID
    for bagID = NUM_BAG_SLOTS, 1, -1 do
        self:CreateInventoryBagSlot(bagID)
    end
    self:LayoutInventoryBagSlots()

    local itemPanel = CreateFrame("Frame", nil, window)
    itemPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -94)
    itemPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -20, 48)
    itemPanel:SetBackdrop(PANEL_BACKDROP)
    itemPanel:SetBackdropColor(0.02, 0.02, 0.03, 0.80)
    itemPanel:SetBackdropBorderColor(0.30, 0.40, 0.52, 0.75)
    self.ItemPanel = itemPanel

    local scroll = CreateFrame(
        "ScrollFrame",
        "RaidThreeBagsScrollFrame",
        itemPanel,
        "UIPanelScrollFrameTemplate"
    )
    scroll:SetPoint("TOPLEFT", itemPanel, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", itemPanel, "BOTTOMRIGHT", -28, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maximum = self:GetVerticalScrollRange()
        local nextValue = current - (delta * ITEM_STEP * 3)
        self:SetVerticalScroll(Clamp(nextValue, 0, maximum))
    end)
    self.ItemScroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(ITEM_SIZE)
    content:SetHeight(ITEM_SIZE)
    scroll:SetScrollChild(content)
    self.ItemContent = content

    local freeSlotsText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    freeSlotsText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 24, 24)
    freeSlotsText:SetTextColor(0.78, 0.86, 0.94)
    self.FreeSlotsText = freeSlotsText

    local columnsText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    columnsText:SetPoint("LEFT", freeSlotsText, "RIGHT", 14, 0)
    columnsText:SetTextColor(0.52, 0.66, 0.80)
    self.ColumnsText = columnsText

    local moneyText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    moneyText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -30, 22)
    moneyText:SetJustifyH("RIGHT")
    self.MoneyText = moneyText

    self.FooterBrand = self:CreateFooterBrand(
        window,
        columnsText,
        moneyText
    )

    local grip = CreateFrame("Button", nil, window)
    grip:SetWidth(16)
    grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)

    local gripTexture = grip:CreateTexture(nil, "ARTWORK")
    gripTexture:SetAllPoints(grip)
    gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            RTB:StartWindowResize(window, "BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        RTB:StopWindowResize(window)
        RTB:RequestLayout()
    end)
    grip:SetScript("OnEnter", function()
        gripTexture:SetTexture(
            "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
        )
    end)
    grip:SetScript("OnLeave", function()
        gripTexture:SetTexture(
            "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
        )
    end)
    self.ResizeGrip = grip

    local function StartMoving()
        RTB:StartWindowMove(window)
    end

    local function StopMoving()
        RTB:StopWindowMove(window)
    end

    window:SetScript("OnDragStart", StartMoving)
    window:SetScript("OnDragStop", StopMoving)
    header:SetScript("OnDragStart", StartMoving)
    header:SetScript("OnDragStop", StopMoving)
    window:SetScript("OnSizeChanged", function()
        RTB:LayoutFooterBrand(RTB.FooterBrand)
        RTB:RequestLayout()
    end)
    window:SetScript("OnShow", function()
        RTB:RestorePrimaryWindowLock()
        RTB:RefreshAll()
    end)
    window:SetScript("OnHide", function()
        RTB:SaveWindowState()
        if RTB.SettingsFrame
            and RTB.SettingsAnchorFrame == window
        then
            RTB.SettingsFrame:Hide()
        end
    end)

    local layoutDriver = CreateFrame("Frame", nil, window)
    layoutDriver:Hide()
    layoutDriver:SetScript("OnUpdate", function(self)
        self:Hide()
        RTB:LayoutItems()
    end)
    self.LayoutDriver = layoutDriver

    self:CreateSettingsGear(window, "inventory")

    if UISpecialFrames then
        table.insert(UISpecialFrames, "RaidThreeBagsFrame")
    end
end

function RTB:EnsureUI()
    if self.MainFrame then
        return
    end

    self:BuildUI()
    self:ApplyWindowState()
end

local function SetOnOffToggleState(button, enabled)
    if enabled then
        button:SetText("ON")
        button:LockHighlight()
    else
        button:SetText("OFF")
        button:UnlockHighlight()
    end

    local fontString = button:GetFontString()
    if fontString then
        if enabled then
            fontString:SetTextColor(0, 1, 0)
        else
            fontString:SetTextColor(1, 0.2, 0.2)
        end
    end

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetBlendMode("ADD")
        if enabled then
            highlight:SetVertexColor(0, 1, 0, 0.70)
        else
            highlight:SetVertexColor(1, 0.12, 0.12, 0.75)
        end
    end
end

function RTB:RefreshSettingsUI()
    if not self.SettingsFrame then
        return
    end

    local _, row
    for _, row in ipairs(self.SpecialBagRows or {}) do
        SetOnOffToggleState(
            row.toggle,
            not self:GetSpecialBagInvisible(row.definition.family)
        )
    end
    if self.WindowLockButton then
        SetOnOffToggleState(
            self.WindowLockButton,
            self:GetWindowLockEnabled()
        )
    end
end

function RTB:LayoutSettings()
    if not self.SettingsFrame or not self.SettingsTableContent then
        return
    end

    local tableWidth =
        self.SettingsFrame:GetWidth() - SETTINGS_TABLE_WIDTH_OVERHEAD
    self.SettingsTableContent:SetWidth(math.max(1, tableWidth))
    self.SettingsTableContent:SetHeight(
        #self.SPECIAL_BAG_TYPES * SETTINGS_ROW_HEIGHT
    )
end

function RTB:PositionSettingsFrame(anchor)
    if not self.SettingsFrame or not anchor then
        return
    end

    local right = anchor:GetRight() or 0
    local rightSpace = GetScreenWidth() - right
    local neededSpace = self.SettingsFrame:GetWidth() + 10

    self.SettingsFrame:ClearAllPoints()
    if rightSpace >= neededSpace then
        self.SettingsFrame:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    else
        self.SettingsFrame:SetPoint("RIGHT", anchor, "LEFT", -10, 0)
    end
end

function RTB:BuildSettingsUI()
    self.SpecialBagRows = {}

    local window, header, title = self:CreateWindow(
        "RaidThreeBagsSettingsFrame",
        SETTINGS_WIDTH,
        SETTINGS_HEIGHT,
        "Raid Three Bags Settings"
    )
    window:SetFrameStrata("DIALOG")
    window:SetBackdropColor(0, 0, 0, 0.97)
    window:SetResizable(true)
    window:SetMinResize(SETTINGS_MIN_WIDTH, SETTINGS_MIN_HEIGHT)
    if window.SetMaxResize then
        window:SetMaxResize(SETTINGS_MAX_WIDTH, SETTINGS_MAX_HEIGHT)
    end
    self.SettingsFrame = window
    self.SettingsTitle = title

    local closeButton = CreateFrame(
        "Button",
        "RaidThreeBagsSettingsCloseButton",
        window,
        "UIPanelCloseButton"
    )
    closeButton:SetWidth(32)
    closeButton:SetHeight(32)
    closeButton:SetFrameLevel(header:GetFrameLevel() + 10)
    closeButton:SetHitRectInsets(0, 0, 0, 0)
    closeButton:EnableMouse(true)
    closeButton:RegisterForClicks("LeftButtonUp")
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        window:Hide()
    end)
    self.SettingsCloseButton = closeButton

    local content = CreateFrame("Frame", nil, window)
    content:SetPoint(
        "TOPLEFT",
        window,
        "TOPLEFT",
        SETTINGS_CONTENT_SIDE,
        -SETTINGS_CONTENT_TOP
    )
    content:SetPoint(
        "BOTTOMRIGHT",
        window,
        "BOTTOMRIGHT",
        -SETTINGS_CONTENT_SIDE,
        SETTINGS_CONTENT_BOTTOM
    )
    content:SetBackdrop(PANEL_BACKDROP)
    content:SetBackdropColor(0.03, 0.03, 0.05, 0.82)
    content:SetBackdropBorderColor(0.30, 0.40, 0.52, 0.75)
    self.SettingsContent = content

    local layoutHeading = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    layoutHeading:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -13)
    layoutHeading:SetText("Window layout")
    layoutHeading:SetTextColor(1, 0.82, 0)

    local windowLockLabel = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    windowLockLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -94, -15)
    windowLockLabel:SetText("Corner lock")
    windowLockLabel:SetTextColor(0.85, 0.90, 0.96)

    local windowLock = CreateFrame(
        "Button",
        nil,
        content,
        "UIPanelButtonTemplate"
    )
    windowLock:SetWidth(70)
    windowLock:SetHeight(22)
    windowLock:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -9)
    windowLock:SetScript("OnClick", function()
        RTB:SetWindowLockEnabled(not RTB:GetWindowLockEnabled())
    end)
    windowLock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Corner lock", 0.85, 0.92, 1)
        GameTooltip:AddLine(
            "Green ON joins compatible window corners.",
            0,
            1,
            0,
            true
        )
        GameTooltip:AddLine(
            "Hold Shift while moving a window to disconnect it.",
            1,
            0.82,
            0,
            true
        )
        GameTooltip:Show()
    end)
    windowLock:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.WindowLockButton = windowLock

    local resetInventory = CreateFrame(
        "Button",
        nil,
        content,
        "UIPanelButtonTemplate"
    )
    resetInventory:SetWidth(SETTINGS_RESET_BUTTON_WIDTH)
    resetInventory:SetHeight(26)
    resetInventory:SetPoint(
        "TOPLEFT",
        layoutHeading,
        "BOTTOMLEFT",
        0,
        -8
    )
    resetInventory:SetText("Reset Inventory Window")
    resetInventory:SetScript("OnClick", function()
        RTB:ResetInventoryWindowState()
    end)
    self.ResetInventoryButton = resetInventory

    local resetBank = CreateFrame(
        "Button",
        nil,
        content,
        "UIPanelButtonTemplate"
    )
    resetBank:SetWidth(SETTINGS_RESET_BUTTON_WIDTH)
    resetBank:SetHeight(26)
    resetBank:SetPoint(
        "LEFT",
        resetInventory,
        "RIGHT",
        SETTINGS_RESET_BUTTON_GAP,
        0
    )
    resetBank:SetText("Reset Player Bank Window")
    resetBank:SetScript("OnClick", function()
        RTB:ResetBankWindowState()
    end)
    self.ResetBankButton = resetBank

    local divider = content:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -79)
    divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -79)
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.7, 0.85, 1, 0.24)

    local bagsHeading = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    bagsHeading:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -94)
    bagsHeading:SetText("Special bag slot invisibility")
    bagsHeading:SetTextColor(1, 0.82, 0)

    local note = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    note:SetPoint("TOPLEFT", bagsHeading, "BOTTOMLEFT", 0, -5)
    note:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -116)
    note:SetHeight(30)
    note:SetJustifyH("LEFT")
    note:SetJustifyV("TOP")
    note:SetText(
        "Green ON keeps every slot of that equipped special bag visible. " ..
        "Red OFF hides its slots from the inventory grid."
    )
    note:SetTextColor(0.72, 0.76, 0.82)

    local typeHeader = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    typeHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 18, -150)
    typeHeader:SetText("SPECIAL BAG TYPE")
    typeHeader:SetTextColor(0.60, 0.78, 1)

    local stateHeader = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )
    stateHeader:SetPoint("TOPRIGHT", content, "TOPRIGHT", -42, -150)
    stateHeader:SetText("VISIBLE")
    stateHeader:SetTextColor(0.60, 0.78, 1)
    self.SettingsStateHeader = stateHeader

    local tableScroll = CreateFrame(
        "ScrollFrame",
        "RaidThreeBagsSettingsScrollFrame",
        content,
        "UIPanelScrollFrameTemplate"
    )
    tableScroll:SetPoint(
        "TOPLEFT",
        content,
        "TOPLEFT",
        SETTINGS_INNER_SIDE,
        -SETTINGS_LIST_TOP
    )
    tableScroll:SetPoint(
        "BOTTOMRIGHT",
        content,
        "BOTTOMRIGHT",
        -32,
        SETTINGS_LIST_BOTTOM
    )
    tableScroll:EnableMouseWheel(true)
    tableScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maximum = self:GetVerticalScrollRange()
        local nextValue =
            current - (delta * SETTINGS_ROW_HEIGHT * 3)
        self:SetVerticalScroll(Clamp(nextValue, 0, maximum))
    end)
    self.SettingsTableScroll = tableScroll

    local tableContent = CreateFrame("Frame", nil, tableScroll)
    tableContent:SetWidth(
        SETTINGS_WIDTH - SETTINGS_TABLE_WIDTH_OVERHEAD
    )
    tableContent:SetHeight(
        #self.SPECIAL_BAG_TYPES * SETTINGS_ROW_HEIGHT
    )
    tableScroll:SetScrollChild(tableContent)
    self.SettingsTableContent = tableContent

    local index, definition
    for index, definition in ipairs(self.SPECIAL_BAG_TYPES) do
        local rowDefinition = definition
        local row = CreateFrame("Frame", nil, tableContent)
        row:SetHeight(SETTINGS_ROW_HEIGHT)
        row:SetPoint(
            "TOPLEFT",
            tableContent,
            "TOPLEFT",
            0,
            -((index - 1) * SETTINGS_ROW_HEIGHT)
        )
        row:SetPoint(
            "TOPRIGHT",
            tableContent,
            "TOPRIGHT",
            0,
            -((index - 1) * SETTINGS_ROW_HEIGHT)
        )

        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(row)
        background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        if index % 2 == 0 then
            background:SetVertexColor(0.10, 0.13, 0.18, 0.62)
        else
            background:SetVertexColor(0.06, 0.08, 0.12, 0.62)
        end

        local label = row:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlight"
        )
        label:SetPoint("LEFT", row, "LEFT", 8, 0)
        label:SetText(rowDefinition.label)
        label:SetTextColor(0.85, 0.90, 0.96)

        local toggle = CreateFrame(
            "Button",
            nil,
            row,
            "UIPanelButtonTemplate"
        )
        toggle:SetWidth(70)
        toggle:SetHeight(22)
        toggle:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        toggle:SetScript("OnClick", function()
            local invisible = RTB:GetSpecialBagInvisible(
                rowDefinition.family
            )
            RTB:SetSpecialBagInvisible(
                rowDefinition.family,
                not invisible
            )
            RTB:RefreshSettingsUI()
        end)
        toggle:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(rowDefinition.label, 0.85, 0.92, 1)
            GameTooltip:AddLine(
                "Green ON: bag slots remain visible.",
                0,
                1,
                0,
                true
            )
            GameTooltip:AddLine(
                "Red OFF: bag slots are hidden from the inventory.",
                1,
                0.2,
                0.2,
                true
            )
            GameTooltip:Show()
        end)
        toggle:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.definition = rowDefinition
        row.toggle = toggle
        self.SpecialBagRows[index] = row
    end

    local close = CreateFrame(
        "Button",
        nil,
        window,
        "UIPanelButtonTemplate"
    )
    close:SetWidth(100)
    close:SetHeight(24)
    close:SetPoint("BOTTOM", window, "BOTTOM", 0, 16)
    close:SetText("Close")
    close:SetScript("OnClick", function()
        window:Hide()
    end)
    self.SettingsBottomClose = close

    local grip = CreateFrame("Button", nil, window)
    grip:SetWidth(16)
    grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)

    local gripTexture = grip:CreateTexture(nil, "ARTWORK")
    gripTexture:SetAllPoints(grip)
    gripTexture:SetTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
    )

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            RTB:StartWindowResize(window, "BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        RTB:StopWindowResize(window)
        RTB:LayoutSettings()
    end)
    grip:SetScript("OnEnter", function()
        gripTexture:SetTexture(
            "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
        )
    end)
    grip:SetScript("OnLeave", function()
        gripTexture:SetTexture(
            "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
        )
    end)
    self.SettingsResizeGrip = grip

    local function StartMoving()
        RTB:StartWindowMove(window)
    end

    local function StopMoving()
        RTB:StopWindowMove(window)
    end

    window:SetScript("OnDragStart", StartMoving)
    window:SetScript("OnDragStop", StopMoving)
    header:SetScript("OnDragStart", StartMoving)
    header:SetScript("OnDragStop", StopMoving)
    window:SetScript("OnSizeChanged", function()
        RTB:LayoutSettings()
    end)
    window:SetScript("OnShow", function()
        RTB:LayoutSettings()
        RTB:RefreshSettingsUI()
    end)
    window:SetScript("OnHide", function()
        RTB:DisconnectWindow(window)
        RTB:SavePrimaryWindowStates()
    end)

    self:LayoutSettings()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "RaidThreeBagsSettingsFrame")
    end
end

function RTB:EnsureSettingsUI()
    if self.SettingsFrame then
        return
    end
    self:BuildSettingsUI()
end

function RTB:ToggleSettings(anchor)
    self:EnsureSettingsUI()
    if self.SettingsFrame:IsShown()
        and self.SettingsAnchorFrame == anchor
    then
        self.SettingsFrame:Hide()
        return
    end

    self.SettingsAnchorFrame = anchor
    self:PositionSettingsFrame(anchor)
    self:RefreshSettingsUI()
    self.SettingsFrame:Show()
end
