-- ============================================================
-- RaidThreeBags.lua
-- Core state, bag hooks, events, and slash commands.
-- Target: WoW 3.3.5a / Interface 30300 / Lua 5.1.
-- ============================================================

RaidThreeBags = RaidThreeBags or {}

local RTB = RaidThreeBags

RTB.ADDON_NAME = "RaidThreeBags"
RTB.VERSION = "0.4.3"
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
RTB.ITEM_AGE_SECONDS = 24 * 60 * 60
RTB.SORT_TRACE_SCHEMA = 2
RTB.SORT_TRACE_MAX_SESSIONS = 10
RTB.SORT_TRACE_MAX_ID = 2147483647

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
    },
    itemAgeByCharacter = {},
    sortTrace = {
        enabled = true,
        nextSessionID = 1,
        sessions = {}
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
    if self.GetInventorySortTraceStore then
        self:GetInventorySortTraceStore()
    end
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

function RTB:GetItemAgeKey(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end

    local itemID = string.match(itemLink, "item:(%d+)")
    if itemID then
        return itemID
    end
    return itemLink
end

function RTB:GetCharacterItemAgeStore()
    if not self.DB then
        return nil
    end

    local characterName = UnitName("player")
    if not characterName or characterName == "" then
        return nil
    end
    local realmName = GetRealmName and GetRealmName() or ""
    local characterKey = tostring(realmName or "")
        .. ":"
        .. tostring(characterName)

    if type(self.DB.itemAgeByCharacter) ~= "table" then
        self.DB.itemAgeByCharacter = {}
    end
    if type(self.DB.itemAgeByCharacter[characterKey]) ~= "table" then
        self.DB.itemAgeByCharacter[characterKey] = {}
    end
    return self.DB.itemAgeByCharacter[characterKey]
end

function RTB:UpdateItemAgeTracking(observedAt)
    if self.SortInProgress or (CursorHasItem and CursorHasItem()) then
        return false
    end

    local ageStore = self:GetCharacterItemAgeStore()
    if not ageStore then
        return false
    end

    observedAt = tonumber(observedAt) or (time and time()) or 0
    local counts = {}
    local inventoryComplete = true
    local _, bagID
    for _, bagID in ipairs(self.BAG_IDS) do
        local slotCount = GetContainerNumSlots(bagID) or 0
        local slotID
        for slotID = 1, slotCount do
            local texture, count, _, _, _, _, itemLink =
                GetContainerItemInfo(bagID, slotID)
            if texture and not itemLink then
                inventoryComplete = false
            end
            local itemKey = self:GetItemAgeKey(itemLink)
            if itemKey then
                counts[itemKey] = (counts[itemKey] or 0)
                    + math.max(1, tonumber(count) or 1)
            end
        end
    end

    if not inventoryComplete then
        return false
    end

    local itemKey, count
    for itemKey, count in pairs(counts) do
        local entry = ageStore[itemKey]
        if type(entry) ~= "table"
            or type(entry.firstSeen) ~= "number"
        then
            entry = { firstSeen = observedAt }
            ageStore[itemKey] = entry
        end
        entry.count = count
        entry.lastSeen = observedAt
    end

    for itemKey in pairs(ageStore) do
        if not counts[itemKey] then
            ageStore[itemKey] = nil
        end
    end
    return true
end

function RTB:GetInventorySortTopologyFingerprint()
    local parts = {}
    local _, bagID
    for _, bagID in ipairs(self.BAG_IDS) do
        local slotCount = tonumber(GetContainerNumSlots(bagID)) or 0
        local _, bagType = GetContainerNumFreeSlots(bagID)
        local bagLink = ""
        if bagID ~= BACKPACK_CONTAINER
            and ContainerIDToInventoryID
            and GetInventoryItemLink
        then
            local inventorySlot = ContainerIDToInventoryID(bagID)
            if inventorySlot then
                bagLink = GetInventoryItemLink("player", inventorySlot) or ""
            end
        end
        table.insert(
            parts,
            tostring(bagID)
                .. ":"
                .. tostring(slotCount)
                .. ":"
                .. tostring(tonumber(bagType) or 0)
                .. ":"
                .. tostring(bagLink)
        )
    end
    return table.concat(parts, "|")
end

function RTB:GetItemFirstSeen(itemLink)
    local ageStore = self:GetCharacterItemAgeStore()
    local itemKey = self:GetItemAgeKey(itemLink)
    local entry = ageStore and itemKey and ageStore[itemKey]
    if type(entry) == "table" then
        return tonumber(entry.firstSeen)
    end
    return nil
end

local SORT_CATEGORY_RANKS = {
    quest = 1, consumable = 2, weapon = 3, armor = 4,
    recipe = 5, gem = 6, trade = 7, container = 8,
    projectile = 9, key = 10, miscellaneous = 11, other = 12
}

local SORT_EQUIP_RANKS = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3,
    INVTYPE_CLOAK = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WRIST = 6, INVTYPE_HAND = 7, INVTYPE_WAIST = 8,
    INVTYPE_LEGS = 9, INVTYPE_FEET = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 12, INVTYPE_WEAPONMAINHAND = 13,
    INVTYPE_2HWEAPON = 14, INVTYPE_WEAPON = 15,
    INVTYPE_WEAPONOFFHAND = 16, INVTYPE_SHIELD = 17,
    INVTYPE_HOLDABLE = 18, INVTYPE_RANGED = 19,
    INVTYPE_RANGEDRIGHT = 19, INVTYPE_THROWN = 19,
    INVTYPE_RELIC = 20, INVTYPE_TABARD = 21, INVTYPE_BODY = 22,
    INVTYPE_BAG = 23, INVTYPE_QUIVER = 24
}

local function GetSortCategory(itemType)
    if itemType == (QUESTS or "Quest") then return "quest"
    elseif itemType == (CONSUMABLE or "Consumable") then return "consumable"
    elseif itemType == (WEAPON or "Weapon") then return "weapon"
    elseif itemType == (ARMOR or "Armor") then return "armor"
    elseif itemType == (RECIPE or "Recipe") then return "recipe"
    elseif itemType == (GEM or "Gem") then return "gem"
    elseif itemType == (TRADE_GOODS or "Trade Goods") then return "trade"
    elseif itemType == (CONTAINER or "Container") then return "container"
    elseif itemType == (PROJECTILE or "Projectile")
        or itemType == (QUIVER or "Quiver") then return "projectile"
    elseif itemType == (KEYS or "Key") then return "key"
    elseif itemType == (MISCELLANEOUS or "Miscellaneous") then
        return "miscellaneous"
    end
    return "other"
end

local function SortItemsHierarchically(first, second)
    local fields = { "categoryRank", "subTypeRank", "equipRank", "usableRank" }
    local _, field
    for _, field in ipairs(fields) do
        if first[field] ~= second[field] then
            return first[field] < second[field]
        end
    end
    if first.quality ~= second.quality then return first.quality > second.quality end
    if first.itemLevel ~= second.itemLevel then return first.itemLevel > second.itemLevel end
    if first.sortName ~= second.sortName then return first.sortName < second.sortName end
    if first.itemKey ~= second.itemKey then return first.itemKey < second.itemKey end
    return (first.order or 0) < (second.order or 0)
end

local function AppendSortItems(target, source)
    local _, item
    for _, item in ipairs(source) do
        table.insert(target, item.itemKey)
    end
end

local function CountNonEmptySortGroups(pool)
    local count = 0
    if #pool.trash > 0 then
        count = count + 1
    end
    if #pool.current > 0 then
        count = count + 1
    end
    if #pool.old > 0 then
        count = count + 1
    end
    return count
end

local function BuildPoolDesiredOrder(pool)
    local desired = {}
    local groups = {
        { key = "trash", items = pool.trash },
        { key = "current", items = pool.current },
        { key = "old", items = pool.old }
    }
    local remainingEmpty = pool.emptyCount - pool.requiredSeparators
    local appendedGroups = 0
    local _, group
    for _, group in ipairs(groups) do
        if #group.items > 0 then
            if appendedGroups > 0 then
                table.insert(desired, false)
            end
            if group.key == "old" then
                local emptyIndex
                for emptyIndex = 1, remainingEmpty do
                    table.insert(desired, false)
                end
            end
            AppendSortItems(desired, group.items)
            appendedGroups = appendedGroups + 1
        end
    end

    if #pool.old == 0 then
        local emptyIndex
        for emptyIndex = 1, remainingEmpty do
            table.insert(desired, false)
        end
    end
    return desired
end

function RTB:BuildInventorySortPlan(observedAt)
    observedAt = tonumber(observedAt) or (time and time()) or 0
    self:UpdateItemAgeTracking(observedAt)

    local pools = {}
    local poolByKey = {}
    local order = 0
    local tradeGoodsName = TRADE_GOODS or "Trade Goods"
    local _, bagID
    for _, bagID in ipairs(self.BAG_IDS) do
        local _, bagType = GetContainerNumFreeSlots(bagID)
        bagType = tonumber(bagType) or 0
        local poolKey = bagType == 0
            and "general"
            or ("family:" .. tostring(bagType))
        local pool = poolByKey[poolKey]
        if not pool then
            pool = {
                key = poolKey,
                slots = {},
                trash = {},
                current = {},
                old = {},
                emptyCount = 0,
                stackByKey = {}
            }
            poolByKey[poolKey] = pool
            table.insert(pools, pool)
        end

        local slotCount = GetContainerNumSlots(bagID) or 0
        local slotID
        for slotID = 1, slotCount do
            order = order + 1
            local texture, count, locked, quality, _, _, itemLink =
                GetContainerItemInfo(bagID, slotID)
            local slot = {
                bagID = bagID,
                slotID = slotID,
                itemKey = false,
                count = 0
            }
            table.insert(pool.slots, slot)

            if texture and not itemLink then
                return nil, "Item information is still loading. Try again."
            elseif itemLink then
                if locked then
                    return nil, "An inventory item is locked. Try again shortly."
                end

                local name, _, itemQuality, itemLevel, minimumLevel,
                    itemType, itemSubType, maxStack, equipLocation =
                    GetItemInfo(itemLink)
                if not name then
                    return nil, "Item information is still loading. Try again."
                end

                local itemKey = self:GetItemAgeKey(itemLink)
                local firstSeen = self:GetItemFirstSeen(itemLink)
                local category = GetSortCategory(itemType)
                local playerLevel = UnitLevel and UnitLevel("player") or 0
                minimumLevel = math.max(0, tonumber(minimumLevel) or 0)
                maxStack = math.max(1, tonumber(maxStack) or 1)
                local item = {
                    itemKey = itemKey,
                    link = itemLink,
                    name = name,
                    sortName = string.lower(tostring(name)),
                    count = math.max(1, tonumber(count) or 1),
                    maxStack = maxStack,
                    quality = tonumber(quality) or tonumber(itemQuality) or 0,
                    itemType = itemType,
                    itemSubType = itemSubType or "",
                    itemLevel = math.max(0, tonumber(itemLevel) or 0),
                    minimumLevel = minimumLevel,
                    equipLocation = equipLocation or "",
                    category = category,
                    categoryRank = SORT_CATEGORY_RANKS[category]
                        or SORT_CATEGORY_RANKS.other,
                    subTypeRank = string.lower(tostring(itemSubType or "")),
                    equipRank = SORT_EQUIP_RANKS[equipLocation] or 100,
                    usableRank = minimumLevel <= playerLevel and 0 or 1,
                    firstSeen = firstSeen,
                    order = order
                }
                slot.itemKey = itemKey
                slot.count = item.count
                slot.maxStack = maxStack

                local stack = pool.stackByKey[itemKey]
                if not stack then
                    stack = {
                        totalCount = 0,
                        stackCount = 0,
                        maxStack = maxStack
                    }
                    pool.stackByKey[itemKey] = stack
                end
                stack.totalCount = stack.totalCount + item.count
                stack.stackCount = stack.stackCount + 1
                stack.maxStack = math.max(stack.maxStack, maxStack)

                quality = tonumber(quality) or tonumber(itemQuality)
                item.quality = quality
                if quality == 0 then
                    item.group = "trash"
                    table.insert(pool.trash, item)
                elseif itemType == tradeGoodsName then
                    item.group = "current"
                    table.insert(pool.current, item)
                elseif firstSeen
                    and observedAt - firstSeen >= self.ITEM_AGE_SECONDS
                then
                    item.group = "old"
                    table.insert(pool.old, item)
                else
                    item.group = "current"
                    table.insert(pool.current, item)
                end
            else
                pool.emptyCount = pool.emptyCount + 1
            end
        end
    end
    local activePools = {}
    local _, pool
    for _, pool in ipairs(pools) do
        if #pool.slots > 0 then
            table.insert(activePools, pool)
        end
    end
    pools = activePools
    pools.topologyFingerprint = self:GetInventorySortTopologyFingerprint()

    for _, pool in ipairs(pools) do
        table.sort(pool.trash, SortItemsHierarchically)
        table.sort(pool.current, SortItemsHierarchically)
        table.sort(pool.old, SortItemsHierarchically)

        local nonEmptyGroups = CountNonEmptySortGroups(pool)
        pool.requiredSeparators = math.max(0, nonEmptyGroups - 1)
        pool.freeableSlots = 0
        local _, stack
        for _, stack in pairs(pool.stackByKey) do
            if stack.maxStack > 1 then
                local minimumStacks = math.floor(
                    (stack.totalCount + stack.maxStack - 1) / stack.maxStack
                )
                pool.freeableSlots = pool.freeableSlots
                    + math.max(0, stack.stackCount - minimumStacks)
            end
        end

        if pool.emptyCount + pool.freeableSlots < pool.requiredSeparators then
            return nil, "Not enough compatible stack capacity to create "
                .. tostring(pool.requiredSeparators)
                .. " required separator slots."
        end

        pool.needsConsolidation =
            pool.emptyCount < pool.requiredSeparators
        if not pool.needsConsolidation then
            pool.desired = BuildPoolDesiredOrder(pool)
        end
    end
    return pools
end

local function TraceSlotKey(bagID, slotID)
    return tostring(bagID) .. ":" .. tostring(slotID)
end

local function TraceCountsEqual(first, second)
    local itemKey, count
    for itemKey, count in pairs(first or {}) do
        if tonumber(second and second[itemKey]) ~= tonumber(count) then
            return false, itemKey
        end
    end
    for itemKey, count in pairs(second or {}) do
        if tonumber(first and first[itemKey]) ~= tonumber(count) then
            return false, itemKey
        end
    end
    return true, nil
end

local function NormalizeTraceInteger(value, fallback)
    value = tonumber(value)
    if not value
        or value ~= value
        or value == math.huge
        or value == -math.huge
    then
        return fallback
    end
    return math.floor(value)
end

local function TraceDenseArrayValid(value)
    if type(value) ~= "table" then
        return false
    end
    local length = #value
    local count = 0
    local key
    for key in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key ~= math.floor(key)
            or key > length
        then
            return false
        end
        count = count + 1
    end
    return count == length
end

function RTB:GetInventorySortTraceStore()
    if not self.DB then
        return nil
    end
    if type(self.DB.sortTrace) ~= "table" then
        self.DB.sortTrace = {}
    end
    local store = self.DB.sortTrace
    if store.enabled == nil then
        store.enabled = true
    else
        store.enabled = store.enabled ~= false
    end
    if type(store.sessions) ~= "table" then
        store.sessions = {}
    end
    local retained = {}
    local key, trace
    for key, trace in pairs(store.sessions) do
        local rawTraceID = type(key) == "number"
            and key >= 1
            and key == math.floor(key)
            and type(trace) == "table"
            and tonumber(trace.id)
            or nil
        local traceID = NormalizeTraceInteger(rawTraceID, nil)
        if traceID
            and traceID > 0
            and traceID <= self.SORT_TRACE_MAX_ID
            and rawTraceID == traceID
        then
            trace.id = traceID
            if trace.status ~= "PASS"
                and trace.status ~= "FAIL"
                and trace.status ~= "ABORTED"
                and trace.status ~= "RUNNING"
            then
                trace.status = "ABORTED"
                trace.reason = "Invalid retained sort trace status."
            elseif trace.status == "RUNNING" and not self.SortSession then
                trace.status = "ABORTED"
                trace.reason = "Client reloaded before sort completion."
                trace.finishedAt = (time and time()) or trace.startedAt or 0
            end
            if type(trace.events) ~= "table" then
                trace.events = {}
            end
            if type(trace.verdict) ~= "table" then
                trace.verdict = nil
            end
            if type(trace.before) ~= "table" then
                trace.before = nil
            end
            if type(trace.after) ~= "table" then
                trace.after = nil
            end
            table.insert(retained, trace)
        end
    end
    table.sort(retained, function(first, second)
        return first.id < second.id
    end)
    while #retained > self.SORT_TRACE_MAX_SESSIONS do
        table.remove(retained, 1)
    end
    store.sessions = retained
    local highestID = 0
    local duplicateID = false
    local index
    for index, trace in ipairs(store.sessions) do
        if trace.id <= highestID then
            duplicateID = true
        end
        highestID = math.max(highestID, trace.id)
    end
    local nextSessionID = math.max(
        highestID + 1,
        NormalizeTraceInteger(store.nextSessionID, 1),
        1
    )
    if duplicateID or nextSessionID > self.SORT_TRACE_MAX_ID then
        highestID = 0
        for index, trace in ipairs(store.sessions) do
            trace.id = index
            highestID = index
        end
        nextSessionID = highestID + 1
    end
    store.nextSessionID = nextSessionID
    return store
end

function RTB:CaptureInventorySortTraceSnapshot()
    local snapshot = {
        topology = self:GetInventorySortTopologyFingerprint(),
        cursorHasItem = CursorHasItem and CursorHasItem() and true or false,
        unknownCount = 0,
        slots = {},
        counts = {},
        poolCounts = {}
    }
    local _, bagID
    for _, bagID in ipairs(self.BAG_IDS) do
        local _, bagType = GetContainerNumFreeSlots(bagID)
        bagType = tonumber(bagType) or 0
        local poolKey = bagType == 0
            and "general"
            or ("family:" .. tostring(bagType))
        if type(snapshot.poolCounts[poolKey]) ~= "table" then
            snapshot.poolCounts[poolKey] = {}
        end
        local slotCount = tonumber(GetContainerNumSlots(bagID)) or 0
        local slotID
        for slotID = 1, slotCount do
            local texture, count, locked, _, _, _, itemLink =
                GetContainerItemInfo(bagID, slotID)
            local itemKey = self:GetItemAgeKey(itemLink)
            local unknown = texture and not itemLink and true or false
            local itemCount = itemKey
                and math.max(1, tonumber(count) or 1)
                or 0
            local entry = {
                bagID = bagID,
                slotID = slotID,
                pool = poolKey,
                itemKey = itemKey or false,
                count = itemCount
            }
            if unknown then
                entry.unknown = true
                snapshot.unknownCount = snapshot.unknownCount + 1
            end
            if locked then
                entry.locked = true
            end
            table.insert(snapshot.slots, entry)
            if itemKey then
                snapshot.counts[itemKey] =
                    (snapshot.counts[itemKey] or 0) + itemCount
                local poolCounts = snapshot.poolCounts[poolKey]
                poolCounts[itemKey] = (poolCounts[itemKey] or 0) + itemCount
            end
        end
    end
    return snapshot
end

local function AppendTraceGroup(plan, groupName, items, observedAt)
    local keys = {}
    local _, item
    for _, item in ipairs(items) do
        table.insert(keys, item.itemKey)
        local metadata = plan.items[item.itemKey]
        if not metadata then
            metadata = {
                itemKey = item.itemKey,
                name = item.name,
                sortName = item.sortName,
                group = groupName,
                quality = item.quality,
                itemType = item.itemType,
                itemSubType = item.itemSubType,
                itemLevel = item.itemLevel,
                minimumLevel = item.minimumLevel,
                equipLocation = item.equipLocation,
                category = item.category,
                categoryRank = item.categoryRank,
                subTypeRank = item.subTypeRank,
                equipRank = item.equipRank,
                usableRank = item.usableRank,
                firstSeen = item.firstSeen
            }
            if item.firstSeen then
                metadata.ageSeconds = math.max(0, observedAt - item.firstSeen)
            end
            plan.items[item.itemKey] = metadata
        end
    end
    return keys
end

function RTB:CreateInventorySortTracePlan(pools, observedAt)
    if type(pools) ~= "table" then
        return nil
    end
    observedAt = tonumber(observedAt) or (time and time()) or 0
    local plan = {
        topology = pools.topologyFingerprint,
        items = {},
        pools = {}
    }
    local _, pool
    for _, pool in ipairs(pools) do
        local tracePool = {
            key = pool.key,
            emptyCount = pool.emptyCount,
            freeableSlots = pool.freeableSlots,
            requiredSeparators = pool.requiredSeparators,
            needsConsolidation = pool.needsConsolidation and true or false,
            slots = {},
            desired = {},
            groups = {}
        }
        local _, slot
        for _, slot in ipairs(pool.slots) do
            table.insert(tracePool.slots, {
                bagID = slot.bagID,
                slotID = slot.slotID
            })
        end
        local index
        for index = 1, #(pool.desired or {}) do
            tracePool.desired[index] = pool.desired[index]
        end
        tracePool.groups.trash = AppendTraceGroup(
            plan,
            "trash",
            pool.trash,
            observedAt
        )
        tracePool.groups.current = AppendTraceGroup(
            plan,
            "current",
            pool.current,
            observedAt
        )
        tracePool.groups.old = AppendTraceGroup(
            plan,
            "old",
            pool.old,
            observedAt
        )
        table.insert(plan.pools, tracePool)
    end
    return plan
end

function RTB:BeginInventorySortTrace()
    local store = self:GetInventorySortTraceStore()
    if not store or store.enabled == false then
        return nil
    end
    local characterName = UnitName and UnitName("player") or ""
    local realmName = GetRealmName and GetRealmName() or ""
    local trace = {
        schema = self.SORT_TRACE_SCHEMA,
        id = store.nextSessionID,
        addonVersion = self.VERSION,
        character = tostring(realmName or "")
            .. ":"
            .. tostring(characterName or ""),
        startedAt = (time and time()) or 0,
        status = "RUNNING",
        events = {},
        before = self:CaptureInventorySortTraceSnapshot()
    }
    store.nextSessionID = store.nextSessionID + 1
    table.insert(store.sessions, trace)
    while #store.sessions > self.SORT_TRACE_MAX_SESSIONS do
        table.remove(store.sessions, 1)
    end
    return trace
end

function RTB:AttachInventorySortTracePlan(trace, pools, initial)
    if not trace then
        return
    end
    local plan = self:CreateInventorySortTracePlan(pools, trace.startedAt)
    if initial or not trace.initialPlan then
        trace.initialPlan = plan
    end
    trace.finalPlan = plan
end

function RTB:TraceInventorySortMove(session, pending)
    local trace = session and session.trace
    if not trace or not pending then
        return
    end
    local event = {
        index = #trace.events + 1,
        kind = pending.kind,
        attemptedAt = session.elapsed,
        source = {
            bagID = pending.source.bagID,
            slotID = pending.source.slotID,
            itemKey = pending.sourceKey,
            count = pending.sourceCount
        },
        target = {
            bagID = pending.target.bagID,
            slotID = pending.target.slotID,
            itemKey = pending.targetKey,
            count = pending.targetCount
        },
        polls = 0,
        unknownReads = 0,
        lockedReads = 0,
        result = "PENDING"
    }
    if pending.kind == "consolidate" then
        event.expectedSourceKey = pending.expectedSourceKey
        event.expectedSourceCount = pending.expectedSourceCount
        event.expectedTargetKey = pending.sourceKey
        event.expectedTargetCount = pending.expectedTargetCount
    else
        event.expectedSourceKey = pending.targetKey
        event.expectedSourceCount = pending.targetCount
        event.expectedTargetKey = pending.sourceKey
        event.expectedTargetCount = pending.sourceCount
    end
    table.insert(trace.events, event)
    pending.traceEvent = event
end

function RTB:ObserveInventorySortTraceMove(
    pending,
    sourceKey,
    sourceCount,
    sourceLocked,
    sourceState,
    targetKey,
    targetCount,
    targetLocked,
    targetState
)
    local event = pending and pending.traceEvent
    if not event then
        return
    end
    event.polls = event.polls + 1
    if sourceState == "unknown" or targetState == "unknown" then
        event.unknownReads = event.unknownReads + 1
    end
    if sourceLocked or targetLocked then
        event.lockedReads = event.lockedReads + 1
    end
    event.lastSourceKey = sourceKey
    event.lastSourceCount = sourceCount
    event.lastTargetKey = targetKey
    event.lastTargetCount = targetCount
end

local function BuildTraceSnapshotLookup(snapshot)
    local lookup = {}
    local _, slot
    for _, slot in ipairs(snapshot and snapshot.slots or {}) do
        lookup[TraceSlotKey(slot.bagID, slot.slotID)] = slot
    end
    return lookup
end

local function TraceCountMapValid(counts)
    if type(counts) ~= "table" then
        return false
    end
    local _, count
    for _, count in pairs(counts) do
        local normalized = NormalizeTraceInteger(count, nil)
        if type(count) ~= "number"
            or not normalized
            or normalized < 1
            or normalized ~= count
        then
            return false
        end
    end
    return true
end

local function TraceSnapshotCountsConsistent(snapshot)
    if type(snapshot) ~= "table"
        or not TraceDenseArrayValid(snapshot.slots)
        or not TraceCountMapValid(snapshot.counts)
        or type(snapshot.poolCounts) ~= "table"
    then
        return false
    end
    local _, storedPoolCounts
    for _, storedPoolCounts in pairs(snapshot.poolCounts) do
        if not TraceCountMapValid(storedPoolCounts) then
            return false
        end
    end
    local counts = {}
    local poolCounts = {}
    local _, slot
    for _, slot in ipairs(snapshot and snapshot.slots or {}) do
        if slot.itemKey then
            if not slot.pool then
                return false
            end
            local itemCount = NormalizeTraceInteger(slot.count, nil)
            if type(slot.count) ~= "number"
                or not itemCount
                or itemCount < 1
                or itemCount ~= slot.count
            then
                return false
            end
            counts[slot.itemKey] = (counts[slot.itemKey] or 0) + itemCount
            if type(poolCounts[slot.pool]) ~= "table" then
                poolCounts[slot.pool] = {}
            end
            local currentPoolCounts = poolCounts[slot.pool]
            currentPoolCounts[slot.itemKey] =
                (currentPoolCounts[slot.itemKey] or 0) + itemCount
        elseif slot.itemKey ~= false or slot.count ~= 0 then
            return false
        end
    end
    local equal = TraceCountsEqual(counts, snapshot and snapshot.counts)
    if not equal then
        return false
    end
    local poolKey, expected
    for poolKey, expected in pairs(poolCounts) do
        equal = TraceCountsEqual(
            expected,
            snapshot.poolCounts and snapshot.poolCounts[poolKey]
        )
        if not equal then
            return false
        end
    end
    for poolKey, expected in pairs(snapshot and snapshot.poolCounts or {}) do
        equal = TraceCountsEqual(poolCounts[poolKey], expected)
        if not equal then
            return false
        end
    end
    return true
end

function RTB:VerifyInventorySortTrace(trace)
    local verdict = {
        countsConserved = false,
        poolIsolation = false,
        planMatches = false,
        groupOrder = false,
        hierarchical = false,
        separators = false,
        oldAtBottom = false,
        cursorEmpty = false,
        topologyStable = false,
        completeSnapshots = false,
        snapshotCounts = false
    }
    if not trace or not trace.before or not trace.after then
        verdict.firstMismatch = "missing snapshot"
        return verdict, false
    end

    local countItem
    verdict.countsConserved, countItem = TraceCountsEqual(
        trace.before.counts,
        trace.after.counts
    )
    if not verdict.countsConserved then
        verdict.firstMismatch = "item count changed: " .. tostring(countItem)
    end

    verdict.poolIsolation = true
    local poolKey, counts
    for poolKey, counts in pairs(trace.before.poolCounts or {}) do
        local equal, itemKey = TraceCountsEqual(
            counts,
            trace.after.poolCounts and trace.after.poolCounts[poolKey]
        )
        if not equal then
            verdict.poolIsolation = false
            verdict.firstMismatch = verdict.firstMismatch
                or ("pool count changed: "
                    .. tostring(poolKey)
                    .. ":"
                    .. tostring(itemKey))
            break
        end
    end
    if verdict.poolIsolation then
        for poolKey, counts in pairs(trace.after.poolCounts or {}) do
            local equal, itemKey = TraceCountsEqual(
                trace.before.poolCounts and trace.before.poolCounts[poolKey],
                counts
            )
            if not equal then
                verdict.poolIsolation = false
                verdict.firstMismatch = verdict.firstMismatch
                    or ("pool count changed: "
                        .. tostring(poolKey)
                        .. ":"
                        .. tostring(itemKey))
                break
            end
        end
    end

    verdict.cursorEmpty = not trace.after.cursorHasItem
    verdict.topologyStable = trace.before.topology == trace.after.topology
    verdict.completeSnapshots = trace.before.unknownCount == 0
        and trace.after.unknownCount == 0
    verdict.snapshotCounts = TraceSnapshotCountsConsistent(trace.before)
        and TraceSnapshotCountsConsistent(trace.after)

    local plan = trace.finalPlan
    if not plan or not TraceDenseArrayValid(plan.pools) then
        verdict.firstMismatch = verdict.firstMismatch or "invalid final plan"
        return verdict, false
    end
    local lookup = BuildTraceSnapshotLookup(trace.after)
    verdict.planMatches = true
    verdict.groupOrder = true
    verdict.hierarchical = true
    verdict.separators = true
    verdict.oldAtBottom = true
    local ranks = { trash = 1, current = 2, old = 3 }
    local expectedSlotCount = 0
    local plannedSlotKeys = {}
    local plannedSlotPools = {}
    local _, pool
    for _, pool in ipairs(plan.pools or {}) do
        local groups = pool.groups or {}
        if not TraceDenseArrayValid(pool.desired)
            or not TraceDenseArrayValid(pool.slots)
            or not TraceDenseArrayValid(groups.trash)
            or not TraceDenseArrayValid(groups.current)
            or not TraceDenseArrayValid(groups.old)
            or #pool.desired ~= #pool.slots
        then
            verdict.completeSnapshots = false
            verdict.planMatches = false
            verdict.firstMismatch = verdict.firstMismatch
                or ("plan length mismatch: " .. tostring(pool.key))
        end
        local previousRank = 0
        local emptySinceItem = false
        local lastItemByRank = {}
        local lastOccupiedRank = 0
        local lastPhysicalRank = 0
        local hasOld = #(pool.groups and pool.groups.old or {}) > 0
        local index, slotRef
        for index, slotRef in ipairs(pool.slots or {}) do
            expectedSlotCount = expectedSlotCount + 1
            local slotKey = TraceSlotKey(slotRef.bagID, slotRef.slotID)
            if plannedSlotKeys[slotKey] then
                verdict.completeSnapshots = false
                verdict.planMatches = false
                verdict.firstMismatch = verdict.firstMismatch
                    or ("duplicate planned slot: " .. slotKey)
            end
            plannedSlotKeys[slotKey] = true
            plannedSlotPools[slotKey] = pool.key
            local actual = lookup[slotKey]
            if not actual then
                verdict.completeSnapshots = false
                verdict.planMatches = false
                verdict.firstMismatch = verdict.firstMismatch
                    or ("missing snapshot slot: "
                        .. slotKey)
            end
            local actualKey = actual and actual.itemKey or false
            if actualKey ~= pool.desired[index] then
                verdict.planMatches = false
                verdict.firstMismatch = verdict.firstMismatch
                    or ("plan mismatch at "
                        .. TraceSlotKey(slotRef.bagID, slotRef.slotID))
            end
            if not actualKey then
                emptySinceItem = true
                lastPhysicalRank = 0
            else
                local metadata = plan.items[actualKey]
                local rank = metadata and ranks[metadata.group] or nil
                if not rank then
                    verdict.groupOrder = false
                    verdict.hierarchical = false
                    verdict.firstMismatch = verdict.firstMismatch
                        or ("unclassified item: " .. tostring(actualKey))
                else
                    if rank < previousRank then
                        verdict.groupOrder = false
                    elseif previousRank > 0
                        and rank > previousRank
                        and not emptySinceItem
                    then
                        verdict.separators = false
                    end
                    if lastItemByRank[rank]
                        and SortItemsHierarchically(metadata, lastItemByRank[rank])
                    then
                        verdict.hierarchical = false
                    end
                    lastItemByRank[rank] = metadata
                    previousRank = rank
                    lastOccupiedRank = rank
                    lastPhysicalRank = rank
                    emptySinceItem = false
                end
            end
        end
        if hasOld
            and (lastOccupiedRank ~= ranks.old
                or lastPhysicalRank ~= ranks.old)
        then
            verdict.oldAtBottom = false
        end
    end
    if #(trace.after.slots or {}) ~= expectedSlotCount
        or #(trace.before.slots or {}) ~= expectedSlotCount
    then
        verdict.completeSnapshots = false
        verdict.firstMismatch = verdict.firstMismatch
            or "snapshot slot count mismatch"
    end
    local _, snapshot
    for _, snapshot in ipairs({ trace.before, trace.after }) do
        local seenSnapshotSlots = {}
        local _, slot
        for _, slot in ipairs(snapshot.slots or {}) do
            local slotKey = TraceSlotKey(slot.bagID, slot.slotID)
            if seenSnapshotSlots[slotKey] or not plannedSlotKeys[slotKey] then
                verdict.completeSnapshots = false
                verdict.planMatches = false
                verdict.firstMismatch = verdict.firstMismatch
                    or ("invalid snapshot slot: " .. slotKey)
            end
            if slot.pool ~= plannedSlotPools[slotKey] then
                verdict.poolIsolation = false
                verdict.firstMismatch = verdict.firstMismatch
                    or ("snapshot pool mismatch: " .. slotKey)
            end
            seenSnapshotSlots[slotKey] = true
        end
    end

    local passed = verdict.countsConserved
        and verdict.poolIsolation
        and verdict.planMatches
        and verdict.groupOrder
        and verdict.hierarchical
        and verdict.separators
        and verdict.oldAtBottom
        and verdict.cursorEmpty
        and verdict.topologyStable
        and verdict.completeSnapshots
        and verdict.snapshotCounts
    return verdict, passed
end

function RTB:CompleteInventorySortTrace(trace, session, message, isError)
    if not trace or trace.status ~= "RUNNING" then
        return
    end
    trace.finishedAt = (time and time()) or trace.startedAt
    trace.duration = session and session.elapsed or 0
    trace.moveCount = session and session.moves or 0
    trace.reason = message
    if session and session.pools then
        self:AttachInventorySortTracePlan(trace, session.pools, false)
    end
    trace.after = self:CaptureInventorySortTraceSnapshot()
    if session and session.pending and session.pending.traceEvent then
        session.pending.traceEvent.result = "UNCONFIRMED"
    end
    local passed
    trace.verdict, passed = self:VerifyInventorySortTrace(trace)
    if isError then
        trace.status = "ABORTED"
    elseif passed then
        trace.status = "PASS"
    else
        trace.status = "FAIL"
        trace.reason = trace.reason
            or (trace.verdict and trace.verdict.firstMismatch)
            or "sort verification failed"
    end
end

function RTB:SetInventorySortTraceEnabled(enabled)
    local store = self:GetInventorySortTraceStore()
    if not store then
        return
    end
    store.enabled = enabled and true or false
    self:Print("Sort log " .. (store.enabled and "enabled." or "disabled."))
end

function RTB:PrintInventorySortTraceStatus()
    local store = self:GetInventorySortTraceStore()
    if not store then
        self:Print("Sort log unavailable.")
        return
    end
    self:Print(
        "Sort log "
            .. (store.enabled and "ON" or "OFF")
            .. ", "
            .. tostring(#store.sessions)
            .. "/"
            .. tostring(self.SORT_TRACE_MAX_SESSIONS)
            .. " sessions."
    )
end

function RTB:PrintLastInventorySortTrace()
    local store = self:GetInventorySortTraceStore()
    local trace = store and store.sessions[#store.sessions]
    if not trace then
        self:Print("No inventory sort log is available.")
        return
    end
    local verdict = type(trace.verdict) == "table" and trace.verdict or {}
    self:Print(
        "Sort log #"
            .. tostring(trace.id)
            .. " "
            .. tostring(trace.status)
            .. ", "
            .. tostring(trace.moveCount or 0)
            .. " moves, counts="
            .. (verdict.countsConserved and "OK" or "FAIL")
            .. ", plan="
            .. (verdict.planMatches and "OK" or "FAIL")
            .. ", groups="
            .. (verdict.groupOrder
                and verdict.hierarchical
                and verdict.separators
                and "OK"
                or "FAIL")
            .. ", cursor="
            .. (verdict.cursorEmpty and "OK" or "FAIL")
            .. "."
    )
    if trace.reason then
        self:Print("Sort log reason: " .. tostring(trace.reason))
    end
end

function RTB:ClearInventorySortTrace()
    if self.SortInProgress then
        self:Print("Cannot clear the sort log while sorting.")
        return false
    end
    local store = self:GetInventorySortTraceStore()
    if not store then
        return false
    end
    store.sessions = {}
    self:Print("Inventory sort log cleared.")
    return true
end

function RTB:InventorySortNeedsConsolidation(pools)
    local _, pool
    for _, pool in ipairs(pools) do
        if pool.needsConsolidation then
            return true
        end
    end
    return false
end

function RTB:FindInventoryConsolidationMove(pools)
    local _, pool
    for _, pool in ipairs(pools) do
        if pool.needsConsolidation then
            local targetIndex, target
            for targetIndex, target in ipairs(pool.slots) do
                if target.itemKey
                    and target.maxStack
                    and target.count < target.maxStack
                then
                    local sourceIndex = #pool.slots
                    while sourceIndex >= 1 do
                        local source = pool.slots[sourceIndex]
                        if sourceIndex ~= targetIndex
                            and source.itemKey == target.itemKey
                        then
                            return source, target, target.maxStack
                        end
                        sourceIndex = sourceIndex - 1
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

function RTB:GetContainerSlotState(slot)
    local texture, count, locked, _, _, _, itemLink =
        GetContainerItemInfo(slot.bagID, slot.slotID)
    if texture and not itemLink then
        return nil, 0, locked and true or false, "unknown"
    end
    if not itemLink then
        return false, 0, locked and true or false, "empty"
    end
    return self:GetItemAgeKey(itemLink) or false,
        math.max(1, tonumber(count) or 1),
        locked and true or false,
        "occupied"
end

function RTB:GetContainerSlotItemKey(slot)
    local itemKey = self:GetContainerSlotState(slot)
    return itemKey
end

function RTB:SwapInventorySlots(source, target)
    if source == target then
        return true
    end
    if not PickupContainerItem then
        return false, "This client does not expose PickupContainerItem."
    end
    if CursorHasItem and CursorHasItem() then
        return false, "The cursor must be empty before sorting."
    end

    PickupContainerItem(source.bagID, source.slotID)
    if not CursorHasItem or not CursorHasItem() then
        return false, "Could not pick up an inventory item."
    end

    PickupContainerItem(target.bagID, target.slotID)
    if CursorHasItem and CursorHasItem() then
        PickupContainerItem(source.bagID, source.slotID)
    end

    if CursorHasItem and CursorHasItem() then
        return false, "Sorting left an item on the cursor."
    end

    return true
end

function RTB:RefreshInventorySortPlan(pools)
    local _, pool
    for _, pool in ipairs(pools) do
        local _, slot
        for _, slot in ipairs(pool.slots) do
            local itemKey, count, _, state = self:GetContainerSlotState(slot)
            if state == "unknown" then
                return false, "Item information is still loading. Try again."
            end
            slot.itemKey = itemKey
            slot.count = count
        end
    end
    return true
end

function RTB:IsInventorySortSlotLocked(slot)
    local _, _, locked = GetContainerItemInfo(slot.bagID, slot.slotID)
    return locked and true or false
end

function RTB:FindNextInventorySortMove(pools)
    local _, pool
    for _, pool in ipairs(pools) do
        local targetIndex
        for targetIndex = 1, #pool.slots do
            local target = pool.slots[targetIndex]
            local desiredKey = pool.desired[targetIndex]
            if target.itemKey ~= desiredKey then
                local sourceIndex = targetIndex + 1
                while sourceIndex <= #pool.slots
                    and pool.slots[sourceIndex].itemKey ~= desiredKey
                do
                    sourceIndex = sourceIndex + 1
                end
                if sourceIndex > #pool.slots then
                    return nil, nil, "The inventory changed while sorting."
                end

                local source = pool.slots[sourceIndex]
                if desiredKey then
                    return source, target
                end
                return target, source
            end
        end
    end
    return nil, nil, nil
end

function RTB:EnsureInventorySortDriver()
    if self.InventorySortDriver then
        return self.InventorySortDriver
    end

    local driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", function(self, elapsed)
        local session = RTB.SortSession
        if not session then
            self:Hide()
            return
        end

        elapsed = tonumber(elapsed) or 0
        session.elapsed = session.elapsed + elapsed
        if session.pending then
            session.pending.elapsed = session.pending.elapsed + elapsed
        end
        self.rtbDelay = (self.rtbDelay or 0) - elapsed
        if self.rtbDelay > 0 then
            return
        end

        self:Hide()
        RTB:ContinueInventorySort()
    end)
    self.InventorySortDriver = driver
    return driver
end

function RTB:ScheduleInventorySort(delay)
    if not self.SortSession then
        return
    end

    local driver = self:EnsureInventorySortDriver()
    delay = math.max(0, tonumber(delay) or 0)
    if driver:IsShown() then
        driver.rtbDelay = math.min(driver.rtbDelay or delay, delay)
    else
        driver.rtbDelay = delay
        driver:Show()
    end
end

function RTB:FinishInventorySort(message, isError)
    local session = self.SortSession
    local driver = self.InventorySortDriver
    if driver then
        driver:Hide()
    end
    if session and session.trace then
        self:CompleteInventorySortTrace(
            session.trace,
            session,
            message,
            isError
        )
        if session.trace.status == "FAIL" then
            isError = true
            message = "Inventory sort verification failed. "
                .. "Use /rtb sortlog last."
        end
    end
    self.SortSession = nil
    self.SortInProgress = false
    self:UpdateItemAgeTracking()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshAll()
    end

    if isError then
        self:Print(message or "Inventory sorting stopped.")
        return false
    end
    if session and session.moves == 0 then
        self:Print("Inventory is already arranged.")
    else
        self:Print(
            message
                or ("Inventory arranged: "
                    .. tostring(session and session.moves or 0)
                    .. " moves.")
        )
    end
    return true
end

function RTB:ContinueInventorySort()
    local session = self.SortSession
    if not session then
        return
    end
    if session.elapsed >= 60 then
        self:FinishInventorySort(
            "Sorting timed out before every slot was confirmed.",
            true
        )
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self:FinishInventorySort("Sorting stopped when combat began.", true)
        return
    end
    if CursorHasItem and CursorHasItem() then
        self:FinishInventorySort(
            "Sorting stopped because an item remained on the cursor.",
            true
        )
        return
    end

    local pending = session.pending
    if pending then
        local actualSourceKey, actualSourceCount, sourceLocked, sourceState =
            self:GetContainerSlotState(pending.source)
        local actualTargetKey, actualTargetCount, targetLocked, targetState =
            self:GetContainerSlotState(pending.target)
        self:ObserveInventorySortTraceMove(
            pending,
            actualSourceKey,
            actualSourceCount,
            sourceLocked,
            sourceState,
            actualTargetKey,
            actualTargetCount,
            targetLocked,
            targetState
        )
        local readable = sourceState ~= "unknown"
            and targetState ~= "unknown"
            and not sourceLocked
            and not targetLocked
        local confirmed = false
        if readable and pending.kind == "consolidate" then
            confirmed = actualSourceKey == pending.expectedSourceKey
                and actualSourceCount == pending.expectedSourceCount
                and actualTargetKey == pending.sourceKey
                and actualTargetCount == pending.expectedTargetCount
        elseif readable then
            confirmed = actualSourceKey == pending.targetKey
                and actualSourceCount == pending.targetCount
                and actualTargetKey == pending.sourceKey
                and actualTargetCount == pending.sourceCount
        end

        if confirmed then
            if pending.traceEvent then
                pending.traceEvent.result = "CONFIRMED"
                pending.traceEvent.confirmedAt = session.elapsed
                pending.traceEvent.actualSourceKey = actualSourceKey
                pending.traceEvent.actualSourceCount = actualSourceCount
                pending.traceEvent.actualTargetKey = actualTargetKey
                pending.traceEvent.actualTargetCount = actualTargetCount
            end
            pending.source.itemKey = actualSourceKey
            pending.source.count = actualSourceCount
            pending.target.itemKey = actualTargetKey
            pending.target.count = actualTargetCount
            session.pending = nil
            session.moves = session.moves + 1
            if pending.kind == "consolidate" then
                local rebuiltPools, rebuildError =
                    self:BuildInventorySortPlan()
                if not rebuiltPools then
                    self:FinishInventorySort(rebuildError, true)
                    return
                end
                session.pools = rebuiltPools
                self:AttachInventorySortTracePlan(
                    session.trace,
                    rebuiltPools,
                    false
                )
                session.topologyFingerprint =
                    rebuiltPools.topologyFingerprint
                session.phase = self:InventorySortNeedsConsolidation(
                    rebuiltPools
                ) and "consolidate" or "arrange"
            end
            self:ScheduleInventorySort(0.05)
            return
        end

        if pending.elapsed >= 5 then
            self:FinishInventorySort(
                "The client did not confirm an inventory move.",
                true
            )
            return
        end

        self:ScheduleInventorySort(0.10)
        return
    end

    if self:GetInventorySortTopologyFingerprint()
        ~= session.topologyFingerprint
    then
        self:FinishInventorySort(
            "Bag layout changed while sorting. Run A-Z again.",
            true
        )
        return
    end

    if session.phase == "consolidate" then
        local refreshed, refreshError =
            self:RefreshInventorySortPlan(session.pools)
        if not refreshed then
            self:FinishInventorySort(refreshError, true)
            return
        end
        local source, target, maxStack =
            self:FindInventoryConsolidationMove(session.pools)
        if not source then
            self:FinishInventorySort(
                "Compatible stacks could not create required separator slots.",
                true
            )
            return
        end
        if self:IsInventorySortSlotLocked(source)
            or self:IsInventorySortSlotLocked(target)
        then
            self:ScheduleInventorySort(0.10)
            return
        end

        local sourceCount = source.count
        local targetCount = target.count
        local movedCount = math.min(
            sourceCount,
            maxStack - targetCount
        )
        local expectedSourceKey = source.itemKey
        if movedCount == sourceCount then
            expectedSourceKey = false
        end
        local pendingMove = {
            kind = "consolidate",
            source = source,
            target = target,
            sourceKey = source.itemKey,
            targetKey = target.itemKey,
            sourceCount = sourceCount,
            targetCount = targetCount,
            expectedSourceKey = expectedSourceKey,
            expectedSourceCount = sourceCount - movedCount,
            expectedTargetCount = targetCount + movedCount,
            elapsed = 0
        }
        self:TraceInventorySortMove(session, pendingMove)
        local ok, err = self:SwapInventorySlots(source, target)
        if not ok then
            if pendingMove.traceEvent then
                pendingMove.traceEvent.result = "FAILED"
                pendingMove.traceEvent.reason = err
            end
            self:FinishInventorySort(err, true)
            return
        end
        session.pending = pendingMove
        self:ScheduleInventorySort(0.10)
        return
    end

    local refreshed, refreshError =
        self:RefreshInventorySortPlan(session.pools)
    if not refreshed then
        self:FinishInventorySort(refreshError, true)
        return
    end
    local source, target, moveError =
        self:FindNextInventorySortMove(session.pools)
    if moveError then
        self:FinishInventorySort(moveError, true)
        return
    end
    if not source then
        self:FinishInventorySort()
        return
    end
    if self:IsInventorySortSlotLocked(source)
        or self:IsInventorySortSlotLocked(target)
    then
        self:ScheduleInventorySort(0.10)
        return
    end

    local sourceKey = source.itemKey
    local targetKey = target.itemKey
    local sourceCount = source.count
    local targetCount = target.count
    local pendingMove = {
        kind = "arrange",
        source = source,
        target = target,
        sourceKey = sourceKey,
        targetKey = targetKey,
        sourceCount = sourceCount,
        targetCount = targetCount,
        elapsed = 0
    }
    self:TraceInventorySortMove(session, pendingMove)
    local ok, err = self:SwapInventorySlots(source, target)
    if not ok then
        if pendingMove.traceEvent then
            pendingMove.traceEvent.result = "FAILED"
            pendingMove.traceEvent.reason = err
        end
        self:FinishInventorySort(err, true)
        return
    end
    session.pending = pendingMove
    self:ScheduleInventorySort(0.10)
end

function RTB:SortInventory()
    if self.SortInProgress then
        self:Print("Inventory sorting is already running.")
        return false
    end
    local trace = self:BeginInventorySortTrace()
    if InCombatLockdown and InCombatLockdown() then
        self:CompleteInventorySortTrace(
            trace,
            nil,
            "Sorting is unavailable during combat.",
            true
        )
        self:Print("Sorting is unavailable during combat.")
        return false
    end
    if CursorHasItem and CursorHasItem() then
        self:CompleteInventorySortTrace(
            trace,
            nil,
            "Clear the cursor before sorting.",
            true
        )
        self:Print("Clear the cursor before sorting.")
        return false
    end

    local pools, planError = self:BuildInventorySortPlan()
    if not pools then
        self:CompleteInventorySortTrace(trace, nil, planError, true)
        self:Print(planError)
        return false
    end
    self:AttachInventorySortTracePlan(trace, pools, true)

    self.SortSession = {
        pools = pools,
        trace = trace,
        topologyFingerprint = pools.topologyFingerprint,
        moves = 0,
        elapsed = 0,
        pending = nil,
        phase = self:InventorySortNeedsConsolidation(pools)
            and "consolidate"
            or "arrange"
    }
    self.SortInProgress = true
    self:ScheduleInventorySort(0)
    return true
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
    self:UpdateItemAgeTracking()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:RefreshAll()
    end
end

function RTB:BAG_UPDATE()
    if self.SortSession then
        self:ScheduleInventorySort(0.05)
    end
    self:UpdateItemAgeTracking()
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
    if self.SortSession then
        self:ScheduleInventorySort(0.05)
    end
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
    if command == "sort" or command == "arrange" then
        RTB:SortInventory()
    elseif command == "sortlog on" then
        RTB:SetInventorySortTraceEnabled(true)
    elseif command == "sortlog off" then
        RTB:SetInventorySortTraceEnabled(false)
    elseif command == "sortlog last" then
        RTB:PrintLastInventorySortTrace()
    elseif command == "sortlog clear" then
        RTB:ClearInventorySortTrace()
    elseif command == "sortlog" or command == "sortlog status" then
        RTB:PrintInventorySortTraceStatus()
    elseif command == "version" then
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
        RTB:Print("/rtb sort = arrange inventory")
        RTB:Print("/rtb sortlog on|off = enable or disable persistent sort logs")
        RTB:Print("/rtb sortlog last = print the last sort verdict")
        RTB:Print("/rtb sortlog status|clear = inspect or clear sort logs")
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
