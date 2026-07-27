-- ============================================================
-- RTB_Bank.lua
-- Responsive live player-bank window and optional Bagnon bridge.
-- Target: WoW 3.3.5a / Interface 30300 / Lua 5.1.
-- ============================================================

local RTB = RaidThreeBags

local ITEM_SIZE = 36
local ITEM_SPACING = 4
local ITEM_STEP = ITEM_SIZE + ITEM_SPACING
local MAX_COLUMNS = 22
local BANK_BAG_SIZE = 30
local BANK_BAG_SPACING = 4

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
    value = tonumber(value) or minimum
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function GetEmptySlotColor(bagType)
    local color = EMPTY_SLOT_COLORS[tonumber(bagType) or 0]
    if color then
        return color[1], color[2], color[3]
    end
    return EMPTY_SLOT_COLORS[0][1], EMPTY_SLOT_COLORS[0][2], EMPTY_SLOT_COLORS[0][3]
end

local function IsBankBagID(bagID)
    return type(bagID) == "number"
        and bagID > NUM_BAG_SLOTS
        and bagID <= NUM_BAG_SLOTS + NUM_BANKBAGSLOTS
end

local function GetBankContainerSize(bagID)
    if bagID == BANK_CONTAINER then
        return NUM_BANKGENERIC_SLOTS or GetContainerNumSlots(bagID) or 0
    end
    return GetContainerNumSlots(bagID) or 0
end

function RTB:SaveBankWindowState()
    if not self.DB or not self.PlayerBankFrame then
        return
    end

    local state = self.DB.bankWindow
    local left = self.PlayerBankFrame:GetLeft()
    local bottom = self.PlayerBankFrame:GetBottom()
    local screenLeft = UIParent:GetLeft() or 0
    local screenBottom = UIParent:GetBottom() or 0
    if type(left) == "number" and type(bottom) == "number" then
        state.point = "BOTTOMLEFT"
        state.relativePoint = "BOTTOMLEFT"
        state.x = left - screenLeft
        state.y = bottom - screenBottom
    end
    state.width = Clamp(
        self.PlayerBankFrame:GetWidth(),
        self.BANK_MIN_WIDTH,
        self.BANK_MAX_WIDTH
    )
    state.height = Clamp(
        self.PlayerBankFrame:GetHeight(),
        self.BANK_MIN_HEIGHT,
        self.BANK_MAX_HEIGHT
    )
end

function RTB:ApplyBankWindowState()
    if not self.DB or not self.PlayerBankFrame then
        return
    end

    local state = self.DB.bankWindow
    local width = Clamp(
        state.width,
        self.BANK_MIN_WIDTH,
        self.BANK_MAX_WIDTH
    )
    local height = Clamp(
        state.height,
        self.BANK_MIN_HEIGHT,
        self.BANK_MAX_HEIGHT
    )

    self.PlayerBankFrame:SetWidth(width)
    self.PlayerBankFrame:SetHeight(height)
    self.PlayerBankFrame:ClearAllPoints()
    self.PlayerBankFrame:SetPoint(
        state.point or "RIGHT",
        UIParent,
        state.relativePoint or "CENTER",
        tonumber(state.x) or -250,
        tonumber(state.y) or 0
    )
    self:RequestBankLayout()
end

function RTB:GetBankBagParent(bagID)
    local parent = self.BankBagParents[bagID]
    if parent then
        return parent
    end

    parent = CreateFrame("Frame", nil, self.BankItemContent)
    parent:SetAllPoints(self.BankItemContent)
    parent:SetID(bagID)
    self.BankBagParents[bagID] = parent
    return parent
end

function RTB:UpdateBankItemTooltip(button)
    if not button or not button.rtbBankBagID then
        return
    end

    if button:GetRight() and button:GetRight() > (GetScreenWidth() / 2) then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    end

    if button.rtbBankBagID == BANK_CONTAINER then
        if button.hasItem then
            GameTooltip:SetInventoryItem(
                "player",
                BankButtonIDToInvSlotID(button.rtbBankSlotID)
            )
            GameTooltip:Show()
            if CursorUpdate then
                CursorUpdate(button)
            end
        end
    else
        ContainerFrameItemButton_OnEnter(button)
    end
end

function RTB:CreateBankItemButton()
    local index = #self.BankItemButtons + 1
    local parent = self:GetBankBagParent(BANK_CONTAINER)
    local button = CreateFrame(
        "Button",
        "RaidThreeBagsBankItem" .. tostring(index),
        parent,
        "ContainerFrameItemButtonTemplate"
    )

    button:SetWidth(ITEM_SIZE)
    button:SetHeight(ITEM_SIZE)
    button:SetScript("OnEvent", nil)
    button:UnregisterAllEvents()
    button:SetScript("OnEnter", function(self)
        RTB:UpdateBankItemTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
        if ResetCursor then
            ResetCursor()
        end
    end)
    button.UpdateTooltip = function(self)
        RTB:UpdateBankItemTooltip(self)
    end

    local qualityBorder = button:CreateTexture(nil, "OVERLAY")
    qualityBorder:SetWidth(62)
    qualityBorder:SetHeight(62)
    qualityBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
    qualityBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    qualityBorder:SetBlendMode("ADD")
    qualityBorder:Hide()

    button.rtbQualityBorder = qualityBorder
    self.BankItemButtons[index] = button
    return button
end

function RTB:UpdateBankItemButton(button, bagID, slotID)
    local bagParent = self:GetBankBagParent(bagID)
    if button:GetParent() ~= bagParent then
        button:SetParent(bagParent)
    end

    button:SetID(slotID)
    button.rtbBankBagID = bagID
    button.rtbBankSlotID = slotID

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

function RTB:RefreshBankItems()
    if not self.BankItemContent or not self.AtBank then
        return
    end

    local index
    for index = 1, #self.BankItemButtons do
        self.BankItemButtons[index]:Hide()
    end

    self.BankButtonByBagSlot = {}
    local visibleIndex = 0

    local function AddBag(bagID)
        local slotCount = GetBankContainerSize(bagID)
        local slotID
        for slotID = 1, slotCount do
            visibleIndex = visibleIndex + 1
            local button =
                self.BankItemButtons[visibleIndex] or self:CreateBankItemButton()
            self:UpdateBankItemButton(button, bagID, slotID)
            button.rtbBankVisibleIndex = visibleIndex
            self.BankButtonByBagSlot[
                tostring(bagID) .. ":" .. tostring(slotID)
            ] = button
            button:Show()
        end
    end

    AddBag(BANK_CONTAINER)
    local _, bagID
    for _, bagID in ipairs(self.BANK_BAG_IDS) do
        AddBag(bagID)
    end

    self.BankVisibleItemCount = visibleIndex
    self:RequestBankLayout()
end

function RTB:RefreshBankCooldowns()
    if not self.BankItemButtons then
        return
    end

    local index
    for index = 1, #self.BankItemButtons do
        local button = self.BankItemButtons[index]
        if button:IsShown() and button.rtbBankBagID ~= nil then
            ContainerFrame_UpdateCooldown(button.rtbBankBagID, button)
        end
    end
end

function RTB:UpdateBankFooter()
    if not self.BankFreeSlotsText or not self.BankSlotsText then
        return
    end

    local freeSlots = 0
    local totalSlots = 0
    local function AddBagTotals(bagID)
        totalSlots = totalSlots + GetBankContainerSize(bagID)
        freeSlots = freeSlots + (GetContainerNumFreeSlots(bagID) or 0)
    end

    AddBagTotals(BANK_CONTAINER)
    local _, bagID
    for _, bagID in ipairs(self.BANK_BAG_IDS) do
        AddBagTotals(bagID)
    end

    self.BankFreeSlotsText:SetText(
        "Free: " .. tostring(freeSlots) .. " / " .. tostring(totalSlots)
    )

    local purchased = GetNumBankSlots() or 0
    self.BankSlotsText:SetText(
        "Bank bags: " .. tostring(purchased) .. " / " .. tostring(NUM_BANKBAGSLOTS)
    )

    if GetCoinTextureString then
        self.BankMoneyText:SetText(GetCoinTextureString(GetMoney() or 0))
    else
        self.BankMoneyText:SetText(tostring(GetMoney() or 0) .. " copper")
    end
    self:LayoutFooterBrand(self.BankFooterBrand)
end

function RTB:ShowBankSlotPurchase()
    if not self.AtBank then
        return
    end

    local dialogID = "CONFIRM_BUY_BANK_SLOT_RAIDTHREEBAGS"
    if not StaticPopupDialogs[dialogID] then
        StaticPopupDialogs[dialogID] = {
            text = CONFIRM_BUY_BANK_SLOT,
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                PurchaseSlot()
            end,
            OnShow = function(popup)
                MoneyFrame_Update(
                    popup:GetName() .. "MoneyFrame",
                    GetBankSlotCost(GetNumBankSlots())
                )
            end,
            hasMoneyFrame = 1,
            timeout = 0,
            hideOnEscape = 1
        }
    end
    StaticPopup_Show(dialogID)
end

function RTB:HandleBankBagSlotClick(button)
    if not self.AtBank or not button then
        return
    end

    if not button.rtbPurchased then
        self:ShowBankSlotPurchase()
    elseif CursorHasItem() then
        PutItemInBag(button.rtbInventorySlot)
    end
    self:UpdateBankBagSlots()
end

function RTB:HandleBankBagSlotDrag(button)
    if not self.AtBank or not button or not button.rtbPurchased then
        return
    end

    PlaySound("BAGMENUBUTTONPRESS")
    PickupBagFromSlot(button.rtbInventorySlot)
    self:UpdateBankBagSlots()
end

function RTB:UpdateBankBagSlotTooltip(button)
    if not button then
        return
    end

    if button:GetRight() and button:GetRight() > (GetScreenWidth() / 2) then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    end

    if not GameTooltip:SetInventoryItem("player", button.rtbInventorySlot) then
        if not button.rtbPurchased then
            GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
            SetTooltipMoney(GameTooltip, GetBankSlotCost(GetNumBankSlots()))
        else
            GameTooltip:SetText(BANK_BAG or EQUIP_CONTAINER, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

function RTB:CreateBankBagSlot(bagID)
    local index = #self.BankBagSlotButtons + 1
    local button = CreateFrame(
        "Button",
        "RaidThreeBagsBankBag" .. tostring(index),
        self.BankBagBar
    )
    button:SetWidth(BANK_BAG_SIZE)
    button:SetHeight(BANK_BAG_SIZE)
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
    button.rtbBankBagID = bagID
    button.rtbInventorySlot = BankButtonIDToInvSlotID(bagID, 1)

    button:SetScript("OnClick", function(self)
        RTB:HandleBankBagSlotClick(self)
    end)
    button:SetScript("OnDragStart", function(self)
        RTB:HandleBankBagSlotDrag(self)
    end)
    button:SetScript("OnReceiveDrag", function(self)
        RTB:HandleBankBagSlotClick(self)
    end)
    button:SetScript("OnEnter", function(self)
        RTB:UpdateBankBagSlotTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)

    self.BankBagSlotButtons[index] = button
    return button
end

function RTB:UpdateBankBagSlots()
    if not self.BankBagSlotButtons or not self.AtBank then
        return
    end

    local purchasedSlots = GetNumBankSlots() or 0
    local index, button
    for index, button in ipairs(self.BankBagSlotButtons) do
        local purchased =
            button.rtbBankBagID <= NUM_BAG_SLOTS + purchasedSlots
        local texture
        if purchased then
            texture = GetInventoryItemTexture(
                "player",
                button.rtbInventorySlot
            )
        end

        button.rtbPurchased = purchased
        button.rtbIcon:SetTexture(
            texture or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
        )

        if texture then
            button.rtbIcon:SetVertexColor(1, 1, 1)
        elseif purchased then
            button.rtbIcon:SetVertexColor(0.7, 0.7, 0.7)
        else
            button.rtbIcon:SetVertexColor(1, 0.15, 0.15)
        end

        local locked = purchased
            and IsInventoryItemLocked(button.rtbInventorySlot)
        if button.rtbIcon.SetDesaturated then
            button.rtbIcon:SetDesaturated(locked and true or false)
        end

        if purchased
            and CursorCanGoInSlot
            and CursorCanGoInSlot(button.rtbInventorySlot)
        then
            button.rtbCursorHighlight:Show()
        else
            button.rtbCursorHighlight:Hide()
        end
    end
end

function RTB:LayoutBankBagSlots()
    if not self.BankBagBar or not self.BankBagSlotButtons then
        return
    end

    local index, button
    for index, button in ipairs(self.BankBagSlotButtons) do
        button:ClearAllPoints()
        button:SetPoint(
            "LEFT",
            self.BankBagBar,
            "LEFT",
            (index - 1) * (BANK_BAG_SIZE + BANK_BAG_SPACING),
            0
        )
    end
end

function RTB:LayoutBankItems()
    self.BankLayoutPending = false
    if not self.PlayerBankFrame
        or not self.BankItemScroll
        or not self.BankItemContent
    then
        return
    end

    local availableWidth = self.BankItemScroll:GetWidth()
    if not availableWidth or availableWidth < ITEM_SIZE then
        availableWidth = self.PlayerBankFrame:GetWidth() - 76
    end
    availableWidth = math.max(ITEM_SIZE, availableWidth)

    local columns = math.floor((availableWidth + ITEM_SPACING) / ITEM_STEP)
    columns = Clamp(columns, 1, MAX_COLUMNS)

    local itemCount = self.BankVisibleItemCount or 0
    local rowCount = 0
    if itemCount > 0 then
        rowCount = math.ceil(itemCount / columns)
    end

    local viewportHeight = self.BankItemScroll:GetHeight()
    if not viewportHeight or viewportHeight < ITEM_SIZE then
        viewportHeight = self.PlayerBankFrame:GetHeight() - 154
    end
    viewportHeight = math.max(ITEM_SIZE, viewportHeight)

    local gridHeight = ITEM_SIZE
    if rowCount > 0 then
        gridHeight = (rowCount * ITEM_STEP) - ITEM_SPACING
    end

    self.BankItemContent:SetWidth(availableWidth)
    self.BankItemContent:SetHeight(math.max(viewportHeight, gridHeight))

    local index
    for index = 1, itemCount do
        local button = self.BankItemButtons[index]
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            self.BankItemContent,
            "TOPLEFT",
            column * ITEM_STEP,
            -(row * ITEM_STEP)
        )
    end

    self.BankColumns = columns
    if self.BankColumnsText then
        self.BankColumnsText:SetText(tostring(columns) .. " cols")
    end
    self:LayoutFooterBrand(self.BankFooterBrand)
end

function RTB:RequestBankLayout()
    if not self.BankLayoutDriver or self.BankLayoutPending then
        return
    end

    self.BankLayoutPending = true
    self.BankLayoutDriver:Show()
end

function RTB:RefreshBankAll()
    if not self.PlayerBankFrame or not self.AtBank then
        return
    end

    self:RefreshBankItems()
    self:UpdateBankBagSlots()
    self:UpdateBankFooter()
    self:RequestBankLayout()
end

function RTB:BuildBankUI()
    self.BankItemButtons = {}
    self.BankBagParents = {}
    self.BankButtonByBagSlot = {}
    self.BankBagSlotButtons = {}

    local playerName = UnitName("player") or "Player"
    local window, header, title = self:CreateWindow(
        "RaidThreeBagsBankFrame",
        self.BANK_DEFAULT_WIDTH,
        self.BANK_DEFAULT_HEIGHT,
        "Raid Three Bank v" .. self.VERSION .. " - " .. playerName
    )
    self.PlayerBankFrame = window
    self.BankTitle = title

    window:SetResizable(true)
    window:SetMinResize(self.BANK_MIN_WIDTH, self.BANK_MIN_HEIGHT)
    if window.SetMaxResize then
        window:SetMaxResize(self.BANK_MAX_WIDTH, self.BANK_MAX_HEIGHT)
    end

    local closeButton = CreateFrame(
        "Button",
        "RaidThreeBagsBankCloseButton",
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
    self.BankCloseButton = closeButton

    local bagBar = CreateFrame("Frame", nil, window)
    bagBar:SetHeight(BANK_BAG_SIZE)
    bagBar:SetPoint("TOPLEFT", window, "TOPLEFT", 24, -54)
    bagBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -24, -54)
    self.BankBagBar = bagBar

    local _, bagID
    for _, bagID in ipairs(self.BANK_BAG_IDS) do
        self:CreateBankBagSlot(bagID)
    end
    self:LayoutBankBagSlots()

    local itemPanel = CreateFrame("Frame", nil, window)
    itemPanel:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -94)
    itemPanel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -20, 48)
    itemPanel:SetBackdrop(PANEL_BACKDROP)
    itemPanel:SetBackdropColor(0.02, 0.02, 0.03, 0.80)
    itemPanel:SetBackdropBorderColor(0.30, 0.40, 0.52, 0.75)
    self.BankItemPanel = itemPanel

    local scroll = CreateFrame(
        "ScrollFrame",
        "RaidThreeBagsBankScrollFrame",
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
    self.BankItemScroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(ITEM_SIZE)
    content:SetHeight(ITEM_SIZE)
    scroll:SetScrollChild(content)
    self.BankItemContent = content

    local freeSlotsText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    freeSlotsText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 24, 24)
    freeSlotsText:SetTextColor(0.78, 0.86, 0.94)
    self.BankFreeSlotsText = freeSlotsText

    local bankSlotsText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    bankSlotsText:SetPoint("LEFT", freeSlotsText, "RIGHT", 14, 0)
    bankSlotsText:SetTextColor(0.62, 0.76, 0.88)
    self.BankSlotsText = bankSlotsText

    local columnsText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    columnsText:SetPoint("LEFT", bankSlotsText, "RIGHT", 14, 0)
    columnsText:SetTextColor(0.52, 0.66, 0.80)
    self.BankColumnsText = columnsText

    local moneyText = window:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    moneyText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -30, 22)
    moneyText:SetJustifyH("RIGHT")
    self.BankMoneyText = moneyText

    self.BankFooterBrand = self:CreateFooterBrand(
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
        RTB:RequestBankLayout()
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
    self.BankResizeGrip = grip

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
        RTB:LayoutFooterBrand(RTB.BankFooterBrand)
        RTB:RequestBankLayout()
    end)
    window:SetScript("OnShow", function()
        RTB:RestorePrimaryWindowLock()
        RTB:RefreshBankAll()
    end)
    window:SetScript("OnHide", function()
        RTB:SaveBankWindowState()
        if RTB.SettingsFrame
            and RTB.SettingsAnchorFrame == window
        then
            RTB.SettingsFrame:Hide()
        end
        if RTB.AtBank and CloseBankFrame then
            CloseBankFrame()
        end
    end)

    local layoutDriver = CreateFrame("Frame", nil, window)
    layoutDriver:Hide()
    layoutDriver:SetScript("OnUpdate", function(self)
        self:Hide()
        RTB:LayoutBankItems()
    end)
    self.BankLayoutDriver = layoutDriver

    self:CreateSettingsGear(window, "bank")

    if UISpecialFrames then
        table.insert(UISpecialFrames, "RaidThreeBagsBankFrame")
    end
end

function RTB:EnsureBankUI()
    if self.PlayerBankFrame then
        return
    end

    self:BuildBankUI()
    self:ApplyBankWindowState()
end

function RTB:InstallBankHooks()
    if self.BankHooksInstalled then
        return
    end
    self.BankHooksInstalled = true

    if BankFrame then
        BankFrame:UnregisterEvent("BANKFRAME_OPENED")
        BankFrame:UnregisterEvent("BANKFRAME_CLOSED")
    end
end

function RTB:HideBagnonBankWithoutClosing(bagnon)
    local frame
    if type(bagnon.GetFrame) == "function" then
        local ok, result = pcall(bagnon.GetFrame, bagnon, "bank")
        if ok then
            frame = result
        end
    end

    if frame
        and frame.IsShown
        and frame:IsShown()
        and type(frame.CloseBankFrame) == "function"
    then
        local ownCloseMethod = rawget(frame, "CloseBankFrame")
        frame.CloseBankFrame = function()
        end
        local ok, result = pcall(bagnon.HideFrame, bagnon, "bank")
        frame.CloseBankFrame = ownCloseMethod
        return ok, result
    end

    return pcall(bagnon.HideFrame, bagnon, "bank")
end

function RTB:HideCompetingBankFrames()
    local bagnon = _G["Bagnon"]
    if type(bagnon) == "table" and type(bagnon.HideFrame) == "function" then
        self:HideBagnonBankWithoutClosing(bagnon)
        pcall(bagnon.HideFrame, bagnon, "inventory")
    end
end

function RTB:ShowFallbackBank()
    local bagnon = _G["Bagnon"]
    if type(bagnon) == "table" and type(bagnon.ShowFrame) == "function" then
        local ok, shown = pcall(bagnon.ShowFrame, bagnon, "bank")
        if ok and shown then
            return
        end
    end

    if BankFrame and BankFrame_OnEvent then
        BankFrame_OnEvent(BankFrame, "BANKFRAME_OPENED")
    end
end

function RTB:RunBankAction(methodName)
    local method = self[methodName]
    if type(method) ~= "function" then
        self:Print("Bank UI method is unavailable.")
        return false
    end

    local ok, err = pcall(method, self)
    if ok then
        return true
    end

    self:Print("Bank UI error: " .. tostring(err))
    if self.AtBank then
        self:ShowFallbackBank()
    end
    return false
end

function RTB:ShowBank()
    if not self.AtBank then
        self:Print("Hracska banka je dostupna iba pri bankerovi.")
        return
    end

    self:EnsureBankUI()
    self:HideCompetingBankFrames()
    self:RefreshBankAll()
    self.PlayerBankFrame:Show()
end

function RTB:HideBank()
    if self.PlayerBankFrame then
        self.PlayerBankFrame:Hide()
    end
end

function RTB:ToggleBank()
    if not self.AtBank then
        self:Print("Hracska banka je dostupna iba pri bankerovi.")
        return
    end

    self:EnsureBankUI()
    if self.PlayerBankFrame:IsShown() then
        self:HideBank()
    else
        self:ShowBank()
    end
end

function RTB:BANKFRAME_OPENED()
    self.AtBank = true
    self.InventoryOpenedForBank =
        not self.MainFrame or not self.MainFrame:IsShown()

    self:RunBagAction("Show")
    if not self:RunBankAction("ShowBank") then
        return
    end

    if not self.BankCompatibilityDriver then
        local driver = CreateFrame("Frame")
        driver:Hide()
        driver:SetScript("OnUpdate", function(self)
            self:Hide()
            if RTB.AtBank and RTB.PlayerBankFrame
                and RTB.PlayerBankFrame:IsShown()
            then
                RTB:HideCompetingBankFrames()
            end
        end)
        self.BankCompatibilityDriver = driver
    end
    self.BankCompatibilityDriver:Show()
end

function RTB:BANKFRAME_CLOSED()
    self.AtBank = false
    self:HideBank()
    if BankFrame and BankFrame:IsShown() and BankFrame_OnEvent then
        BankFrame_OnEvent(BankFrame, "BANKFRAME_CLOSED")
    end
    if self.InventoryOpenedForBank then
        self:Hide()
    end
    self.InventoryOpenedForBank = nil
end

function RTB:PLAYERBANKSLOTS_CHANGED()
    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:RefreshBankAll()
    end
end

function RTB:PLAYERBANKBAGSLOTS_CHANGED()
    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:RefreshBankAll()
    end
end

function RTB:CURSOR_UPDATE()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:UpdateInventoryBagSlots()
    end
    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:UpdateBankBagSlots()
    end
end
