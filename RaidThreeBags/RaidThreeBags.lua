-- ============================================================
-- RaidThreeBags.lua
-- Core state, bag hooks, events, and slash commands.
-- Target: WoW 3.3.5a / Interface 30300 / Lua 5.1.
-- ============================================================

RaidThreeBags = RaidThreeBags or {}

local RTB = RaidThreeBags

RTB.ADDON_NAME = "RaidThreeBags"
RTB.VERSION = "0.4.0"
RTB.BAG_IDS = { 0, 1, 2, 3, 4 }
RTB.BANK_BAG_IDS = { 5, 6, 7, 8, 9, 10, 11 }
RTB.SPECIAL_BAG_TYPES = {
    { family = 1, label = "Quiver (Arrows)" },
    { family = 2, label = "Ammo Pouch (Bullets)" },
    { family = 4, label = "Soul Bag (Shards)" },
    { family = 8, label = "Leatherworking Bag" },
    { family = 16, label = "Inscription Bag" },
    { family = 32, label = "Herb Bag" },
    { family = 64, label = "Enchanting Bag" },
    { family = 128, label = "Engineering Bag" },
    { family = 512, label = "Gem Bag" },
    { family = 1024, label = "Mining Bag" }
}
RTB.DEFAULT_WIDTH = 480
RTB.DEFAULT_HEIGHT = 500
RTB.MIN_WIDTH = 320
RTB.MIN_HEIGHT = 240
RTB.MAX_WIDTH = 900
RTB.MAX_HEIGHT = 760
RTB.BANK_DEFAULT_WIDTH = 560
RTB.BANK_DEFAULT_HEIGHT = 500
RTB.BANK_MIN_WIDTH = 320
RTB.BANK_MIN_HEIGHT = 300
RTB.BANK_MAX_WIDTH = 1000
RTB.BANK_MAX_HEIGHT = 800

local DEFAULTS = {
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = RTB.DEFAULT_WIDTH,
        height = RTB.DEFAULT_HEIGHT
    },
    bankWindow = {
        point = "RIGHT",
        relativePoint = "CENTER",
        x = -250,
        y = 0,
        width = RTB.BANK_DEFAULT_WIDTH,
        height = RTB.BANK_DEFAULT_HEIGHT
    },
    settings = {
        windowLockEnabled = true,
        invisibleBagFamilies = {
            [1] = false,
            [2] = false,
            [4] = false,
            [8] = false,
            [16] = false,
            [32] = false,
            [64] = false,
            [128] = false,
            [512] = false,
            [1024] = false
        }
    }
}

local function CopyDefaults(target, defaults)
    local key, value
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

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

function RTB:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb3d9ffRaidThreeBags:|r " .. tostring(message or ""))
end

function RTB:InitializeDB()
    if type(RaidThreeBagsDB) ~= "table" then
        RaidThreeBagsDB = {}
    end

    CopyDefaults(RaidThreeBagsDB, DEFAULTS)
    self.DB = RaidThreeBagsDB
end

function RTB:SaveWindowState()
    if not self.DB or not self.MainFrame then
        return
    end

    local state = self.DB.window
    local left = self.MainFrame:GetLeft()
    local bottom = self.MainFrame:GetBottom()
    local screenLeft = UIParent:GetLeft() or 0
    local screenBottom = UIParent:GetBottom() or 0
    if type(left) == "number" and type(bottom) == "number" then
        state.point = "BOTTOMLEFT"
        state.relativePoint = "BOTTOMLEFT"
        state.x = left - screenLeft
        state.y = bottom - screenBottom
    end
    state.width = Clamp(self.MainFrame:GetWidth(), self.MIN_WIDTH, self.MAX_WIDTH)
    state.height = Clamp(self.MainFrame:GetHeight(), self.MIN_HEIGHT, self.MAX_HEIGHT)
end

function RTB:ApplyWindowState()
    if not self.DB or not self.MainFrame then
        return
    end

    local state = self.DB.window
    local width = Clamp(state.width, self.MIN_WIDTH, self.MAX_WIDTH)
    local height = Clamp(state.height, self.MIN_HEIGHT, self.MAX_HEIGHT)

    self.MainFrame:SetWidth(width)
    self.MainFrame:SetHeight(height)
    self.MainFrame:ClearAllPoints()
    self.MainFrame:SetPoint(
        state.point or "CENTER",
        UIParent,
        state.relativePoint or state.point or "CENTER",
        tonumber(state.x) or 0,
        tonumber(state.y) or 0
    )
    self:RequestLayout()
end

function RTB:ResetInventoryWindowState(silent)
    if not self.DB then
        return
    end

    if self.DisconnectWindow then
        self:DisconnectWindow(self.MainFrame)
    end
    self.DB.window = {}
    CopyDefaults(self.DB.window, DEFAULTS.window)
    self:EnsureUI()
    self:ApplyWindowState()
    self:RefreshAll()
    if not silent then
        self:Print("Okno inventara bolo obnovene.")
    end
end

function RTB:ResetBankWindowState(silent)
    if not self.DB then
        return
    end

    if self.DisconnectWindow then
        self:DisconnectWindow(self.PlayerBankFrame)
    end
    self.DB.bankWindow = {}
    CopyDefaults(self.DB.bankWindow, DEFAULTS.bankWindow)
    if self.PlayerBankFrame then
        self:ApplyBankWindowState()
        if self.PlayerBankFrame:IsShown() then
            self:RefreshBankAll()
        end
    end
    if not silent then
        self:Print("Okno banky bolo obnovene.")
    end
end

function RTB:ResetWindowState()
    self:ResetInventoryWindowState(true)
    self:ResetBankWindowState(true)
    self:Print("Poloha a velkost okien boli obnovene.")
end

function RTB:IsSpecialBagInvisible(bagType)
    if not self.DB or not self.DB.settings then
        return false
    end

    bagType = tonumber(bagType) or 0
    local invisible = self.DB.settings.invisibleBagFamilies
    local _, definition
    for _, definition in ipairs(self.SPECIAL_BAG_TYPES) do
        if invisible[definition.family]
            and bit
            and bit.band(bagType, definition.family) > 0
        then
            return true
        end
    end
    return false
end

function RTB:IsInventoryBagVisible(bagID)
    if bagID == BACKPACK_CONTAINER then
        return true
    end

    local _, bagType = GetContainerNumFreeSlots(bagID)
    return not self:IsSpecialBagInvisible(bagType)
end

function RTB:SetSpecialBagInvisible(family, invisible)
    if not self.DB or not self.DB.settings then
        return
    end

    family = tonumber(family)
    if not family then
        return
    end

    self.DB.settings.invisibleBagFamilies[family] =
        invisible and true or false

    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshAll()
    end
end

function RTB:GetSpecialBagInvisible(family)
    if not self.DB or not self.DB.settings then
        return false
    end
    return self.DB.settings.invisibleBagFamilies[tonumber(family)] and true or false
end

function RTB:GetWindowLockEnabled()
    if not self.DB or not self.DB.settings then
        return true
    end
    return self.DB.settings.windowLockEnabled ~= false
end

function RTB:SetWindowLockEnabled(enabled)
    if not self.DB or not self.DB.settings then
        return
    end

    self.DB.settings.windowLockEnabled = enabled and true or false
    if not enabled and self.ClearWindowLocks then
        self:ClearWindowLocks()
    elseif enabled and self.RestorePrimaryWindowLock then
        self:RestorePrimaryWindowLock()
    end

    if self.RefreshSettingsUI then
        self:RefreshSettingsUI()
    end
end

function RTB:Show()
    self:EnsureUI()
    self:RefreshAll()
    self.MainFrame:Show()
end

function RTB:Hide()
    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

function RTB:Toggle()
    self:EnsureUI()
    if self.MainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function RTB:RunBagAction(methodName, fallback, ...)
    local method = self[methodName]
    local ok, err = pcall(method, self, ...)
    if ok then
        return
    end

    self:Print("UI error: " .. tostring(err))
    if fallback then
        fallback(...)
    end
end

function RTB:InstallBagHooks()
    if self.BagHooksInstalled then
        return
    end
    self.BagHooksInstalled = true

    local originalOpenBackpack = OpenBackpack
    local originalToggleBackpack = ToggleBackpack
    local originalToggleBag = ToggleBag
    local originalOpenAllBags = OpenAllBags

    OpenBackpack = function()
        RTB:RunBagAction("Show", originalOpenBackpack)
    end

    ToggleBackpack = function()
        RTB:RunBagAction("Toggle", originalToggleBackpack)
    end

    ToggleBag = function(bagSlot)
        RTB:RunBagAction("Toggle", originalToggleBag, bagSlot)
    end

    OpenAllBags = function(force)
        if force then
            RTB:RunBagAction("Show", originalOpenAllBags, force)
        else
            RTB:RunBagAction("Toggle", originalOpenAllBags, force)
        end
    end

    hooksecurefunc("CloseBackpack", function()
        RTB:Hide()
    end)

    hooksecurefunc("CloseAllBags", function()
        RTB:Hide()
    end)
end

function RTB:ADDON_LOADED(loadedAddon)
    if loadedAddon ~= self.ADDON_NAME then
        return
    end

    self:InitializeDB()
    self:InstallBagHooks()
    if self.InstallBankHooks then
        self:InstallBankHooks()
    end
end

function RTB:PLAYER_ENTERING_WORLD()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshAll()
    end
end

function RTB:BAG_UPDATE()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshAll()
    end
    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:RefreshBankAll()
    end
end

function RTB:BAG_UPDATE_COOLDOWN()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshCooldowns()
    end
    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:RefreshBankCooldowns()
    end
end

function RTB:ITEM_LOCK_CHANGED(bagID, slotID)
    if self.MainFrame and self.MainFrame:IsShown() then
        self:UpdateInventoryBagSlots()
        if type(bagID) == "number" and type(slotID) == "number" then
            self:RefreshItem(bagID, slotID)
        else
            self:RefreshItems()
        end
    end

    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:RefreshBankItems()
        self:UpdateBankBagSlots()
    end
end

function RTB:PLAYER_MONEY()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:UpdateFooter()
    end
    if self.PlayerBankFrame and self.PlayerBankFrame:IsShown() then
        self:UpdateBankFooter()
        self:UpdateBankBagSlots()
    end
end

SLASH_RAIDTHREEBAGS1 = "/rtb"
SLASH_RAIDTHREEBAGS2 = "/r3bags"

SlashCmdList.RAIDTHREEBAGS = function(message)
    local command = tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if command == "version" then
        RTB:Print("version " .. tostring(RTB.VERSION))
    elseif command == "reset" then
        RTB:ResetWindowState()
    elseif command == "reset inventory" then
        RTB:ResetInventoryWindowState()
    elseif command == "reset bank" then
        RTB:ResetBankWindowState()
    elseif command == "settings" or command == "options" then
        RTB:EnsureUI()
        local ok, err = pcall(RTB.ToggleSettings, RTB, RTB.MainFrame)
        if not ok then
            RTB:Print("Settings UI error: " .. tostring(err))
        end
    elseif command == "bank" then
        RTB:RunBankAction("ToggleBank")
    elseif command == "show" or command == "open" then
        RTB:RunBagAction("Show")
    elseif command == "hide" or command == "close" then
        RTB:Hide()
    elseif command == "help" then
        RTB:Print("/rtb = open or close inventory")
        RTB:Print("/rtb bank = open or close the bank while at a banker")
        RTB:Print("/rtb settings = open settings")
        RTB:Print("/rtb reset = reset both window positions and sizes")
        RTB:Print("/rtb reset inventory = reset the inventory window")
        RTB:Print("/rtb reset bank = reset the bank window")
        RTB:Print("/rtb version = print the addon version")
    else
        RTB:RunBagAction("Toggle")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
eventFrame:RegisterEvent("CURSOR_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = RTB[event]
    if handler then
        handler(RTB, ...)
    end
end)
