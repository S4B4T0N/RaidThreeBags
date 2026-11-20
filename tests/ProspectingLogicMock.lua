-- Behavior checks for WoW 3.3.5a prospecting under PUC Lua 5.1.
-- This harness does not emulate the client's secure execution engine.
local source = assert(arg[1], "source directory is required")
local now, combat, moving, dead, cursor, targeting = 100, false, 0, false, false, false
local casting, lootCount, profession, skill = false, 0, true, 450
local collapsed, learned = false, true
local bags, sizes, frames, messages = {}, {}, {}, {}
local secureWrites, attemptedActions = 0, 0
local heldItem, visibleBags, allowPickup, rejectMerge = nil, nil, false, false
local pickupCalls, families, unavailableInfo = 0, {}, false

local function Guard(frame)
    if frame.secure then
        assert(not combat, "insecure protected-frame write during combat")
        secureWrites = secureWrites + 1
    end
end

local Widget = {}
function Widget:RegisterEvent(event) self.events[event] = true end
function Widget:SetScript(event, handler) self.scripts[event] = handler end
function Widget:SetAttribute(key, value) Guard(self); self.attributes[key] = value end
function Widget:GetAttribute(key) return self.attributes[key] end
function Widget:RegisterForClicks(...) self.clicks = {...} end
function Widget:Hide() Guard(self); self.shown = false end
function Widget:Show() Guard(self); self.shown = true end
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
    local frame = setmetatable({kind=kind, name=name, parent=parent,
        template=template, secure=template == "SecureActionButtonTemplate",
        shown=true, scripts={}, events={}, attributes={}}, {__index=Widget})
    frames[#frames+1] = frame
    return frame
end
UIParent = CreateFrame("Frame")
UIParent.scale = 0.8
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(_, message) messages[#messages+1] = message end}
BACKPACK_CONTAINER, NUM_BAG_SLOTS, BANK_CONTAINER = 0, 4, -1
RaidThreeUIStyle = {CreateSquareIconChrome=function(_, button, icon)
    button.icon = icon; button:SetWidth(30); button:SetHeight(30)
end}
GameTooltip = {
    SetOwner=function(self, owner) self.owner=owner end,
    IsOwned=function(self, owner) return self.owner == owner end,
    SetText=function() end, AddLine=function() end,
    Show=function() end, Hide=function() end
}
function RegisterStateDriver(frame, state, expression)
    Guard(frame)
    assert(state == "visibility")
    frame.visibility = expression
    frame.shown = expression ~= "hide" and not combat
end
function GetTime() return now end
function GetSpellInfo(id)
    if id == 25229 then return "Jewelcrafting" end
    if id == 31252 then return "Prospecting", nil, "ProspectIcon" end
end
function GetNumSkillLines() return (profession and not collapsed) and 2 or 0 end
function GetSkillLineInfo(index)
    if index == 1 then return "Professions", true, false, 0 end
    return "Jewelcrafting", false, false, skill, 0, 0
end
function IsSpellKnown(id)
    return (id == 31252 and learned and profession)
        or (id == 25229 and profession)
end
function UnitCastingInfo() return casting and "Prospecting" or nil end
function UnitChannelInfo() return nil end
function GetNumLootItems() return lootCount end
function InCombatLockdown() return combat end
function CursorHasItem() return cursor or heldItem ~= nil end
function SpellIsTargeting() return targeting end
function UnitIsDeadOrGhost() return dead end
function GetUnitSpeed() return moving end
function GetContainerNumSlots(bag) return sizes[bag] or 0 end
function GetContainerNumFreeSlots(bag) return 0, families[bag] or 0 end
function GetContainerItemInfo(bag, slot)
    local view = visibleBags or bags
    local item = view[bag] and view[bag][slot]
    if not item then return nil end
    return "ItemIcon", item.count, item.locked, 1, false, false,
        not item.unknown and ("item:" .. item.id) or nil
end
function GetItemInfo(link)
    if unavailableInfo or not link then return nil end
    return "Ore", link, 1, 1, 1, "Trade Goods", "Metal & Stone", 20
end
function GetContainerItemLink(bag, slot)
    local item = bags[bag] and bags[bag][slot]
    return item and ("item:" .. item.id) or nil
end
function CastSpellByName() error("addon attempted direct spell cast") end
function CastSpellByID() error("addon attempted direct spell cast") end
function UseContainerItem() error("addon attempted direct item use") end
function PickupContainerItem(bag, slot)
    assert(allowPickup, "inventory mutation outside an explicit merge test")
    assert(not combat and not cursor, "pickup in unsafe state")
    pickupCalls = pickupCalls + 1
    bags[bag] = bags[bag] or {}
    local destination = bags[bag][slot]
    if not heldItem then
        heldItem, bags[bag][slot] = destination, nil
    elseif not destination then
        bags[bag][slot], heldItem = heldItem, nil
    elseif not rejectMerge and destination.id == heldItem.id then
        assert(destination.count + heldItem.count <= 20, "merge would overflow stack")
        destination.count = destination.count + heldItem.count
        heldItem = nil
    elseif not rejectMerge then
        heldItem, bags[bag][slot] = destination, heldItem
    end
end

assert(loadfile(source .. "/RaidThreeBags.lua"))()
local RTB = RaidThreeBags
RTB:InitializeDB()
assert(loadfile(source .. "/RTB_Prospect.lua"))()
local driver = frames[#frames]
RTB.MainFrame = CreateFrame("Frame")
RTB.InventoryProspectAnchor = CreateFrame("Frame", nil, RTB.MainFrame)
RTB.InventoryProspectAnchor.left, RTB.InventoryProspectAnchor.bottom = 120, 240
RTB.InventoryProspectAnchor.scale = 1.2

local function Reset()
    RTB.ProfessionWindowInteraction = nil
    bags, sizes = {}, {}
    profession, skill, learned, collapsed = true, 450, true, false
    casting, lootCount, moving, dead, cursor, targeting = false, 0, 0, false, false, false
    combat = false
    RTB.ProspectPending, RTB.ProspectSkipped, RTB.ProspectLootOpen = nil, nil, false
    RTB.SortSession, RTB.TransferSession, RTB.SortInProgress = nil, nil, false
    RTB.ProspectTopology = nil
    RTB.ProspectMergeSession = nil
    heldItem, visibleBags, allowPickup, rejectMerge = nil, nil, false, false
    pickupCalls, families, unavailableInfo = 0, {}, false
    RTB.MainFrame.shown = true
    RTB:SetProspectingEnabled(true)
    if RTB.SetProspectingAutoMerge then RTB:SetProspectingAutoMerge(true) end
end
local function Put(bag, slot, id, count, locked, unknown)
    bags[bag] = bags[bag] or {}
    sizes[bag] = math.max(sizes[bag] or 0, slot)
    bags[bag][slot] = {id=id, count=count, locked=locked, unknown=unknown}
end
local function Click(mouse)
    RTB:RefreshProspecting()
    local button = assert(RTB.ProspectButton)
    button.scripts.PreClick(button, mouse or "LeftButton")
    local selected
    if button:GetAttribute("type") == "spell" then
        attemptedActions = attemptedActions + 1
        assert(button:GetAttribute("spell") == "Prospecting")
        selected = {bagID=button:GetAttribute("target-bag"),
            slotID=button:GetAttribute("target-slot")}
    end
    button.scripts.PostClick(button, mouse or "LeftButton")
    assert(not button:GetAttribute("type"), "cast attribute leaked after click")
    return selected
end

assert(RTB:GetProspectingEnabled(), "prospecting must default on")
RTB:SetProspectingEnabled(false)
RTB:InitializeDB()
assert(not RTB:GetProspectingEnabled(), "OFF did not survive database initialization")
assert(RTB.DB == RaidThreeBagsDB, "setting must use authoritative saved database")
Reset()

-- Shared traversal includes every physical slot, empty bags, and final bag.
sizes = {[0]=2, [1]=0, [2]=1, [3]=0, [4]=2}
local coordinates = {}
for bag, slot in RTB:IterateContainerSlots(RTB.BAG_IDS) do
    coordinates[#coordinates+1] = bag .. ":" .. slot
end
assert(table.concat(coordinates, ",") == "0:1,0:2,2:1,4:1,4:2")
Put(0, 1, 2770, 4)
Put(0, 2, 99999, 20)
Put(2, 1, 2771, 20, true)
Put(4, 1, 2772, 20, false, true)
Put(4, 2, 36912, 20)
RTB.DB.settings.invisibleBagFamilies[1024] = true
local target, batches = RTB:FindProspectingTarget()
assert(target.bagID == 4 and target.slotID == 2 and batches == 4,
    "must skip bad slots and reach eligible ore in final/hidden bag")
skill = 399
assert(not RTB:FindProspectingTarget(), "insufficient skill ore was selected")
skill = 450

-- Every supported WotLK ore obeys its exact profession threshold.
local oreRanks = {
    {2770, 1}, {2771, 50}, {2772, 125}, {3858, 175}, {10620, 250},
    {23424, 275}, {23425, 325}, {36909, 350}, {36912, 400}, {36910, 450}
}
for _, entry in ipairs(oreRanks) do
    bags, sizes = {}, {}
    Put(0, 1, entry[1], 5)
    skill = entry[2] - 1
    assert(not RTB:FindProspectingTarget(), "ore accepted below required rank")
    skill = entry[2]
    assert(RTB:FindProspectingTarget(), "ore rejected at required rank")
end
Reset()
Put(0, 1, 2770, 5, true)
assert(not RTB:FindProspectingTarget())
bags[0][1].locked = false
assert(RTB:FindProspectingTarget(), "temporary lock permanently excluded ore")
bags[0][1].unknown = true
assert(not RTB:FindProspectingTarget())
bags[0][1].unknown = false
assert(RTB:FindProspectingTarget(), "uncached slot was not retried after loading")

-- Secure button is detached from movable bag frames and follows physical scale.
RTB:RefreshProspecting()
local button = assert(RTB.ProspectButton)
assert(button.parent == UIParent and button.template == "SecureActionButtonTemplate")
assert(button.point[2] == UIParent and button.point[1] == "BOTTOMLEFT")
assert(math.abs(button.width - 45) < 0.0001 and math.abs(button.point[4] - 180) < 0.0001)
assert(button.visibility == "[combat] hide; show")
local beforeActions = attemptedActions
driver.scripts.OnUpdate(driver, 1)
RTB:OnProspectingEvent("BAG_UPDATE", 4)
assert(attemptedActions == beforeActions and not button:GetAttribute("type"),
    "background refresh armed or invoked a spell")
profession = false
RTB:RefreshProspecting()
assert(button.visibility == "hide", "button visible without Jewelcrafting")
profession, learned = true, false
RTB:RefreshProspecting()
assert(button.visibility ~= "hide" and not RTB:FindProspectingTarget(),
    "novice Jewelcrafting should show button but require training")
learned, collapsed = true, true
assert(RTB:GetJewelcraftingSkill(), "collapsed skill line lost profession")
collapsed = false

-- Recheck exact bag/slot immediately before dispatch, including moved items.
Reset()
Put(0, 1, 2770, 5)
RTB:RefreshProspecting()
bags[0][1] = nil
Put(4, 3, 2770, 5)
target = Click()
assert(target.bagID == 4 and target.slotID == 3, "stale coordinates used on click")

-- Four explicit clicks consume a 20-stack; casts and loot block extra clicks.
Reset()
Put(0, 1, 2770, 20)
Put(4, 1, 2771, 5)
for batch = 1, 4 do
    target = Click()
    assert(target and target.bagID == 0, "20-stack was not kept until exhausted")
    casting = true
    assert(not Click(), "additional cast permitted during existing cast")
    casting = false
    bags[0][1].count = bags[0][1].count - 5
    if bags[0][1].count == 0 then bags[0][1] = nil end
    RTB:OnProspectingEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Prospecting")
    lootCount = 1
    RTB:OnProspectingEvent("LOOT_OPENED")
    now = now + 4
    assert(not Click(), "additional cast permitted with prospect loot open")
    lootCount = 0
    RTB:OnProspectingEvent("LOOT_CLOSED")
    assert(not RTB.ProspectPending, "completed batch did not release pending action")
end
target = Click()
assert(target and target.bagID == 4, "finished stack did not advance to next bag")

-- Rejected exact stack is skipped; unrelated events cannot corrupt selection.
Reset()
Put(0, 1, 2770, 10)
Put(4, 1, 2771, 5)
assert(Click().bagID == 0)
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "party1", "Prospecting")
assert(RTB.ProspectPending, "other player's event cleared our action")
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "player", "Other spell")
assert(RTB.ProspectPending, "unrelated spell event cleared our action")
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "player", "Prospecting")
assert(Click().bagID == 4, "failed slot trapped scan before final bag")
RTB:OnProspectingEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Prospecting")
assert(not Click("RightButton"), "retry click must never cast")
assert(Click().bagID == 0, "right-click did not reset failed-slot exclusion")
RTB:OnProspectingEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Prospecting")
assert(Click().bagID == 0, "interruption permanently skipped a valid stack")
moving = 1
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "player", "Prospecting")
moving = 0
assert(Click().bagID == 0, "movement failure permanently skipped valid ore")
now = now + 31
RTB:UpdateProspectingPending()
assert(not RTB.ProspectPending and RTB:FindProspectingTarget().bagID == 4,
    "timeout did not allow bounded recovery")

-- A completely rejected pass ends without dispatching; the following click
-- retries from the first physical slot rather than trapping the user forever.
Reset()
Put(0, 1, 2770, 5)
Put(4, 1, 2771, 5)
assert(Click().bagID == 0)
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "player", "Prospecting")
assert(Click().bagID == 4)
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "player", "Prospecting")
assert(not RTB:FindProspectingTarget(), "failed signatures escaped current pass")
local beforePassEnd = attemptedActions
assert(not Click(), "pass acknowledgement must not dispatch a cast")
assert(attemptedActions == beforePassEnd and not next(RTB.ProspectSkipped),
    "pass acknowledgement did not clear skipped signatures")
assert(Click().bagID == 0, "next pass did not retry the first slot")
RTB:OnProspectingEvent("UNIT_SPELLCAST_FAILED", "player", "Prospecting")
assert(RTB:FindProspectingTarget().bagID == 4)
sizes[3] = 1 -- inserting another equipped bag invalidates old slot snapshots
assert(RTB:FindProspectingTarget().bagID == 0,
    "bag topology change retained the old skipped snapshot")
assert(not next(RTB.ProspectSkipped), "topology change did not clear exclusion set")

-- Every safety block must leave the secure action unarmed.
Reset()
Put(0, 1, 2770, 5)
local blockers = {
    function(value) moving = value and 1 or 0 end,
    function(value) dead = value end,
    function(value) cursor = value end,
    function(value) targeting = value end,
    function(value) RTB.SortInProgress = value end,
    function(value) RTB.SortSession = value and {} or nil end,
    function(value) RTB.TransferSession = value and {} or nil end,
    function(value) casting = value end,
    function(value) lootCount = value and 1 or 0 end,
    function(value) RTB.MainFrame.shown = not value end,
    function(value) RTB:SetProspectingEnabled(not value) end
}
for _, block in ipairs(blockers) do
    block(true)
    assert(not Click(), "unsafe state dispatched prospect action")
    assert(not RTB.ProspectPending, "unsafe state created pending action")
    block(false)
end

-- Combat must not mutate protected frame state; apply preference afterwards.
RTB:RefreshProspecting()
combat = true
button.shown = false -- native secure visibility driver, not an addon write
local writesBeforeCombat = secureWrites
RTB:SetProspectingEnabled(false)
RTB:OnProspectingEvent("PLAYER_REGEN_DISABLED")
driver.scripts.OnUpdate(driver, 1)
button.scripts.PreClick(button, "LeftButton")
button.scripts.PostClick(button, "LeftButton")
assert(secureWrites == writesBeforeCombat, "combat caused protected writes")
assert(not RTB.ProspectPending and not button:GetAttribute("type"))
combat = false
RTB:OnProspectingEvent("PLAYER_REGEN_ENABLED")
assert(button.visibility == "hide" and not RTB:GetProspectingEnabled())
RTB:SetProspectingEnabled(true)
assert(button.visibility ~= "hide")

-- Auto-merge is a separate, click-started inventory operation. It never casts.
assert(RTB:GetProspectingAutoMerge(), "ore merging must default on")
RTB:SetProspectingAutoMerge(false)
RTB:InitializeDB()
assert(not RTB:GetProspectingAutoMerge(), "merge OFF preference did not persist")

local function Tick(seconds)
    now = now + (seconds or 0.2)
    driver.scripts.OnUpdate(driver, seconds or 0.2)
end
local function DrainMerge()
    local tick
    for tick = 1, 20 do
        Tick()
        if not RTB.ProspectMergeSession then return end
    end
    error("merge did not finish within bounded simulated ticks")
end
local function StartMerge()
    allowPickup = true
    assert(not Click(), "merge-start click dispatched a spell")
    assert(RTB.ProspectMergeSession, "merge-start click did not create a session")
    assert(pickupCalls == 0, "merge executed inside secure click preparation")
end

Reset()
Put(0, 1, 2770, 2)
Put(4, 1, 2770, 3)
families[4] = 1024
local actionsBeforeMerge = attemptedActions
RTB:RefreshProspecting()
RTB:OnProspectingEvent("BAG_UPDATE", 4)
Tick()
assert(pickupCalls == 0 and not RTB.ProspectMergeSession,
    "background refresh started merging without a user click")
StartMerge()
assert(RTB:IsProspectingBusy(), "merging must block concurrent sort/transfer")
RTB:SortInventory()
assert(not RTB.SortSession, "sorting started during ore merging")
RTB:TransferRecentItems("bags-to-bank")
assert(not RTB.TransferSession, "transfer started during ore merging")
DrainMerge()
assert(bags[0][1].count == 5 and not bags[4][1],
    "2+3 across normal/mining bags did not yield one five-stack")
assert(pickupCalls == 2 and not heldItem and not RTB.ProspectPending)
assert(attemptedActions == actionsBeforeMerge and not button:GetAttribute("type"),
    "confirmed merge automatically cast or armed Prospecting")
target = Click()
assert(target and target.bagID == 0 and attemptedActions == actionsBeforeMerge + 1,
    "merged batch did not require and accept a separate explicit click")

Reset()
Put(0, 1, 2770, 2)
Put(2, 1, 2770, 2)
Put(4, 1, 2770, 1)
StartMerge()
DrainMerge()
assert(bags[0][1].count == 5 and not bags[2][1] and not bags[4][1])
assert(pickupCalls == 4 and not heldItem, "2+2+1 must use two confirmed full merges")

-- Insufficient totals, distinct ore types, disabled mode and missing item data
-- must preserve all stacks without attempting native pickups.
Reset()
Put(0, 1, 2770, 2)
Put(4, 1, 2770, 2)
assert(not Click() and not RTB.ProspectMergeSession and pickupCalls == 0)
bags[4][1].id, bags[4][1].count = 2771, 3
assert(not Click() and not RTB.ProspectMergeSession and pickupCalls == 0)
bags[4][1].id = 2770
RTB:SetProspectingAutoMerge(false)
assert(not Click() and not RTB.ProspectMergeSession and pickupCalls == 0)
RTB:SetProspectingAutoMerge(true)
unavailableInfo = true
assert(not Click() and not RTB.ProspectMergeSession and pickupCalls == 0)
unavailableInfo = false
Put(2, 1, 2771, 5)
assert(Click().bagID == 2 and not RTB.ProspectMergeSession and pickupCalls == 0,
    "ready dose must take priority over combining other partial stacks")

-- Stale and locked reads cannot confirm a merge or trigger another operation.
Reset()
Put(0, 1, 2770, 2)
Put(4, 1, 2770, 3)
StartMerge()
Tick()
assert(RTB.ProspectMergeSession.pending and pickupCalls == 2)
visibleBags = {[0]={[1]={id=2770,count=2}}, [4]={[1]={id=2770,count=3}}}
Tick()
assert(RTB.ProspectMergeSession.pending and pickupCalls == 2,
    "stale pre-merge reads were treated as confirmation")
visibleBags = nil
bags[0][1].locked = true
Tick()
assert(RTB.ProspectMergeSession.pending and pickupCalls == 2,
    "locked target was treated as confirmation")
bags[0][1].locked = false
bags[0][1].unknown = true
Tick()
assert(RTB.ProspectMergeSession.pending, "uncached target was treated as confirmation")
bags[0][1].unknown = false
DrainMerge()
assert(pickupCalls == 2 and not RTB.ProspectPending)

Reset()
Put(0, 1, 2770, 2)
Put(4, 1, 2770, 3)
StartMerge()
rejectMerge = true
Tick()
assert(not heldItem and pickupCalls == 3, "rejected merge did not return source to its slot")
Tick(6)
assert(not RTB.ProspectMergeSession and bags[0][1].count == 2
    and bags[4][1].count == 3, "unconfirmed merge did not stop after timeout")

-- Every interruption stops the session before any subsequent native operation.
local stopCases = {
    function() sizes[3] = 1 end,
    function() now = now + 31 end,
    function() cursor = true end,
    function() combat = true; RTB:OnProspectingEvent("PLAYER_REGEN_DISABLED") end,
    function() RTB.MainFrame.shown = false; RTB:RefreshProspecting() end,
    function() RTB:SetProspectingEnabled(false) end,
    function() RTB:SetProspectingAutoMerge(false) end,
    function() profession = false end,
    function() learned = false end,
    function() casting = true end,
    function() lootCount = 1; RTB:OnProspectingEvent("LOOT_OPENED") end,
    function() moving = 1 end,
    function() RTB.SortInProgress = true end,
    function() RTB.TransferSession = {} end
}
for _, stop in ipairs(stopCases) do
    Reset()
    Put(0, 1, 2770, 2)
    Put(4, 1, 2770, 3)
    StartMerge()
    stop()
    Tick()
    assert(not RTB.ProspectMergeSession and pickupCalls == 0,
        "unsafe state failed to stop merging before mutation")
end

-- Active window movement must not scan bags or mutate secure overlays.
Reset(); Put(0, 1, 2770, 5)
RTB:RefreshProspecting()
RTB.ProfessionWindowInteraction = RTB.MainFrame
local savedIterator = RTB.IterateContainerSlots
RTB.IterateContainerSlots = function() error("bag scan during window interaction") end
local writesDuringDrag = secureWrites
RTB:RefreshProspecting()
RTB:OnProspectingEvent("BAG_UPDATE", 0)
Tick()
assert(secureWrites == writesDuringDrag, "active drag refreshed secure Prospect overlay")
RTB.IterateContainerSlots = savedIterator
assert(not Click() and not RTB.ProspectPending, "active drag allowed Prospect cast")
RTB.InventoryProspectAnchor.left = 333
RTB.ProfessionWindowInteraction = nil
RTB:RefreshProspecting()
assert(RTB.ProspectButton.rtbX == 333 * 1.2 / 0.8,
    "Prospect did not resync after window interaction")

print("PROSPECTING LOGIC OK")
