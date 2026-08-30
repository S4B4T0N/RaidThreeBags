-- RaidThreeBags settings behavior test under PUC Lua 5.1.
-- Usage: lua SettingsLogicMock.lua <source-directory>

local sourceDirectory = assert(arg[1], "source directory is required")
sourceDirectory = string.gsub(sourceDirectory, "\\", "/")

local chatMessages = {}
local shiftKeyDown = false
local bagTypes = {
    [1] = 4
}
local bagTextures = {
    [20] = "BagOne",
    [21] = "BagTwo",
    [23] = "BagFour"
}
local cursorHasItem = false
local cursorTargetSlot
local putItemSlot
local pickedUpBagSlot
local playedSound
local mockTime = 200000
local inventoryData = {}
local inventorySlotCounts = {}
local itemInfoByID = {}
local containerCursor
local combatLocked = false
local pickupSnapshot
local laggedInventoryData
local laggedContainerReads = 0
local laggedReadsAfterMove = 2
local postMoveLockReads = 0
local postMoveLocksRemaining = 0

local function SnapshotInventory()
    local snapshot = {}
    local bagID, slots
    for bagID, slots in pairs(inventoryData) do
        snapshot[bagID] = {}
        local slotID
        for slotID = 1, inventorySlotCounts[bagID] or #slots do
            local item = slots[slotID]
            if item then
                local copy = {}
                local key, value
                for key, value in pairs(item) do
                    copy[key] = value
                end
                snapshot[bagID][slotID] = copy
            end
        end
    end
    return snapshot
end

local function GetAnchorX(widget, point)
    local left = widget:GetLeft()
    local right = widget:GetRight()
    if type(left) ~= "number" or type(right) ~= "number" then
        return
    end
    if string.find(point or "", "LEFT", 1, true) then
        return left
    elseif string.find(point or "", "RIGHT", 1, true) then
        return right
    end
    return (left + right) / 2
end

local function GetAnchorY(widget, point)
    local bottom = widget:GetBottom()
    local top = widget:GetTop()
    if type(bottom) ~= "number" or type(top) ~= "number" then
        return
    end
    if string.find(point or "", "BOTTOM", 1, true) then
        return bottom
    elseif string.find(point or "", "TOP", 1, true) then
        return top
    end
    return (bottom + top) / 2
end

local function ResolveRect(widget)
    local pointData = rawget(widget, "point")
    if not pointData or rawget(widget, "resolvingRect") then
        return
    end

    local point = pointData[1] or "CENTER"
    local relativeFrame = pointData[2] or widget.parent or UIParent
    local relativePoint = pointData[3] or point
    if not relativeFrame or relativeFrame == widget then
        return
    end

    widget.resolvingRect = true
    local targetX = GetAnchorX(relativeFrame, relativePoint)
    local targetY = GetAnchorY(relativeFrame, relativePoint)
    if type(targetX) ~= "number" or type(targetY) ~= "number" then
        widget.resolvingRect = nil
        return
    end
    local selfX
    local selfY
    if string.find(point, "LEFT", 1, true) then
        selfX = 0
    elseif string.find(point, "RIGHT", 1, true) then
        selfX = widget.width
    else
        selfX = widget.width / 2
    end
    if string.find(point, "BOTTOM", 1, true) then
        selfY = 0
    elseif string.find(point, "TOP", 1, true) then
        selfY = widget.height
    else
        selfY = widget.height / 2
    end

    widget.left = targetX + (pointData[4] or 0) - selfX
    widget.bottom = targetY + (pointData[5] or 0) - selfY
    widget.right = widget.left + widget.width
    widget.top = widget.bottom + widget.height
    widget.resolvingRect = nil
end

local function NewWidget(kind, name, parent)
    local widget = {
        kind = kind,
        name = name,
        parent = parent,
        width = 0,
        height = 0,
        shown = true,
        frameLevel = 1,
        scripts = {}
    }

    function widget:SetWidth(value)
        self.width = value
        if type(rawget(self, "left")) == "number" then
            self.right = self.left + value
        end
        if self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, self.width, self.height)
        end
    end

    function widget:SetHeight(value)
        self.height = value
        if type(rawget(self, "bottom")) == "number" then
            self.top = self.bottom + value
        end
        if self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, self.width, self.height)
        end
    end

    function widget:GetWidth()
        return self.width
    end

    function widget:GetHeight()
        return self.height
    end

    function widget:SetPoint(...)
        local point, relativeFrame, relativePoint, x, y = ...
        if type(relativeFrame) == "number" then
            self.point = {
                point,
                self.parent or UIParent,
                point,
                relativeFrame,
                relativePoint
            }
        elseif type(relativePoint) == "number" then
            self.point = {
                point,
                relativeFrame or self.parent or UIParent,
                point,
                relativePoint,
                x
            }
        else
            self.point = {
                point,
                relativeFrame or self.parent or UIParent,
                relativePoint or point,
                x or 0,
                y or 0
            }
        end
        ResolveRect(self)
    end

    function widget:GetPoint()
        if rawget(self, "point") then
            return unpack(self.point)
        end
        return "CENTER", UIParent, "CENTER", 0, 0
    end

    function widget:GetLeft()
        ResolveRect(self)
        return rawget(self, "left")
    end

    function widget:GetRight()
        ResolveRect(self)
        return rawget(self, "right")
    end

    function widget:GetBottom()
        ResolveRect(self)
        return rawget(self, "bottom")
    end

    function widget:GetTop()
        ResolveRect(self)
        return rawget(self, "top")
    end

    function widget:ClearAllPoints()
        self.point = nil
    end

    function widget:Show()
        self.shown = true
        if self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end

    function widget:Hide()
        self.shown = false
        if self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
    end

    function widget:IsShown()
        return self.shown
    end

    function widget:SetScript(event, callback)
        self.scripts[event] = callback
    end

    function widget:SetResizable(value)
        self.resizable = value
    end

    function widget:SetMinResize(width, height)
        self.minWidth = width
        self.minHeight = height
    end

    function widget:SetMaxResize(width, height)
        self.maxWidth = width
        self.maxHeight = height
    end

    function widget:StartSizing(point)
        self.sizingPoint = point
    end

    function widget:StartMoving()
        self.moving = true
    end

    function widget:StopMovingOrSizing()
        self.moving = false
        self.sizingPoint = nil
    end

    function widget:EnableMouseWheel(value)
        self.mouseWheelEnabled = value
    end

    function widget:SetScrollChild(child)
        self.scrollChild = child
    end

    function widget:GetVerticalScroll()
        return rawget(self, "verticalScroll") or 0
    end

    function widget:GetVerticalScrollRange()
        return rawget(self, "verticalScrollRange") or 0
    end

    function widget:SetVerticalScroll(value)
        self.verticalScroll = value
    end

    function widget:CreateTexture()
        return NewWidget("Texture", nil, self)
    end

    function widget:CreateFontString(_, _, fontObject)
        local fontString = NewWidget("FontString", nil, self)
        fontString.fontObject = fontObject
        fontString.fontPath = "Fonts\\FRIZQT__.TTF"
        fontString.fontSize = 12
        fontString.fontFlags = ""
        return fontString
    end

    function widget:SetText(value)
        self.text = value
    end

    function widget:SetFont(path, size, flags)
        self.fontPath = path
        self.fontSize = size
        self.fontFlags = flags
    end

    function widget:GetFont()
        return self.fontPath or "Fonts\\FRIZQT__.TTF",
            self.fontSize or 12,
            self.fontFlags or ""
    end

    function widget:GetStringWidth()
        return string.len(tostring(self.text or ""))
            * (self.fontSize or 12)
            * 0.5
    end

    function widget:SetJustifyH(value)
        self.justifyH = value
    end

    function widget:SetTextColor(...)
        self.textColor = { ... }
    end

    function widget:SetVertexColor(...)
        self.vertexColor = { ... }
    end

    function widget:SetDesaturated(value)
        self.desaturated = value
    end

    function widget:SetTexture(value)
        self.texture = value
    end

    function widget:SetNormalTexture(value)
        self.normalTexture = NewWidget("Texture", nil, self)
        self.normalTexture:SetTexture(value)
    end

    function widget:GetNormalTexture()
        return rawget(self, "normalTexture")
    end

    function widget:SetPushedTexture(value)
        self.pushedTexture = NewWidget("Texture", nil, self)
        self.pushedTexture:SetTexture(value)
    end

    function widget:GetPushedTexture()
        return rawget(self, "pushedTexture")
    end

    function widget:GetFontString()
        if not rawget(self, "fontString") then
            self.fontString = NewWidget("FontString", nil, self)
        end
        return self.fontString
    end

    function widget:GetHighlightTexture()
        if not rawget(self, "highlightTexture") then
            self.highlightTexture = NewWidget("Texture", nil, self)
        end
        return self.highlightTexture
    end

    function widget:LockHighlight()
        self.highlightLocked = true
    end

    function widget:UnlockHighlight()
        self.highlightLocked = false
    end

    function widget:SetFrameLevel(value)
        self.frameLevel = value
    end

    function widget:GetFrameLevel()
        return self.frameLevel
    end

    function widget:SetParent(value)
        self.parent = value
    end

    function widget:GetParent()
        return self.parent
    end

    function widget:SetID(value)
        self.id = value
    end

    setmetatable(widget, {
        __index = function()
            return function()
            end
        end
    })
    return widget
end

function CreateFrame(kind, name, parent)
    return NewWidget(kind, name, parent)
end

UIParent = NewWidget("Frame", "UIParent", nil)
UIParent.left = 0
UIParent.right = 1920
UIParent.bottom = 0
UIParent.top = 1080
UIParent.width = 1920
UIParent.height = 1080
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        table.insert(chatMessages, message)
    end
}
GameTooltip = NewWidget("Tooltip", "GameTooltip", UIParent)
function GameTooltip:SetInventoryItem(unit, inventorySlot)
    self.inventoryUnit = unit
    self.inventorySlot = inventorySlot
    return bagTextures[inventorySlot] ~= nil
end
function GameTooltip:SetOwner(owner, anchor)
    self.owner = owner
    self.anchor = anchor
end
function GameTooltip:IsOwned(owner)
    return self.owner == owner
end
function GameTooltip:SetText(value)
    self.text = value
    self.lines = {}
end
function GameTooltip:AddLine(value)
    table.insert(self.lines, value)
end
SlashCmdList = {}
StaticPopupDialogs = {}
UISpecialFrames = {}
YES = "YES"
NO = "NO"
EQUIP_CONTAINER = "Equip Container"
BACKPACK_CONTAINER = 0
BANK_CONTAINER = -1
NUM_BAG_SLOTS = 4
NUM_BANKBAGSLOTS = 7
NUM_BANKGENERIC_SLOTS = 28
TRADE_GOODS = "Trade Goods"

function GetScreenWidth()
    return 1920
end

function GetScreenHeight()
    return 1080
end

function IsShiftKeyDown()
    return shiftKeyDown
end

function UnitName()
    return "Sorter"
end

function GetRealmName()
    return "MockRealm"
end

function time()
    return mockTime
end

function InCombatLockdown()
    return combatLocked
end

function GetContainerNumFreeSlots(bagID)
    local slots = inventoryData[bagID]
    if not slots then
        return 10, bagTypes[bagID] or 0
    end
    local free = 0
    local index
    for index = 1, inventorySlotCounts[bagID] or #slots do
        if not slots[index] then
            free = free + 1
        end
    end
    return free, bagTypes[bagID] or 0
end

function GetContainerNumSlots(bagID)
    return inventorySlotCounts[bagID] or 0
end

function GetContainerItemInfo(bagID, slotID)
    local source = inventoryData
    if laggedContainerReads > 0 and laggedInventoryData then
        source = laggedInventoryData
        laggedContainerReads = laggedContainerReads - 1
    end
    local item = source[bagID] and source[bagID][slotID]
    if not item then
        return nil
    end
    local locked = item.locked and true or false
    if postMoveLocksRemaining > 0 then
        locked = true
        postMoveLocksRemaining = postMoveLocksRemaining - 1
    end
    return item.texture or ("Item" .. tostring(item.id)),
        item.count or 1,
        locked,
        item.quality,
        false,
        false,
        item.link
end

function GetItemInfo(itemLink)
    local itemID = tonumber(string.match(tostring(itemLink), "item:(%d+)"))
    local item = itemInfoByID[itemID]
    if not item then
        return nil
    end
    return item.name,
        item.link,
        item.quality,
        item.itemLevel or 1,
        item.minimumLevel or 1,
        item.itemType,
        item.subType or "",
        item.maxStack or 20,
        item.equipLocation or "",
        "Item" .. tostring(itemID),
        0
end

function UnitLevel()
    return 80
end

function ContainerIDToInventoryID(bagID)
    return 19 + bagID
end

function GetInventoryItemTexture(_, inventorySlot)
    return bagTextures[inventorySlot]
end

function IsInventoryItemLocked(inventorySlot)
    return inventorySlot == 21
end

function CursorHasItem()
    return cursorHasItem
end

function CursorCanGoInSlot(inventorySlot)
    return cursorTargetSlot == inventorySlot
end

function PutItemInBag(inventorySlot)
    putItemSlot = inventorySlot
end

function PickupBagFromSlot(inventorySlot)
    pickedUpBagSlot = inventorySlot
end

function PlaySound(sound)
    playedSound = sound
end

function PickupContainerItem(bagID, slotID)
    local slots = assert(inventoryData[bagID], "unknown mock bag")
    if not containerCursor then
        pickupSnapshot = SnapshotInventory()
        containerCursor = slots[slotID]
        slots[slotID] = nil
    else
        local displaced = slots[slotID]
        if displaced
            and containerCursor
            and displaced.id == containerCursor.id
            and (displaced.count or 1) < 20
        then
            local room = 20 - (displaced.count or 1)
            local moved = math.min(room, containerCursor.count or 1)
            displaced.count = (displaced.count or 1) + moved
            containerCursor.count = (containerCursor.count or 1) - moved
            slots[slotID] = displaced
            if containerCursor.count <= 0 then
                containerCursor = nil
            end
        else
            slots[slotID] = containerCursor
            containerCursor = displaced
        end
    end
    cursorHasItem = containerCursor ~= nil
    if not cursorHasItem and pickupSnapshot then
        laggedInventoryData = pickupSnapshot
        laggedContainerReads = laggedReadsAfterMove
        postMoveLocksRemaining = postMoveLockReads
        pickupSnapshot = nil
    end
end

bit = {
    band = function(left, right)
        local result = 0
        local place = 1
        while left > 0 or right > 0 do
            local leftBit = left % 2
            local rightBit = right % 2
            if leftBit == 1 and rightBit == 1 then
                result = result + place
            end
            left = math.floor(left / 2)
            right = math.floor(right / 2)
            place = place * 2
        end
        return result
    end
}

dofile(sourceDirectory .. "/RaidThreeBags.lua")
dofile(sourceDirectory .. "/RaidThreeUIStyle.lua")
dofile(sourceDirectory .. "/RTB_UI.lua")
dofile(sourceDirectory .. "/RTB_Bank.lua")

local RTB = assert(RaidThreeBags)
assert(type(RTB.ToggleSettings) == "function", "ToggleSettings missing")
assert(type(RTB.BuildSettingsUI) == "function", "BuildSettingsUI missing")
assert(type(RTB.CreateSettingsGear) == "function", "CreateSettingsGear missing")

RaidThreeBagsDB = {}
RTB:InitializeDB()

RTB.InventoryBagBar = NewWidget("Frame", "InventoryBagBar", UIParent)
RTB.InventoryBagSlotButtons = {}
local bagID
for bagID = NUM_BAG_SLOTS, 1, -1 do
    RTB:CreateInventoryBagSlot(bagID)
end
RTB:LayoutInventoryBagSlots()
RTB:UpdateInventoryBagSlots()

assert(
    #RTB.InventoryBagSlotButtons == 4,
    "inventory must expose four equipped bag slots"
)
local expectedVisualBagOrder = { 4, 3, 2, 1 }
local visualIndex, expectedBagID
for visualIndex, expectedBagID in ipairs(expectedVisualBagOrder) do
    local button = RTB.InventoryBagSlotButtons[visualIndex]
    assert(
        button.rtbBagID == expectedBagID,
        "equipped bag visual order must be 4, 3, 2, 1"
    )
    assert(
        button.rtbInventorySlot == 19 + expectedBagID,
        "container-to-inventory slot mapping mismatch"
    )
end
assert(
    RTB.InventoryBagSlotButtons[1].rtbIcon.texture == "BagFour",
    "equipped character bag icon missing"
)
assert(
    RTB.InventoryBagSlotButtons[2].rtbIcon.texture
        == "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag",
    "empty character bag placeholder missing"
)
assert(
    RTB.InventoryBagSlotButtons[3].rtbIcon.desaturated,
    "locked character bag is not desaturated"
)
assert(
    RTB.InventoryBagSlotButtons[4].point[4] == 102,
    "character bag slots are not laid out at 30 px plus 4 px spacing"
)

cursorHasItem = true
RTB.InventoryBagSlotButtons[3].scripts.OnClick(
    RTB.InventoryBagSlotButtons[3]
)
assert(putItemSlot == 21, "cursor item was not placed in character bag slot")
cursorHasItem = false
RTB.InventoryBagSlotButtons[2].scripts.OnDragStart(
    RTB.InventoryBagSlotButtons[2]
)
assert(pickedUpBagSlot == 22, "character bag drag did not pick up the bag")
assert(playedSound == "BAGMENUBUTTONPRESS", "character bag sound missing")

cursorTargetSlot = 23
bagTextures[23] = "ChangedCharacterBag"
RTB:UpdateInventoryBagSlots()
assert(
    RTB.InventoryBagSlotButtons[1].rtbIcon.texture == "ChangedCharacterBag",
    "character-specific equipped bag refresh failed"
)
assert(
    RTB.InventoryBagSlotButtons[1].rtbCursorHighlight:IsShown(),
    "valid character bag cursor target is not highlighted"
)
RTB.InventoryBagSlotButtons[1].scripts.OnEnter(
    RTB.InventoryBagSlotButtons[1]
)
assert(
    GameTooltip.inventorySlot == 23,
    "character bag tooltip uses the wrong inventory slot"
)

local function MockInventoryItem(
    itemID,
    name,
    quality,
    itemType,
    count,
    maxStack,
    subType,
    itemLevel,
    minimumLevel,
    equipLocation
)
    local link = "|cffaaaaaa|Hitem:"
        .. tostring(itemID)
        .. ":0:0:0:0:0:0:0|h["
        .. name
        .. "]|h|r"
    itemInfoByID[itemID] = {
        name = name,
        link = link,
        quality = quality,
        itemType = itemType,
        maxStack = maxStack or 20,
        subType = subType or "",
        itemLevel = itemLevel or 1,
        minimumLevel = minimumLevel or 1,
        equipLocation = equipLocation or ""
    }
    return {
        id = itemID,
        link = link,
        quality = quality,
        count = count or 1
    }
end

bagTypes[0] = 0
inventorySlotCounts[0] = 12
inventoryData[0] = {
    MockInventoryItem(220, "Alpha Misc", 4, "Miscellaneous"),
    MockInventoryItem(221, "Alpha Trade", 4, TRADE_GOODS),
    MockInventoryItem(222, "Boot Armor", 4, "Armor", 1, 1,
        "Plate", 200, 1, "INVTYPE_FEET"),
    MockInventoryItem(223, "Helm Armor", 1, "Armor", 1, 1,
        "Plate", 1, 1, "INVTYPE_HEAD"),
    MockInventoryItem(224, "Weapon", 1, "Weapon", 1, 1,
        "Sword", 1, 1, "INVTYPE_WEAPON"),
    MockInventoryItem(225, "A Unusable Potion", 4, "Consumable", 1, 1,
        "Potion", 300, 81),
    MockInventoryItem(226, "Z Usable Potion", 2, "Consumable", 1, 1,
        "Potion", 10, 1),
    MockInventoryItem(227, "A Better Potion", 3, "Consumable", 1, 1,
        "Potion", 5, 1),
    MockInventoryItem(228, "Z Better Potion", 3, "Consumable", 1, 1,
        "Potion", 20, 1),
    MockInventoryItem(229, "Elixir", 1, "Consumable", 1, 1,
        "Elixir", 1, 1),
    MockInventoryItem(230, "Quest", 1, "Quest"),
    nil
}
local hierarchyPools = assert(RTB:BuildInventorySortPlan(mockTime - 1))
local expectedHierarchy = {
    "230", "229", "228", "227", "226", "225",
    "224", "223", "222", "221", "220", false
}
local hierarchyIndex
for hierarchyIndex = 1, #expectedHierarchy do
    assert(
        hierarchyPools[1].desired[hierarchyIndex]
            == expectedHierarchy[hierarchyIndex],
        "smart hierarchy mismatch at slot " .. tostring(hierarchyIndex)
    )
end

bagTypes[0] = 0
inventorySlotCounts[0] = 12
inventoryData[0] = {
    MockInventoryItem(201, "Young Potion", 1, "Consumable"),
    MockInventoryItem(202, "Zebra Relic", 1, "Miscellaneous"),
    MockInventoryItem(203, "Zinc Ore", 1, TRADE_GOODS),
    MockInventoryItem(204, "Zesty Goo", 0, "Miscellaneous"),
    nil,
    MockInventoryItem(205, "Broken Cog", 0, "Miscellaneous"),
    MockInventoryItem(206, "Ancient Note", 1, "Miscellaneous"),
    MockInventoryItem(207, "Adamantite Ore", 1, TRADE_GOODS),
    MockInventoryItem(208, "Copper Thread", 1, TRADE_GOODS),
    MockInventoryItem(209, "Almost Old Charm", 1, "Miscellaneous"),
    nil,
    nil
}

RTB:UpdateItemAgeTracking(mockTime)
local ageStore = assert(RTB:GetCharacterItemAgeStore())
ageStore["202"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS - 10
ageStore["206"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS
ageStore["208"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS - 100
ageStore["209"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS + 1

local pools = assert(RTB:BuildInventorySortPlan(mockTime))
assert(#pools == 1, "general inventory must use one safe sorting pool")
assert(
    pools[1].requiredSeparators == 2,
    "three present groups must reserve two separators"
)
local expectedPlan = {
    "205",
    "204",
    false,
    "201",
    "207",
    "208",
    "203",
    "209",
    false,
    false,
    "206",
    "202"
}
local planIndex
for planIndex = 1, #expectedPlan do
    assert(
        pools[1].desired[planIndex] == expectedPlan[planIndex],
        "inventory sort plan mismatch at slot " .. tostring(planIndex)
    )
end

local sortButton = RTB:CreateInventorySortButton()
assert(sortButton.width == 30 and sortButton.height == 30,
    "inventory sort button must match the 30 px bag controls")
assert(
    sortButton.parent == RTB.InventoryBagBar
        and sortButton.point[1] == "RIGHT"
        and sortButton.point[2] == RTB.InventoryBagBar
        and sortButton.point[3] == "RIGHT"
        and sortButton.point[4] == 0
        and sortButton.point[5] == 0,
    "inventory sort button is not aligned at the right edge"
)
assert(
    RTB.InventorySortFrame == nil
        and RTB.InventorySortCaption == nil
        and RTB.InventorySortSeparator == nil,
    "obsolete settings mini-panel returned"
)
assert(sortButton.rtbLabel.text == "A-Z",
    "inventory sort button label mismatch")
sortButton.scripts.OnEnter(sortButton)
assert(
    string.find(GameTooltip.lines[1], "Three smart groups", 1, true)
        and string.find(GameTooltip.lines[1], "current/keep", 1, true)
        and string.find(GameTooltip.lines[1], "old/review", 1, true),
    "inventory sort tooltip does not explain the three semantic groups"
)
assert(
    string.find(GameTooltip.lines[2], "category, subtype", 1, true)
        and string.find(GameTooltip.lines[3], "Extra empty", 1, true)
        and string.find(GameTooltip.lines[4], "consolidate", 1, true),
    "inventory sort tooltip does not explain separators and consolidation"
)
sortButton.scripts.OnClick()
assert(RTB.SortSession, "inventory sorting did not start asynchronously")

local function RunInventorySort()
    local guard = 0
    while RTB.SortSession and guard < 400 do
        guard = guard + 1
        RTB.InventorySortDriver.scripts.OnUpdate(
            RTB.InventorySortDriver,
            0.10
        )
    end
    assert(not RTB.SortSession, "inventory sorting did not finish")
end

RunInventorySort()

local expectedSortedIDs = {
    205,
    204,
    nil,
    201,
    207,
    208,
    203,
    209,
    nil,
    nil,
    206,
    202
}
for planIndex = 1, 12 do
    local item = inventoryData[0][planIndex]
    local actualID = item and item.id or nil
    assert(
        actualID == expectedSortedIDs[planIndex],
        "inventory move result mismatch at slot "
            .. tostring(planIndex)
            .. ": expected "
            .. tostring(expectedSortedIDs[planIndex])
            .. ", got "
            .. tostring(actualID)
            .. ", last message "
            .. tostring(chatMessages[#chatMessages])
    )
end
assert(
    ageStore["202"].firstSeen
        == mockTime - RTB.ITEM_AGE_SECONDS - 10,
    "sorting reset the continuously-held item age"
)
assert(not cursorHasItem, "inventory sorting left an item on the cursor")
assert(
    string.find(chatMessages[#chatMessages], "Inventory arranged", 1, true),
    "inventory sorting did not report completion"
)

local sortTraceStore = assert(RTB:GetInventorySortTraceStore())
local completedTrace = assert(sortTraceStore.sessions[#sortTraceStore.sessions])
assert(
    sortTraceStore.enabled
        and completedTrace.schema == RTB.SORT_TRACE_SCHEMA
        and completedTrace.status == "PASS"
        and completedTrace.finishedAt
        and completedTrace.initialPlan
        and completedTrace.finalPlan
        and completedTrace.before
        and completedTrace.after,
    "successful sort trace was not persisted with complete lifecycle data"
)
assert(
    completedTrace.initialPlan.items["205"].group == "trash"
        and completedTrace.initialPlan.items["207"].group == "current"
        and completedTrace.initialPlan.items["202"].group == "old"
        and completedTrace.initialPlan.items["202"].ageSeconds
            >= RTB.ITEM_AGE_SECONDS,
    "sort trace did not persist classification reasons and item age"
)
assert(
    #completedTrace.events > 0
        and completedTrace.events[1].kind == "arrange"
        and completedTrace.events[1].result == "CONFIRMED"
        and completedTrace.events[1].source
        and completedTrace.events[1].target,
    "sort trace did not persist confirmed move details"
)
local completedVerdict = completedTrace.verdict
assert(
    completedVerdict.countsConserved
        and completedVerdict.poolIsolation
        and completedVerdict.planMatches
        and completedVerdict.groupOrder
        and completedVerdict.hierarchical
        and completedVerdict.separators
        and completedVerdict.oldAtBottom
        and completedVerdict.cursorEmpty
        and completedVerdict.topologyStable
        and completedVerdict.completeSnapshots
        and completedVerdict.snapshotCounts,
    "successful sort trace invariant verdict was incomplete"
)
local originalTrashCount = completedTrace.after.counts["205"]
completedTrace.after.counts["205"] = originalTrashCount + 1
local badCountVerdict, badCountPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not badCountPassed and not badCountVerdict.countsConserved,
    "sort trace verifier accepted changed item totals"
)
completedTrace.after.counts["205"] = originalTrashCount
local originalFirstKey = completedTrace.after.slots[1].itemKey
completedTrace.after.slots[1].itemKey = "unexpected"
local badPlanVerdict, badPlanPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not badPlanPassed and not badPlanVerdict.planMatches,
    "sort trace verifier accepted a final slot outside the plan"
)
completedTrace.after.slots[1].itemKey = originalFirstKey
local omittedEmptySlot = table.remove(completedTrace.after.slots, 3)
local missingSlotVerdict, missingSlotPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not missingSlotPassed
        and not missingSlotVerdict.planMatches
        and not missingSlotVerdict.completeSnapshots,
    "sort trace verifier accepted an omitted planned empty slot"
)
table.insert(completedTrace.after.slots, 3, omittedEmptySlot)
local oldBottomSlots = completedTrace.after.slots
local finalDesired = completedTrace.finalPlan.pools[1].desired
local savedSlot10Key = oldBottomSlots[10].itemKey
local savedSlot10Count = oldBottomSlots[10].count
local savedSlot11Key = oldBottomSlots[11].itemKey
local savedSlot11Count = oldBottomSlots[11].count
local savedSlot12Key = oldBottomSlots[12].itemKey
local savedSlot12Count = oldBottomSlots[12].count
local savedDesired10 = finalDesired[10]
local savedDesired11 = finalDesired[11]
local savedDesired12 = finalDesired[12]
oldBottomSlots[10].itemKey = savedSlot11Key
oldBottomSlots[10].count = savedSlot11Count
oldBottomSlots[11].itemKey = savedSlot12Key
oldBottomSlots[11].count = savedSlot12Count
oldBottomSlots[12].itemKey = false
oldBottomSlots[12].count = 0
finalDesired[10] = savedDesired11
finalDesired[11] = savedDesired12
finalDesired[12] = false
local trailingEmptyVerdict, trailingEmptyPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not trailingEmptyPassed
        and trailingEmptyVerdict.planMatches
        and trailingEmptyVerdict.hierarchical
        and not trailingEmptyVerdict.oldAtBottom,
    "sort trace verifier accepted empty space below old/review"
)
oldBottomSlots[10].itemKey = savedSlot10Key
oldBottomSlots[10].count = savedSlot10Count
oldBottomSlots[11].itemKey = savedSlot11Key
oldBottomSlots[11].count = savedSlot11Count
oldBottomSlots[12].itemKey = savedSlot12Key
oldBottomSlots[12].count = savedSlot12Count
finalDesired[10] = savedDesired10
finalDesired[11] = savedDesired11
finalDesired[12] = savedDesired12
local tracePlanSlots = completedTrace.finalPlan.pools[1].slots
local savedPlanBag2 = tracePlanSlots[2].bagID
local savedPlanSlot2 = tracePlanSlots[2].slotID
local savedDuplicateDesired2 = finalDesired[2]
tracePlanSlots[2].bagID = tracePlanSlots[1].bagID
tracePlanSlots[2].slotID = tracePlanSlots[1].slotID
finalDesired[2] = finalDesired[1]
local duplicatePlanVerdict, duplicatePlanPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not duplicatePlanPassed
        and not duplicatePlanVerdict.planMatches
        and not duplicatePlanVerdict.completeSnapshots,
    "sort trace verifier accepted duplicate planned slot coordinates"
)
tracePlanSlots[2].bagID = savedPlanBag2
tracePlanSlots[2].slotID = savedPlanSlot2
finalDesired[2] = savedDuplicateDesired2
finalDesired[#tracePlanSlots + 1] = false
local extraDesiredVerdict, extraDesiredPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not extraDesiredPassed
        and not extraDesiredVerdict.planMatches
        and not extraDesiredVerdict.completeSnapshots,
    "sort trace verifier accepted surplus desired plan entries"
)
finalDesired[#tracePlanSlots + 1] = nil
finalDesired.forged = "forged-extra"
local keyedDesiredVerdict, keyedDesiredPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not keyedDesiredPassed
        and not keyedDesiredVerdict.planMatches
        and not keyedDesiredVerdict.completeSnapshots,
    "sort trace verifier accepted keyed desired plan entries"
)
finalDesired.forged = nil
local savedOccupiedCount = completedTrace.after.slots[1].count
completedTrace.after.slots[1].count = 0
local zeroCountVerdict, zeroCountPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not zeroCountPassed and not zeroCountVerdict.snapshotCounts,
    "sort trace verifier normalized an invalid occupied count"
)
completedTrace.after.slots[1].count = savedOccupiedCount
local savedBeforePools = {}
local savedAfterPools = {}
local traceSlotIndex
for traceSlotIndex = 1, #completedTrace.before.slots do
    savedBeforePools[traceSlotIndex] =
        completedTrace.before.slots[traceSlotIndex].pool
    completedTrace.before.slots[traceSlotIndex].pool = "fake"
end
for traceSlotIndex = 1, #completedTrace.after.slots do
    savedAfterPools[traceSlotIndex] =
        completedTrace.after.slots[traceSlotIndex].pool
    completedTrace.after.slots[traceSlotIndex].pool = "fake"
end
local savedBeforePoolCounts = completedTrace.before.poolCounts
local savedAfterPoolCounts = completedTrace.after.poolCounts
completedTrace.before.poolCounts = { fake = completedTrace.before.counts }
completedTrace.after.poolCounts = { fake = completedTrace.after.counts }
local fakePoolVerdict, fakePoolPassed =
    RTB:VerifyInventorySortTrace(completedTrace)
assert(
    not fakePoolPassed
        and not fakePoolVerdict.poolIsolation
        and fakePoolVerdict.snapshotCounts,
    "sort trace verifier trusted forged snapshot pool labels"
)
for traceSlotIndex = 1, #completedTrace.before.slots do
    completedTrace.before.slots[traceSlotIndex].pool =
        savedBeforePools[traceSlotIndex]
end
for traceSlotIndex = 1, #completedTrace.after.slots do
    completedTrace.after.slots[traceSlotIndex].pool =
        savedAfterPools[traceSlotIndex]
end
completedTrace.before.poolCounts = savedBeforePoolCounts
completedTrace.after.poolCounts = savedAfterPoolCounts
RTB:InitializeDB()
assert(
    RTB:GetInventorySortTraceStore().sessions[#sortTraceStore.sessions]
        == completedTrace,
    "sort trace did not survive SavedVariables DB reinitialization"
)

inventorySlotCounts[0] = 2
inventoryData[0] = {
    MockInventoryItem(402, "Zulu Token", 1, "Miscellaneous"),
    MockInventoryItem(401, "Alpha Token", 1, "Miscellaneous")
}
inventorySlotCounts[1] = 0
inventoryData[1] = {}
laggedReadsAfterMove = 1
postMoveLockReads = 4
assert(
    RTB:SortInventory(),
    "sort with split stale reads and post-move locks did not start"
)
RunInventorySort()
assert(
    inventoryData[0][1].id == 401
        and inventoryData[0][2].id == 402
        and string.find(chatMessages[#chatMessages], "Inventory arranged", 1, true),
    "split stale reads or post-move locks aborted a valid move"
)
laggedReadsAfterMove = 2
postMoveLockReads = 0
postMoveLocksRemaining = 0

local linklessAge = ageStore["402"] and ageStore["402"].firstSeen
inventoryData[0][2].link = nil
assert(
    not RTB:UpdateItemAgeTracking(mockTime + 1)
        and ageStore["402"]
        and ageStore["402"].firstSeen == linklessAge,
    "occupied linkless slot pruned or reset item age"
)
local linklessPlan, linklessReason = RTB:BuildInventorySortPlan(mockTime + 1)
assert(
    linklessPlan == nil
        and string.find(linklessReason, "still loading", 1, true),
    "occupied linkless slot was treated as empty"
)
inventoryData[0][2].link = itemInfoByID[402].link

local topologyFirstID = inventoryData[0][1].id
local topologySecondID = inventoryData[0][2].id
assert(RTB:SortInventory(), "topology guard test did not start")
bagTypes[1] = 8
RunInventorySort()
assert(
    inventoryData[0][1].id == topologyFirstID
        and inventoryData[0][2].id == topologySecondID
        and string.find(chatMessages[#chatMessages], "Bag layout changed", 1, true),
    "bag topology changed without stopping before a physical move"
)
bagTypes[1] = 4

local function InventoryFingerprint()
    local parts = {}
    local fingerprintBagID
    for fingerprintBagID = 0, 4 do
        local slotID
        for slotID = 1, inventorySlotCounts[fingerprintBagID] or 0 do
            local item = inventoryData[fingerprintBagID]
                and inventoryData[fingerprintBagID][slotID]
            table.insert(
                parts,
                tostring(fingerprintBagID)
                    .. ":"
                    .. tostring(slotID)
                    .. "="
                    .. tostring(item and item.id or "empty")
                    .. ":"
                    .. tostring(item and item.count or 0)
            )
        end
    end
    return table.concat(parts, "|")
end

inventorySlotCounts[0] = 3
inventoryData[0] = {
    MockInventoryItem(301, "Broken Gear", 0, "Miscellaneous", 1, 1),
    MockInventoryItem(302, "Current Tonic", 1, "Consumable", 1, 1),
    MockInventoryItem(303, "Old Relic", 1, "Miscellaneous", 1, 1)
}
inventorySlotCounts[1] = 0
inventoryData[1] = {}
RTB:UpdateItemAgeTracking(mockTime)
ageStore["303"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS
local blockedFingerprint = InventoryFingerprint()
local blockedPlan, blockedReason = RTB:BuildInventorySortPlan(mockTime)
assert(
    blockedPlan == nil
        and string.find(blockedReason, "stack capacity", 1, true),
    "insufficient separator capacity was not rejected"
)
assert(
    not RTB:SortInventory()
        and InventoryFingerprint() == blockedFingerprint,
    "insufficient capacity changed inventory before refusal"
)
local blockedTrace = sortTraceStore.sessions[#sortTraceStore.sessions]
assert(
    blockedTrace.status == "ABORTED"
        and string.find(blockedTrace.reason, "stack capacity", 1, true),
    "preflight refusal was not persisted as an aborted sort trace"
)

inventorySlotCounts[0] = 6
inventoryData[0] = {
    MockInventoryItem(312, "Copper Thread", 1, TRADE_GOODS, 5),
    MockInventoryItem(314, "Ancient Relic", 1, "Miscellaneous", 6),
    MockInventoryItem(311, "Broken Gear", 0, "Miscellaneous", 1, 1),
    MockInventoryItem(313, "Young Tonic", 1, "Consumable", 1, 1),
    MockInventoryItem(314, "Ancient Relic", 1, "Miscellaneous", 6),
    MockInventoryItem(312, "Copper Thread", 1, TRADE_GOODS, 5)
}
RTB:UpdateItemAgeTracking(mockTime)
ageStore["314"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS - 1
local consolidationPlan = assert(RTB:BuildInventorySortPlan(mockTime))
assert(
    consolidationPlan[1].requiredSeparators == 2
        and consolidationPlan[1].freeableSlots == 2
        and consolidationPlan[1].needsConsolidation,
    "partial-stack simulation did not prove two freeable slots"
)
assert(RTB:SortInventory(), "safe partial-stack consolidation did not start")
local oneClickSession = RTB.SortSession
assert(
    oneClickSession and oneClickSession.phase == "consolidate",
    "sort session did not enter pre-sort consolidation"
)
RunInventorySort()
assert(not cursorHasItem, "consolidation left an item on the cursor")
assert(
    inventoryData[0][1].id == 311
        and inventoryData[0][2] == nil
        and inventoryData[0][3].id == 313
        and inventoryData[0][4].id == 312
        and inventoryData[0][4].count == 10
        and inventoryData[0][5] == nil
        and inventoryData[0][6].id == 314
        and inventoryData[0][6].count == 12,
    "one-session consolidation and three-group arrangement failed: "
        .. InventoryFingerprint()
)
assert(
    string.find(chatMessages[#chatMessages], "Inventory arranged", 1, true),
    "partial-stack consolidation required a second sort session"
)

inventorySlotCounts[0] = 3
inventoryData[0] = {
    MockInventoryItem(321, "Broken Part", 0, "Miscellaneous", 1, 1),
    MockInventoryItem(322, "Shared Dust", 1, TRADE_GOODS, 5),
    MockInventoryItem(323, "Old Token", 1, "Miscellaneous", 1, 1)
}
inventorySlotCounts[1] = 2
inventoryData[1] = {
    MockInventoryItem(322, "Shared Dust", 1, TRADE_GOODS, 5),
    MockInventoryItem(322, "Shared Dust", 1, TRADE_GOODS, 5)
}
RTB:UpdateItemAgeTracking(mockTime)
ageStore["323"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS
local familyFingerprint = InventoryFingerprint()
assert(
    not RTB:SortInventory()
        and InventoryFingerprint() == familyFingerprint
        and inventoryData[0][2].count == 5
        and inventoryData[1][1].count == 5
        and inventoryData[1][2].count == 5,
    "same item key crossed compatible bag-family movement pools"
)

inventorySlotCounts[0] = 4
inventoryData[0] = {
    [3] = MockInventoryItem(331, "Young Item", 1, "Miscellaneous")
}
inventorySlotCounts[1] = 2
inventoryData[1] = {
    MockInventoryItem(332, "Zesty Shard", 1, TRADE_GOODS),
    MockInventoryItem(333, "Azure Shard", 1, TRADE_GOODS)
}
local familyPools = assert(RTB:BuildInventorySortPlan(mockTime))
assert(#familyPools == 2, "specialty bag family was not isolated")
assert(
    familyPools[1].desired[1] == "331"
        and familyPools[1].desired[2] == false
        and familyPools[1].desired[3] == false
        and familyPools[1].desired[4] == false,
    "surplus empties did not follow current/keep when old/review was absent"
)
assert(RTB:SortInventory(), "specialty bag sort failed")
RunInventorySort()
assert(
    inventoryData[0][1].id == 331
        and inventoryData[0][2] == nil
        and inventoryData[0][3] == nil
        and inventoryData[0][4] == nil
        and inventoryData[1][1].id == 333
        and inventoryData[1][2].id == 332,
    "specialty bag sort crossed or misordered its family pool"
)

inventoryData[1][1].locked = true
local lockedPlan, lockedReason = RTB:BuildInventorySortPlan(mockTime)
assert(
    lockedPlan == nil
        and string.find(lockedReason, "locked", 1, true),
    "locked inventory item did not block sorting"
)
inventoryData[1][1].locked = false

local cachedInfo = itemInfoByID[333]
itemInfoByID[333] = nil
local uncachedPlan, uncachedReason = RTB:BuildInventorySortPlan(mockTime)
assert(
    uncachedPlan == nil
        and string.find(uncachedReason, "still loading", 1, true),
    "uncached item information did not block sorting"
)
itemInfoByID[333] = cachedInfo

cursorHasItem = true
assert(not RTB:SortInventory(), "held cursor item did not block sorting")
cursorHasItem = false
combatLocked = true
assert(not RTB:SortInventory(), "combat did not block sorting")
combatLocked = false

inventorySlotCounts[0] = 2
inventoryData[0] = {
    MockInventoryItem(402, "Zulu Token", 1, "Miscellaneous"),
    MockInventoryItem(401, "Alpha Token", 1, "Miscellaneous")
}
inventorySlotCounts[1] = 0
inventoryData[1] = {}
local originalPickupContainerItem = PickupContainerItem
PickupContainerItem = function()
end
assert(RTB:SortInventory(), "failed native pickup trace did not start")
RunInventorySort()
PickupContainerItem = originalPickupContainerItem
local failedPickupTrace = sortTraceStore.sessions[#sortTraceStore.sessions]
assert(
    failedPickupTrace.status == "ABORTED"
        and #failedPickupTrace.events == 1
        and failedPickupTrace.events[1].result == "FAILED"
        and failedPickupTrace.events[1].source
        and failedPickupTrace.events[1].target,
    "failed native pickup was omitted from the sort trace"
)

SlashCmdList.RAIDTHREEBAGS("sortlog status")
assert(
    string.find(chatMessages[#chatMessages], "Sort log ON", 1, true),
    "sortlog status did not report enabled persistent logging"
)
SlashCmdList.RAIDTHREEBAGS("sortlog last")
assert(
    string.find(chatMessages[#chatMessages], "Sort log reason", 1, true),
    "sortlog last did not report the last aborted reason"
)
SlashCmdList.RAIDTHREEBAGS("sortlog off")
local disabledSessionCount = #sortTraceStore.sessions
assert(RTB:SortInventory(), "sort did not start with logging disabled")
RunInventorySort()
assert(
    #sortTraceStore.sessions == disabledSessionCount,
    "disabled sort logging persisted a new session"
)
SlashCmdList.RAIDTHREEBAGS("sortlog on")
local stressIndex
for stressIndex = 1, RTB.SORT_TRACE_MAX_SESSIONS + 1 do
    assert(RTB:SortInventory(), "bounded sort trace test did not start")
    RunInventorySort()
end
assert(
    #sortTraceStore.sessions == RTB.SORT_TRACE_MAX_SESSIONS
        and sortTraceStore.sessions[1].id
            == sortTraceStore.nextSessionID - RTB.SORT_TRACE_MAX_SESSIONS
        and sortTraceStore.sessions[#sortTraceStore.sessions].id
            == sortTraceStore.nextSessionID - 1,
    "sort trace ring did not retain exactly the latest ten sessions"
)
SlashCmdList.RAIDTHREEBAGS("sortlog last")
assert(
    string.find(chatMessages[#chatMessages], "Sort log #", 1, true)
        and string.find(chatMessages[#chatMessages], "PASS", 1, true),
    "sortlog last did not print the latest successful verdict"
)
SlashCmdList.RAIDTHREEBAGS("sortlog clear")
assert(
    #sortTraceStore.sessions == 0
        and string.find(chatMessages[#chatMessages], "cleared", 1, true),
    "sortlog clear did not remove retained sessions"
)
sortTraceStore.sessions = {
    "invalid",
    { status = "PASS" },
    { id = 41, status = "RUNNING", verdict = 42, events = "invalid" },
    { id = 42, status = "PASS" }
}
sortTraceStore.nextSessionID = 1
sortTraceStore.enabled = "invalid"
RTB:InitializeDB()
local sanitizedTraceStore = RTB:GetInventorySortTraceStore()
assert(
    sanitizedTraceStore.enabled
        and #sanitizedTraceStore.sessions == 2
        and sanitizedTraceStore.sessions[1].id == 41
        and sanitizedTraceStore.sessions[1].status == "ABORTED"
        and type(sanitizedTraceStore.sessions[1].events) == "table"
        and sanitizedTraceStore.sessions[1].verdict == nil
        and sanitizedTraceStore.sessions[2].id == 42
        and sanitizedTraceStore.nextSessionID == 43,
    "legacy or corrupted sort trace store was not sanitized"
)
sanitizedTraceStore.sessions = {}
sanitizedTraceStore.nextSessionID = "1.5"
assert(
    RTB:GetInventorySortTraceStore().nextSessionID == 1,
    "fractional sort trace session ID was not normalized"
)
sanitizedTraceStore.nextSessionID = math.huge
assert(
    RTB:GetInventorySortTraceStore().nextSessionID == 1,
    "non-finite sort trace session ID was not rejected"
)
sanitizedTraceStore.sessions = {
    [100] = { id = 50, status = "PASS" },
    junk = { id = 51, status = "PASS" }
}
sanitizedTraceStore.nextSessionID = 1
local denseTraceStore = RTB:GetInventorySortTraceStore()
assert(
    #denseTraceStore.sessions == 1
        and denseTraceStore.sessions[1].id == 50
        and denseTraceStore.nextSessionID == 51,
    "sparse or keyed sort trace entries were not rebuilt densely"
)
denseTraceStore.sessions = {}
denseTraceStore.nextSessionID = 100000000000000000000
local largeIDTraceOne = assert(RTB:BeginInventorySortTrace())
local largeIDTraceTwo = assert(RTB:BeginInventorySortTrace())
assert(
    largeIDTraceOne.id == 1
        and largeIDTraceTwo.id == 2
        and largeIDTraceOne.id ~= largeIDTraceTwo.id,
    "oversized sort trace IDs were not safely rebased"
)
denseTraceStore.sessions = {}

local brandingWindow = NewWidget("Frame", "BrandingWindow", UIParent)
brandingWindow:SetWidth(480)
brandingWindow:SetHeight(500)
brandingWindow.left = 0
brandingWindow.right = 480
brandingWindow.bottom = 0
brandingWindow.top = 500
local brandLeftBoundary = NewWidget(
    "FontString",
    "BrandLeftBoundary",
    brandingWindow
)
brandLeftBoundary.left = 24
brandLeftBoundary.right = 145
local brandRightBoundary = NewWidget(
    "FontString",
    "BrandRightBoundary",
    brandingWindow
)
brandRightBoundary.left = 335
brandRightBoundary.right = 450
local footerBrand = RTB:CreateFooterBrand(
    brandingWindow,
    brandLeftBoundary,
    brandRightBoundary
)
assert(
    footerBrand.point[1] == "BOTTOM"
        and footerBrand.point[2] == brandingWindow
        and footerBrand.point[3] == "BOTTOM"
        and footerBrand.point[4] == 0
        and footerBrand.point[5] == 8,
    "footer brand is not centered in the 48 px lower strip"
)
assert(footerBrand.width == 220, "footer brand default width mismatch")
assert(footerBrand.height == 32, "footer brand height mismatch")
assert(
    footerBrand.rtbCredit.point[1] == "BOTTOM"
        and footerBrand.rtbCredit.point[2] == footerBrand
        and footerBrand.rtbCredit.point[3] == "CENTER"
        and footerBrand.rtbCredit.point[5] == 1,
    "footer brand credit is not vertically centered"
)
assert(
    footerBrand.rtbEdition.point[1] == "TOP"
        and footerBrand.rtbEdition.point[2] == footerBrand
        and footerBrand.rtbEdition.point[3] == "CENTER"
        and footerBrand.rtbEdition.point[5] == -1,
    "footer brand edition is not vertically centered"
)
assert(
    footerBrand.rtbCredit.text == "Made by S4B4T0N",
    "footer brand credit text mismatch"
)
assert(
    footerBrand.rtbEdition.text == "WotLK 3.3.5a",
    "footer brand edition text mismatch"
)
assert(
    footerBrand.rtbCredit.textColor[1] == 0.72
        and footerBrand.rtbCredit.textColor[2] == 0.76
        and footerBrand.rtbCredit.textColor[3] == 0.82,
    "footer brand credit color mismatch"
)
assert(
    footerBrand.rtbEdition.textColor[1] == 0.55
        and footerBrand.rtbEdition.textColor[2] == 0.75
        and footerBrand.rtbEdition.textColor[3] == 1,
    "footer brand edition color mismatch"
)
assert(
    footerBrand.rtbCredit.fontSize == 12
        and footerBrand.rtbEdition.fontSize == 12,
    "footer brand must keep the RaidRollHelper font size at 480 px"
)
assert(footerBrand:IsShown(), "non-colliding footer brand must be visible")
assert(
    not footerBrand.rtbCollisionHidden,
    "visible footer brand retained its collision state"
)

brandingWindow:SetWidth(320)
brandLeftBoundary.right = 80
brandRightBoundary.left = 240
RTB:LayoutFooterBrand(footerBrand)
assert(
    footerBrand.rtbCredit.fontSize == 8
        and footerBrand.rtbEdition.fontSize == 8,
    "footer brand font did not shrink with the window"
)
assert(
    footerBrand:IsShown(),
    "shrunk footer brand disappeared without a collision"
)

brandLeftBoundary.right = 123
RTB:LayoutFooterBrand(footerBrand)
assert(
    not footerBrand:IsShown() and footerBrand.rtbCollisionHidden,
    "left footer collision did not hide the complete brand"
)

brandLeftBoundary.right = 80
brandRightBoundary.left = 198
RTB:LayoutFooterBrand(footerBrand)
assert(
    not footerBrand:IsShown() and footerBrand.rtbCollisionHidden,
    "right footer collision did not hide the complete brand"
)

brandingWindow:SetWidth(900)
brandLeftBoundary.right = 145
brandRightBoundary.left = 835
RTB:LayoutFooterBrand(footerBrand)
assert(
    footerBrand.rtbCredit.fontSize == 12
        and footerBrand.rtbEdition.fontSize == 12,
    "footer brand font must not grow beyond the RaidRollHelper size"
)
assert(
    footerBrand:IsShown() and not footerBrand.rtbCollisionHidden,
    "footer brand did not return after the collision cleared"
)

local inventory = NewWidget("Frame", "Inventory", UIParent)
inventory.width = 777
inventory.height = 666
inventory.right = 800
local bank = NewWidget("Frame", "Bank", UIParent)
bank.width = 888
bank.height = 700
bank.shown = false

RTB.MainFrame = inventory
RTB.PlayerBankFrame = bank
RTB.DB.window.width = 777
RTB.DB.window.height = 666
RTB.DB.bankWindow.width = 888
RTB.DB.bankWindow.height = 700

RTB:ToggleSettings(inventory)
assert(RTB.SettingsFrame:IsShown(), "settings window did not open")
assert(#RTB.SpecialBagRows == 10, "special-bag table must have ten rows")
assert(RTB.ResetInventoryButton, "inventory reset button missing")
assert(RTB.ResetBankButton, "bank reset button missing")
assert(RTB.WindowLockButton, "corner-lock button missing")
assert(RTB.WindowLockButton.text == "ON", "corner lock must default to ON")
assert(RTB.SettingsStateHeader.text == "VISIBLE", "visible column header missing")
assert(RTB.SettingsFrame.resizable, "settings window is not resizable")
assert(RTB.SettingsFrame.minWidth == 500, "settings minimum width mismatch")
assert(RTB.SettingsFrame.minHeight == 336, "settings minimum height mismatch")
assert(RTB.SettingsFrame.maxWidth == 900, "settings maximum width mismatch")
assert(RTB.SettingsFrame.maxHeight == 760, "settings maximum height mismatch")
assert(RTB.SettingsResizeGrip, "settings resize grip missing")
assert(RTB.SettingsTableScroll, "settings table scroll frame missing")
assert(RTB.SettingsTableContent, "settings table scroll child missing")
assert(
    RTB.SettingsTableScroll.scrollChild == RTB.SettingsTableContent,
    "settings table scroll child is not connected"
)
assert(
    RTB.SettingsTableContent.width == 430,
    "default settings table width mismatch"
)
assert(
    RTB.SettingsTableContent.height == 260,
    "settings table height mismatch"
)

RTB.SettingsFrame:SetWidth(500)
RTB.SettingsFrame:SetHeight(336)
assert(
    RTB.SettingsTableContent.width == 410,
    "minimum-width settings layout did not reflow"
)
RTB.SettingsFrame:SetWidth(700)
assert(
    RTB.SettingsTableContent.width == 610,
    "expanded settings layout did not reflow"
)
RTB.SettingsFrame:SetWidth(520)
RTB.SettingsFrame:SetHeight(550)

RTB.SettingsTableScroll.verticalScrollRange = 200
RTB.SettingsTableScroll.scripts.OnMouseWheel(
    RTB.SettingsTableScroll,
    -1
)
assert(
    RTB.SettingsTableScroll.verticalScroll == 78,
    "settings table mouse-wheel scrolling failed"
)

RTB.SettingsResizeGrip.scripts.OnMouseDown(
    RTB.SettingsResizeGrip,
    "LeftButton"
)
assert(
    RTB.SettingsFrame.sizingPoint == "BOTTOMRIGHT",
    "settings resize grip did not start sizing"
)
RTB.SettingsResizeGrip.scripts.OnMouseUp(RTB.SettingsResizeGrip)
assert(
    rawget(RTB.SettingsFrame, "sizingPoint") == nil,
    "settings resize grip did not stop sizing"
)

RTB.SettingsFrame.rtbHeader.scripts.OnDragStart()
assert(RTB.SettingsFrame.moving, "settings header did not start moving")
RTB.SettingsFrame.rtbHeader.scripts.OnDragStop()
assert(
    not RTB.SettingsFrame.moving,
    "settings header did not stop moving"
)

RTB.ResetInventoryButton.scripts.OnClick()
assert(RTB.DB.window.width == RTB.DEFAULT_WIDTH, "inventory width reset failed")
assert(RTB.DB.window.height == RTB.DEFAULT_HEIGHT, "inventory height reset failed")

RTB.ResetBankButton.scripts.OnClick()
assert(
    RTB.DB.bankWindow.width == RTB.BANK_DEFAULT_WIDTH,
    "bank width reset failed"
)
assert(
    RTB.DB.bankWindow.height == RTB.BANK_DEFAULT_HEIGHT,
    "bank height reset failed"
)

local soulRow = RTB.SpecialBagRows[3]
assert(soulRow.definition.family == 4, "soul-bag row missing")
assert(soulRow.toggle.text == "ON", "visible special bag must show ON")
soulRow.toggle.scripts.OnClick()
assert(RTB:GetSpecialBagInvisible(4), "soul-bag invisibility did not enable")
assert(soulRow.toggle.text == "OFF", "hidden special bag must show OFF")
assert(
    soulRow.toggle.fontString.textColor[1] == 1,
    "red OFF color missing"
)
assert(
    not RTB:IsInventoryBagVisible(1),
    "enabled soul-bag slots remain visible"
)

soulRow.toggle.scripts.OnClick()
assert(
    not RTB:GetSpecialBagInvisible(4),
    "soul-bag invisibility did not disable"
)
assert(soulRow.toggle.text == "ON", "visible special bag must show ON")
assert(
    soulRow.toggle.fontString.textColor[2] == 1,
    "green ON color missing"
)

local index, row
for index, row in ipairs(RTB.SpecialBagRows) do
    assert(
        row.parent == RTB.SettingsTableContent,
        "special-bag row is outside the scroll child"
    )
    assert(
        row.definition.family == RTB.SPECIAL_BAG_TYPES[index].family,
        "special-bag row order mismatch"
    )
    row.toggle.scripts.OnClick()
    assert(
        RTB:GetSpecialBagInvisible(row.definition.family),
        "special-bag invisibility did not enable"
    )
    assert(
        row.toggle.text == "OFF",
        "hidden special-bag OFF label missing"
    )
    row.toggle.scripts.OnClick()
    assert(
        not RTB:GetSpecialBagInvisible(row.definition.family),
        "special-bag invisibility did not disable"
    )
    assert(
        row.toggle.text == "ON",
        "visible special-bag ON label missing"
    )
end

RTB.SettingsBottomClose.scripts.OnClick()
assert(not RTB.SettingsFrame:IsShown(), "bottom close button failed")

local inventoryGear = RTB:CreateSettingsGear(inventory, "inventory")
inventoryGear.scripts.OnClick()
assert(RTB.SettingsFrame:IsShown(), "inventory gear did not open settings")
RTB.SettingsCloseButton.scripts.OnClick()
assert(not RTB.SettingsFrame:IsShown(), "top close button failed")

inventoryGear.scripts.OnClick()
assert(RTB.SettingsFrame:IsShown(), "inventory gear did not reopen settings")
inventoryGear.scripts.OnClick()
assert(not RTB.SettingsFrame:IsShown(), "inventory gear did not close settings")

local bankGear = RTB:CreateSettingsGear(bank, "bank")
bankGear.scripts.OnClick()
assert(RTB.SettingsFrame:IsShown(), "bank gear did not open settings")
assert(RTB.SettingsAnchorFrame == bank, "bank settings anchor mismatch")
bankGear.scripts.OnClick()
assert(not RTB.SettingsFrame:IsShown(), "bank gear did not close settings")

SlashCmdList.RAIDTHREEBAGS("settings")
assert(
    RTB.SettingsFrame:IsShown(),
    "slash command did not open settings"
)
assert(
    RTB.SettingsAnchorFrame == inventory,
    "slash command did not use inventory anchor"
)
SlashCmdList.RAIDTHREEBAGS("settings")
assert(
    not RTB.SettingsFrame:IsShown(),
    "slash command did not close settings"
)

local function SetRect(widget, left, bottom, width, height)
    widget:ClearAllPoints()
    widget.left = left
    widget.bottom = bottom
    widget.width = width
    widget.height = height
    widget.right = left + width
    widget.top = bottom + height
end

assert(type(RTB.ApplyWindowMagnet) == "function", "window magnet missing")
assert(type(RTB.StartWindowMove) == "function", "group move start missing")
assert(type(RTB.StopWindowMove) == "function", "group move stop missing")

bank:Hide()
RTB.SettingsFrame:Hide()
SetRect(inventory, 7, 9, 480, 500)
assert(RTB:ApplyWindowMagnet(inventory), "screen-edge magnet failed")
assert(inventory:GetLeft() == 0, "left screen edge did not snap")
assert(inventory:GetBottom() == 0, "bottom screen edge did not snap")

RTB.WindowLockButton.scripts.OnClick()
assert(
    not RTB:GetWindowLockEnabled(),
    "corner-lock settings button did not disable locking"
)
assert(
    RTB.WindowLockButton.text == "OFF",
    "disabled corner lock must display OFF"
)
SetRect(inventory, 7, 9, 480, 500)
assert(
    not RTB:ApplyWindowMagnet(inventory),
    "disabled corner lock still activated the magnet"
)
assert(inventory:GetLeft() == 7, "disabled magnet changed window position")
RTB.WindowLockButton.scripts.OnClick()
assert(RTB:GetWindowLockEnabled(), "corner-lock button did not re-enable locking")
assert(RTB.WindowLockButton.text == "ON", "enabled corner lock must display ON")

local cornerPairs = {
    { "TOPLEFT", "TOPRIGHT" },
    { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPRIGHT", "TOPLEFT" },
    { "BOTTOMRIGHT", "BOTTOMLEFT" },
    { "TOPLEFT", "BOTTOMLEFT" },
    { "TOPRIGHT", "BOTTOMRIGHT" },
    { "BOTTOMLEFT", "TOPLEFT" },
    { "BOTTOMRIGHT", "TOPRIGHT" }
}

local function CornerPosition(widget, corner)
    local x
    local y
    if string.find(corner, "LEFT", 1, true) then
        x = widget:GetLeft()
    else
        x = widget:GetRight()
    end
    if string.find(corner, "BOTTOM", 1, true) then
        y = widget:GetBottom()
    else
        y = widget:GetTop()
    end
    return x, y
end

local function PlaceCornerNear(widget, corner, target, targetCorner, dx, dy)
    local targetX, targetY = CornerPosition(target, targetCorner)
    local left = targetX + dx
    local bottom = targetY + dy
    if string.find(corner, "RIGHT", 1, true) then
        left = left - widget.width
    end
    if string.find(corner, "TOP", 1, true) then
        bottom = bottom - widget.height
    end
    SetRect(widget, left, bottom, widget.width, widget.height)
end

bank:Show()
SetRect(bank, 700, 400, 400, 300)
local _, pair
for _, pair in ipairs(cornerPairs) do
    RTB:ClearWindowLocks()
    SetRect(bank, 700, 400, 400, 300)
    SetRect(inventory, 200, 200, 300, 240)
    PlaceCornerNear(inventory, pair[1], bank, pair[2], 6, 7)
    assert(
        RTB:ApplyWindowMagnet(inventory),
        "corner lock failed for " .. pair[1] .. " to " .. pair[2]
    )
    local firstX, firstY = CornerPosition(inventory, pair[1])
    local secondX, secondY = CornerPosition(bank, pair[2])
    assert(
        firstX == secondX and firstY == secondY,
        "locked corners are not pixel-exact"
    )
end

RTB:ClearWindowLocks()
SetRect(bank, 500, 300, 400, 300)
SetRect(inventory, 906, 367, 300, 240)
assert(RTB:ApplyWindowMagnet(inventory), "primary corner lock failed")
assert(RTB:AreWindowsConnected(inventory, bank), "primary windows not connected")
assert(
    type(RTB.DB.settings.primaryWindowLock) == "table",
    "primary corner lock was not persisted"
)

local inventoryLeftBefore = inventory:GetLeft()
local inventoryBottomBefore = inventory:GetBottom()
RTB:StartWindowMove(bank)
SetRect(bank, 620, 380, 400, 300)
assert(
    inventory:GetLeft() == inventoryLeftBefore + 120
        and inventory:GetBottom() == inventoryBottomBefore + 80,
    "locked group did not move with its active root"
)
RTB:StopWindowMove(bank)

local joinedX, joinedY = CornerPosition(bank, "TOPRIGHT")
RTB:StartWindowResize(inventory, "BOTTOMRIGHT")
assert(
    inventory.sizingPoint == "BOTTOMRIGHT",
    "locked window did not begin standard resize"
)
inventory:SetWidth(360)
local resizedX, resizedY = CornerPosition(inventory, "TOPLEFT")
assert(
    joinedX == resizedX and joinedY == resizedY,
    "independent resize broke the locked corner"
)
RTB:StopWindowResize(inventory)

shiftKeyDown = true
RTB:StartWindowMove(inventory)
assert(
    not RTB:AreWindowsConnected(inventory, bank),
    "Shift move did not disconnect the active window"
)
SetRect(inventory, 250, 180, 360, 240)
shiftKeyDown = false
RTB:StopWindowMove(inventory)
assert(
    not RTB:AreWindowsConnected(inventory, bank),
    "Shift move reconnected after Shift was released before drag stop"
)
assert(
    RTB.DB.settings.primaryWindowLock == nil,
    "Shift disconnect left a persisted primary lock"
)

RTB:ClearWindowLocks()
SetRect(bank, 500, 300, 400, 300)
SetRect(inventory, 913, 367, 360, 240)
assert(
    not RTB:ApplyWindowMagnet(inventory),
    "window corner lock activated beyond 12 pixels"
)

SetRect(inventory, 906, 367, 360, 240)
assert(RTB:ApplyWindowMagnet(inventory), "primary lock recreation failed")
local savedPrimaryLock = RTB.DB.settings.primaryWindowLock
RTB:NormalizeWindowFrames(RTB:GetWindowFrames())
RTB.WindowLocks = {}
RTB.DB.settings.primaryWindowLock = savedPrimaryLock
assert(RTB:RestorePrimaryWindowLock(), "persisted primary lock did not restore")
assert(
    RTB:AreWindowsConnected(inventory, bank),
    "restored primary windows are not connected"
)

RTB:SavePrimaryWindowStates()
assert(
    RTB.DB.window.point == "BOTTOMLEFT"
        and RTB.DB.bankWindow.point == "BOTTOMLEFT",
    "locked window positions were not normalized before saving"
)

RTB:SetWindowLockEnabled(false)
assert(
    not RTB:AreWindowsConnected(inventory, bank),
    "disabling corner lock did not disconnect an existing group"
)
assert(
    RTB.DB.settings.primaryWindowLock == nil,
    "disabling corner lock left a persisted primary lock"
)
RTB:SetWindowLockEnabled(true)
SetRect(bank, 500, 300, 400, 300)
SetRect(inventory, 906, 367, 360, 240)
assert(RTB:ApplyWindowMagnet(inventory), "reset lock setup failed")
RTB:ResetInventoryWindowState(true)
assert(
    not RTB:AreWindowsConnected(inventory, bank),
    "inventory reset did not disconnect its window"
)
assert(
    RTB.DB.settings.primaryWindowLock == nil,
    "inventory reset left a persisted primary lock"
)

RTB:ClearWindowLocks()
SetRect(inventory, 300, 250, 360, 240)
SetRect(RTB.SettingsFrame, 666, 257, 520, 550)
RTB.SettingsFrame:Show()
assert(RTB:ApplyWindowMagnet(RTB.SettingsFrame), "settings corner lock failed")
assert(
    RTB:AreWindowsConnected(RTB.SettingsFrame, inventory),
    "settings window did not join the group"
)
RTB.SettingsFrame:Hide()
assert(
    not RTB:AreWindowsConnected(RTB.SettingsFrame, inventory),
    "hidden settings window remained locked"
)

local _, message
for _, message in ipairs(chatMessages) do
    assert(
        not string.find(message, "Settings UI is unavailable", 1, true),
        "obsolete unavailable fallback was reached"
    )
    assert(
        not string.find(message, "Settings UI error", 1, true),
        "settings runtime error was reported"
    )
end

local savedInventoryData = inventoryData[0]
local savedInventorySlotCount = inventorySlotCounts[0]
local savedBagType = bagTypes[0]

bagTypes[0] = 0
inventorySlotCounts[0] = 5
inventoryData[0] = {
    MockInventoryItem(301, "Speed Potion", 1, "Consumable", 1, 10,
        "Potion", 20, 1),
    MockInventoryItem(302, "Poor Item", 0, "Miscellaneous"),
    MockInventoryItem(303, "Ancient Relic", 1, "Miscellaneous"),
    nil,
    MockInventoryItem(301, "Speed Potion", 1, "Consumable", 9, 10,
        "Potion", 20, 1)
}
RTB:UpdateItemAgeTracking(mockTime)
local frozenAgeStore = assert(RTB:GetCharacterItemAgeStore())
frozenAgeStore["303"].firstSeen = mockTime - RTB.ITEM_AGE_SECONDS - 1
local frozenPools = assert(RTB:BuildInventorySortPlan(mockTime))
local frozenPool = frozenPools[1]
assert(frozenPool.frozenCount == 1,
    "the occupied bottom tail must be frozen")
assert(frozenPool.slots[5].frozen,
    "the bottom item must remain in its original slot")
local frozenSource, frozenTarget = RTB:FindInventoryConsolidationMove(frozenPools)
assert(frozenSource and frozenTarget and frozenTarget.frozen,
    "a frozen bottom stack must remain a valid merge target")
assert(frozenSource.itemKey == frozenTarget.itemKey,
    "frozen merge target must accept only the same item")

inventorySlotCounts[0] = 4
inventoryData[0] = {
    MockInventoryItem(301, "Speed Potion", 1, "Consumable", 1, 10,
        "Potion", 20, 1),
    MockInventoryItem(302, "Poor Item", 0, "Miscellaneous"),
    nil,
    MockInventoryItem(301, "Speed Potion", 1, "Consumable", 9, 10,
        "Potion", 20, 1)
}
local arrangedFrozenPools = assert(RTB:BuildInventorySortPlan(mockTime + 1))
local arrangedFrozenPool = arrangedFrozenPools[1]
assert(arrangedFrozenPool.frozenCount == 1 and arrangedFrozenPool.desired[4] == "301",
    "the frozen bottom item must remain in the arranged plan")
inventoryData[0] = {
    MockInventoryItem(302, "Poor Item", 0, "Miscellaneous"),
    nil,
    nil,
    MockInventoryItem(304, "Different Item", 1, "Miscellaneous")
}
local refreshedFrozen, refreshError = RTB:RefreshInventorySortPlan(arrangedFrozenPools)
assert(refreshedFrozen, refreshError)
local changedSource, changedTarget, changedError =
    RTB:FindNextInventorySortMove(arrangedFrozenPools)
assert(not changedSource and not changedTarget and changedError,
    "sort must stop when a frozen slot changes unexpectedly")

inventoryData[0] = savedInventoryData
inventorySlotCounts[0] = savedInventorySlotCount
bagTypes[0] = savedBagType

print("SETTINGS LOGIC OK")
