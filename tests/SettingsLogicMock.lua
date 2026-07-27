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

function GetScreenWidth()
    return 1920
end

function GetScreenHeight()
    return 1080
end

function IsShiftKeyDown()
    return shiftKeyDown
end

function GetContainerNumFreeSlots(bagID)
    return 10, bagTypes[bagID] or 0
end

function GetContainerNumSlots()
    return 0
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
    footerBrand.rtbCredit.textColor[1] == 0.74
        and footerBrand.rtbCredit.textColor[2] == 0.74
        and footerBrand.rtbCredit.textColor[3] == 0.80,
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

print("SETTINGS LOGIC OK")
