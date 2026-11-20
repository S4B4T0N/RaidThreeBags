-- Lua 5.1 behavior tests, loading the real core and profession modules.
-- Does not emulate WoW's secure execution engine or server disenchant tables.
local source = assert(arg[1], "source directory is required")
local now, combat, cursor, moving, dead, targeting = 100, false, false, 0, false, false
local casting, lootCount = false, 0
local enchanting, learned, collapsed, knownEnchantRank = true, true, false, 7411
local bags, sizes, itemInfo, frames, messages = {}, {}, {}, {}, {}
local namedFrames = {}
local protectedWrites, dispatched, stopActions = 0, 0, 0
local rejectTarget = false
local Widget = {}
local function Guard(frame)
    if frame.secure then
        assert(not combat, "protected frame write in combat")
        protectedWrites = protectedWrites + 1
    end
end
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:SetScript(event, handler) self.scripts[event] = handler end
function Widget:SetAttribute(key, value) Guard(self); self.attributes[key] = value end
function Widget:GetAttribute(key) return self.attributes[key] end
function Widget:RegisterForClicks(...) self.clicks = {...} end
function Widget:Show() Guard(self); self.shown = true end
function Widget:Hide() Guard(self); self.shown = false end
function Widget:IsShown() return self.shown end
function Widget:GetLeft() return self.left end
function Widget:GetBottom() return self.bottom end
function Widget:GetEffectiveScale() return self.scale or 1 end
function Widget:ClearAllPoints() Guard(self); self.point = nil end
function Widget:SetPoint(...) Guard(self); self.point = {...} end
function Widget:SetWidth(value) Guard(self); self.width = value end
function Widget:SetHeight(value) Guard(self); self.height = value end
function Widget:GetFrameStrata() return self.strata or "MEDIUM" end
function Widget:SetFrameStrata(value) Guard(self); self.strata = value end
function Widget:GetFrameLevel() return self.level or 1 end
function Widget:SetFrameLevel(value) Guard(self); self.level = value end
function Widget:SetAlpha(value) Guard(self); self.alpha = value end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({name=name, parent=parent, template=template,
        secure=template == "SecureActionButtonTemplate", shown=true,
        events={}, scripts={}, attributes={}}, {__index=Widget})
    frames[#frames+1] = frame
    if name then namedFrames[name] = frame end
    return frame
end
UIParent = CreateFrame("Frame")
SlashCmdList = {}
BACKPACK_CONTAINER, NUM_BAG_SLOTS, BANK_CONTAINER = 0, 4, -1
DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) messages[#messages+1] = message end}
RaidThreeUIStyle = {CreateSquareIconChrome=function(_, button, icon)
    button.icon = icon; button:SetWidth(30); button:SetHeight(30)
end}
GameTooltip = {
    SetOwner=function(self, owner) self.owner=owner end,
    IsOwned=function(self, owner) return self.owner == owner end,
    SetText=function() end, AddLine=function() end, Show=function() end, Hide=function() end
}
function RegisterStateDriver(frame, state, expression)
    Guard(frame)
    assert(state == "visibility")
    frame.visibility = expression
    frame.shown = expression ~= "hide" and not combat
end
function GetTime() return now end
function InCombatLockdown() return combat end
function CursorHasItem() return cursor end
function SpellIsTargeting() return targeting end
function UnitIsDeadOrGhost() return dead end
function GetUnitSpeed() return moving end
function UnitCastingInfo() return casting and "Casting" or nil end
function UnitChannelInfo() return nil end
function GetNumLootItems() return lootCount end
function GetSpellInfo(id)
    local names = {[7411]="Enchanting", [13262]="Disenchant",
        [25229]="Jewelcrafting", [31252]="Prospecting"}
    return names[id], nil, "SpellIcon"
end
function GetNumSkillLines() return collapsed and 0 or (enchanting and 3 or 2) end
function GetSkillLineInfo(index)
    if index == 1 then return "Professions", true, false, 0 end
    if index == 2 then return "Jewelcrafting", false, false, 450, 0, 0 end
    return "Enchanting", false, false, 450, 0, 0
end
function IsSpellKnown(id)
    return id == 25229 or id == 31252
        or (enchanting and (id == knownEnchantRank or (id == 13262 and learned)))
end
function GetContainerNumSlots(bag) return sizes[bag] or 0 end
function GetContainerNumFreeSlots() return 0, 0 end
function GetContainerItemInfo(bag, slot)
    local item = bags[bag] and bags[bag][slot]
    if not item then return nil end
    return "ItemIcon", item.count, item.locked, item.slotQuality, false, false,
        not item.unknown and item.link or nil
end
function GetContainerItemLink(bag, slot)
    local item = bags[bag] and bags[bag][slot]
    return item and item.link
end
function GetItemInfo(link)
    local item = itemInfo[link]
    if not item or item.uncached then return nil end
    return "Item", link, item.quality, 100, 1, "Armor", "Cloth", 20, item.equip
end
function CastSpellByName() error("direct spell cast") end
function CastSpellByID() error("direct spell cast") end
function RunMacroText() error("insecure macro execution") end
function UseContainerItem() error("direct item use") end
function UseInventoryItem() error("unexpected equipped-item use") end
function EquipItemByName() error("unexpected item equip") end
function PickupContainerItem() error("unexpected inventory mutation") end

assert(loadfile(source .. "/RaidThreeBags.lua"))()
local RTB = RaidThreeBags
RTB:InitializeDB()
assert(loadfile(source .. "/RTB_Prospect.lua"))()
local prospectDriver = frames[#frames]
assert(loadfile(source .. "/RTB_Disenchant.lua"))()
local disenchantDriver = frames[#frames]
RTB.MainFrame = CreateFrame("Frame")
RTB.InventoryProspectAnchor = CreateFrame("Frame", nil, RTB.MainFrame)
RTB.InventoryProspectAnchor.left, RTB.InventoryProspectAnchor.bottom = 160, 200
RTB.InventoryDisenchantAnchor = CreateFrame("Frame", nil, RTB.MainFrame)
RTB.InventoryDisenchantAnchor.left, RTB.InventoryDisenchantAnchor.bottom = 126, 200

local function Reset()
    bags, sizes, itemInfo = {}, {}, {}
    combat, cursor, moving, dead, targeting = false, false, 0, false, false
    casting, lootCount = false, 0
    rejectTarget = false
    enchanting, learned, collapsed, knownEnchantRank = true, true, false, 7411
    RTB.DisenchantPending, RTB.DisenchantSkipped, RTB.DisenchantTopology = nil, nil, nil
    RTB.ProspectPending, RTB.ProspectSkipped, RTB.ProspectMergeSession = nil, nil, nil
    RTB.ProspectLootOpen = false
    RTB.SortInProgress, RTB.SortSession, RTB.TransferSession = false, nil, nil
    RTB.MainFrame.shown = true
    RTB:SetDisenchantingEnabled(true)
    RTB:SetDisenchantBlueEnabled(false)
    RTB:SetProspectingEnabled(true)
end
local function Put(bag, slot, id, quality, equip, count, suffix)
    local link = "item:" .. id .. ":" .. (suffix or "0")
    local item = {link=link, quality=quality, slotQuality=quality,
        equip=equip or "INVTYPE_HEAD", count=count or 1}
    bags[bag] = bags[bag] or {}
    bags[bag][slot] = item
    sizes[bag] = math.max(sizes[bag] or 0, slot)
    itemInfo[link] = item
    return item
end
local function Click(mouse)
    RTB:RefreshDisenchanting()
    local button = assert(RTB.DisenchantButton)
    button.scripts.PreClick(button, mouse or "LeftButton")
    local selected
    if button:GetAttribute("type") then
        assert(button:GetAttribute("type") == "macro", "visible action must use bounded secure helper macro")
        assert(button:GetAttribute("macrotext") ==
            "/click RaidThreeBagsDisenchantCast\n/click RaidThreeBagsDisenchantStop",
            "visible macro must cast once and then clear targeting")
        local cast = assert(namedFrames.RaidThreeBagsDisenchantCast)
        local stop = assert(namedFrames.RaidThreeBagsDisenchantStop)
        assert(cast.parent == UIParent and stop.parent == UIParent)
        assert(cast.template == "SecureActionButtonTemplate" and stop.template == "SecureActionButtonTemplate")
        assert(cast:GetAttribute("type") == "spell" and cast:GetAttribute("spell") == "Disenchant")
        assert(stop:GetAttribute("type") == "stop")
        dispatched = dispatched + 1
        selected = {bagID=cast:GetAttribute("target-bag"), slotID=cast:GetAttribute("target-slot")}
        -- Simulate the native secure handlers: a rejected item target can leave
        -- the spell targeting cursor active until the second helper runs.
        if rejectTarget then targeting = true end
        targeting = false
        stopActions = stopActions + 1
    end
    button.scripts.PostClick(button, mouse or "LeftButton")
    assert(not button:GetAttribute("type"), "secure action left armed")
    assert(not button:GetAttribute("macrotext"), "secure macro left armed")
    local cast = namedFrames.RaidThreeBagsDisenchantCast
    if cast then
        assert(not cast:GetAttribute("type") and not cast:GetAttribute("target-bag")
            and not cast:GetAttribute("target-slot"), "hidden destructive action left armed")
    end
    return selected
end
local function Tick(seconds)
    now = now + (seconds or 0.2)
    prospectDriver.scripts.OnUpdate(prospectDriver, seconds or 0.2)
    disenchantDriver.scripts.OnUpdate(disenchantDriver, seconds or 0.2)
end

assert(RTB:GetDisenchantingEnabled(), "DE must default enabled")
assert(not RTB:GetDisenchantBlueEnabled(), "blue selection must default OFF")
RTB:SetDisenchantBlueEnabled(true)
RTB:SetDisenchantingEnabled(false)
RTB:InitializeDB()
assert(RTB:GetDisenchantBlueEnabled() and not RTB:GetDisenchantingEnabled(),
    "DE preferences did not persist")
Reset()

-- Default green selection skips blue and epic, including at the first slot.
Put(0, 1, 1001, 4)
Put(0, 2, 1002, 3)
Put(4, 1, 1003, 2, "INVTYPE_WEAPON")
local target, count = RTB:FindDisenchantTarget()
assert(target.bagID == 4 and count == 1, "default selection included non-green gear")
RTB:SetDisenchantBlueEnabled(true)
target, count = RTB:FindDisenchantTarget()
assert(target.slotID == 2 and target.bagID == 0 and count == 2)
for quality = 0, 7 do
    Reset()
    Put(0, 1, 1100 + quality, quality)
    RTB:SetDisenchantBlueEnabled(true)
    RTB.DB.disenchantEpicEnabled = true -- edited data must not bypass code predicate
    RTB.DB.disenchantQuality = quality
    assert((RTB:FindDisenchantTarget() ~= nil) == (quality == 2 or quality == 3),
        "hard quality restriction failed for quality " .. quality)
end

Reset()
Put(-1, 1, 1201, 2)
Put(5, 1, 1202, 2)
Put(-2, 1, 1203, 2)
assert(not RTB:FindDisenchantTarget(), "bank/keyring was scanned")
assert(not RTB:ReadDisenchantCandidate({bagID=-1, slotID=1}))
assert(not RTB:ReadDisenchantCandidate({bagID=5, slotID=1}))
-- Equipped inventory is a separate API and is deliberately never queried.
function GetInventoryItemLink() error("equipped items must never be scanned") end
assert(not RTB:ReadDisenchantCandidate({bagID=-2, slotID=1}))
GetInventoryItemLink = nil

local acceptedLocations = {"INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER",
    "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
    "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK",
    "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND",
    "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT",
    "INVTYPE_THROWN", "INVTYPE_RELIC"}
for _, location in ipairs(acceptedLocations) do
    Reset(); Put(0, 1, 1300, 2, location)
    assert(RTB:FindDisenchantTarget(), "wearable location rejected: " .. location)
end
for _, location in ipairs({"", "INVTYPE_BAG", "INVTYPE_QUIVER", "INVTYPE_AMMO",
    "INVTYPE_BODY", "INVTYPE_TABARD", "UNKNOWN"}) do
    Reset(); Put(0, 1, 1300, 2, location)
    assert(not RTB:FindDisenchantTarget(), "nonwearable location accepted: " .. location)
end

-- Missing/contradictory cache or a stacked item cannot authorize destruction.
local invalidators = {
    function(item) item.locked = true end,
    function(item) item.unknown = true end,
    function(item) item.uncached = true end,
    function(item) item.slotQuality = 4 end,
    function(item) item.slotQuality = nil end,
    function(item) item.count = 2 end
}
for _, invalidate in ipairs(invalidators) do
    Reset(); local item = Put(0, 1, 1400, 2); invalidate(item)
    Put(4, 1, 1401, 2)
    assert(RTB:FindDisenchantTarget().bagID == 4, "invalid first item trapped candidate scan")
end

-- Full item links are revalidated after selection, including same-ID variants.
for _, replacement in ipairs({{id=1501, quality=4}, {id=1500, quality=2, suffix="77"}}) do
    Reset(); Put(0, 1, 1500, 2)
    RTB:RefreshDisenchanting()
    local original = RTB.ReadDisenchantCandidate
    local calls = 0
    RTB.ReadDisenchantCandidate = function(self, slot)
        local candidate = original(self, slot)
        calls = calls + 1
        if calls == 1 then Put(0, 1, replacement.id, replacement.quality, nil, 1, replacement.suffix) end
        return candidate
    end
    local button = RTB.DisenchantButton
    button.scripts.PreClick(button, "LeftButton")
    assert(not button:GetAttribute("type") and not RTB.DisenchantPending,
        "changed item was exposed to a destructive secure action")
    RTB.ReadDisenchantCandidate = original
end

Reset(); Put(0, 1, 1600, 2)
enchanting = false
RTB:RefreshDisenchanting()
assert(not RTB:FindDisenchantTarget() and RTB.DisenchantButton.visibility == "hide")
enchanting, learned = true, false
RTB:RefreshDisenchanting()
assert(not RTB:FindDisenchantTarget() and RTB.DisenchantButton.visibility ~= "hide")
learned, collapsed = true, true
for _, rank in ipairs({7411, 7412, 7413, 13920, 28029, 51313}) do
    knownEnchantRank = rank
    assert(RTB:HasEnchanting(), "collapsed profession rank not recognized")
end

Reset(); Put(0, 1, 1700, 2); Put(4, 1, 1701, 2)
RTB:RefreshDisenchanting()
local button = RTB.DisenchantButton
assert(button.parent == UIParent and button.point[2] == UIParent)
assert(button.width == 30 and button.height == 30)
local beforeBackground = dispatched
Tick(); RTB:OnDisenchantEvent("BAG_UPDATE", 0)
assert(dispatched == beforeBackground and not button:GetAttribute("type"))
assert(Click().bagID == 0)
casting = true
assert(not Click(), "DE permitted second action during cast")
casting = false
bags[0][1] = nil
RTB:OnDisenchantEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Disenchant")
lootCount = 1; RTB:OnProspectingEvent("LOOT_OPENED")
Tick(4)
assert(not Click() and RTB.DisenchantPending, "DE ignored outstanding loot")
lootCount = 0; RTB:OnProspectingEvent("LOOT_CLOSED")
RTB:OnDisenchantEvent("LOOT_CLOSED")
assert(not RTB.DisenchantPending and Click().bagID == 4)

Reset(); Put(0, 1, 1800, 2); Put(4, 1, 1801, 2)
assert(Click().bagID == 0)
RTB:OnDisenchantEvent("UNIT_SPELLCAST_FAILED", "party1", "Disenchant")
RTB:OnDisenchantEvent("UNIT_SPELLCAST_FAILED", "player", "Other spell")
assert(RTB.DisenchantPending, "unrelated event cleared DE action")
RTB:OnDisenchantEvent("UNIT_SPELLCAST_FAILED", "player", "Disenchant")
assert(Click().bagID == 4)
RTB:OnDisenchantEvent("UNIT_SPELLCAST_FAILED", "player", "Disenchant")
assert(not Click() and not next(RTB.DisenchantSkipped), "completed failed pass not acknowledged")
assert(Click().bagID == 0)
RTB:OnDisenchantEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Disenchant")
assert(Click().bagID == 0, "interrupted item was permanently skipped")
now = now + 31
RTB:UpdateDisenchantPending()
assert(not RTB.DisenchantPending and RTB:FindDisenchantTarget().bagID == 4)
assert(not Click("RightButton") and not next(RTB.DisenchantSkipped))

-- A rejected native spell target must still execute secure cursor cleanup.
-- No fallback use/equip action is permitted and no item is mutated by addon code.
Reset(); Put(0, 1, 1850, 2); Put(4, 1, 1851, 2)
rejectTarget = true
local beforeStop = stopActions
assert(Click().bagID == 0)
assert(stopActions == beforeStop + 1 and not targeting,
    "rejected target did not execute the secure stop helper")
assert(bags[0][1].count == 1 and bags[4][1].count == 1)
RTB:OnDisenchantEvent("UNIT_SPELLCAST_FAILED", "player", "Disenchant")
rejectTarget = false
assert(Click().bagID == 4, "failed item did not advance after cursor cleanup")

-- A DE action excludes every competing inventory/profession action.
Reset(); Put(0, 1, 1900, 2); Put(1, 1, 2770, 1, "", 2); Put(4, 1, 2770, 1, "", 3)
assert(Click())
assert(RTB:IsDisenchantingBusy() and RTB:IsProspectingBusy())
RTB:SortInventory(); RTB:SortBank(); RTB:TransferRecentItems("bags-to-bank")
assert(not RTB.SortSession and not RTB.TransferSession)
RTB:RefreshProspecting()
RTB:PrepareProspectingClick(RTB.ProspectButton, "LeftButton")
assert(not RTB.ProspectButton:GetAttribute("type") and not RTB.ProspectMergeSession)
assert(not RTB:BeginProspectingMerge(), "merge began while disenchanting")

local blockers = {
    function(value) RTB.ProspectPending = value and {started=now,bagID=3,slotID=1,itemKey="2770",count=5} or nil end,
    function(value) RTB.ProspectMergeSession = value and {} or nil end,
    function(value) RTB.SortInProgress = value end,
    function(value) RTB.TransferSession = value and {} or nil end,
    function(value) casting = value end,
    function(value) lootCount = value and 1 or 0 end,
    function(value) cursor = value end,
    function(value) targeting = value end,
    function(value) moving = value and 1 or 0 end,
    function(value) dead = value end,
    function(value) RTB.MainFrame.shown = not value end,
    function(value) RTB:SetDisenchantingEnabled(not value) end
}
for _, block in ipairs(blockers) do
    Reset(); Put(0, 1, 2000, 2)
    block(true)
    assert(not Click() and not RTB.DisenchantPending, "blocked DE armed an action")
    block(false)
end

Reset(); Put(0, 1, 2100, 2)
RTB:RefreshDisenchanting()
combat = true
button.shown = false -- engine-managed visibility, not insecure addon mutation
local beforeCombat = protectedWrites
RTB:SetDisenchantingEnabled(false)
RTB:SetDisenchantBlueEnabled(true)
Tick()
button.scripts.PreClick(button, "LeftButton")
button.scripts.PostClick(button, "LeftButton")
assert(protectedWrites == beforeCombat and not button:GetAttribute("type"))
assert(not RTB.DisenchantPending)
combat = false
RTB:OnDisenchantEvent("PLAYER_REGEN_ENABLED")
assert(button.visibility == "hide")
RTB:SetDisenchantingEnabled(true)
assert(button.visibility ~= "hide")

print("DISENCHANT LOGIC OK")
