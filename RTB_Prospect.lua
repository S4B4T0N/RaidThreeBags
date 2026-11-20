-- WoW 3.3.5a: scan automatically, cast only through a hardware-clicked
-- secure action button. No timer or event casts spells or uses items.
local RTB = RaidThreeBags
local Style = RaidThreeUIStyle
local PROSPECT = 31252
local JC_RANKS = { 25229, 25230, 28894, 28895, 28897, 51311 }
-- WotLK prospectable ores and RequiredSkillRank (skill 755).
local ORES = {
    [2770] = 1, [2771] = 50, [2772] = 125, [3858] = 175,
    [10620] = 250, [23424] = 275, [23425] = 325,
    [36909] = 350, [36912] = 400, [36910] = 450
}

local function Now()
    return GetTime()
end

local function Casting()
    return UnitCastingInfo("player") or UnitChannelInfo("player")
end

local function Signature(slot, itemKey, count)
    return slot.bagID .. ":" .. slot.slotID .. ":" .. itemKey .. ":" .. count
end

function RTB:GetProspectingEnabled()
    return not self.DB or self.DB.prospectingEnabled ~= false
end

function RTB:SetProspectingEnabled(enabled)
    self:InitializeDB()
    self.DB.prospectingEnabled = enabled and true or false
    self:RefreshProspecting()
end

function RTB:GetProspectingAutoMerge()
    return not self.DB or self.DB.prospectingAutoMerge ~= false
end

function RTB:SetProspectingAutoMerge(enabled)
    self:InitializeDB()
    self.DB.prospectingAutoMerge = enabled and true or false
    if not enabled then self:FinishProspectingMerge("Ore merging disabled.") end
    self:RefreshProspecting()
end

function RTB:GetJewelcraftingSkill()
    local name = GetSpellInfo(25229)
    if name then
        local index
        for index = 1, GetNumSkillLines() do
            local skillName, header, _, rank, temporary, modifier = GetSkillLineInfo(index)
            if not header and skillName == name then
                return true, (tonumber(rank) or 0) + (tonumber(temporary) or 0)
                    + (tonumber(modifier) or 0)
            end
        end
    end
    -- Collapsed skill headers may hide the rank row. Do not expand the user's
    -- skill UI. The server can check the rank when it is not observable here.
    local _, spellID
    for _, spellID in ipairs(JC_RANKS) do
        if IsSpellKnown(spellID) then return true, nil end
    end
    return false, nil
end

function RTB:IsProspectingBusy(ignoreMerge)
    return (not ignoreMerge and self.ProspectMergeSession ~= nil)
        or (self.IsDisenchantingBusy and self:IsDisenchantingBusy())
        or self.ProspectPending ~= nil or self.ProspectLootOpen
        or Casting() or (GetNumLootItems() or 0) > 0
end

-- Reuse the sorter's physical slot traversal/reader and native pickup helper.
-- Same ore is already present in both occupied slots, so a full merge is also
-- valid across normal/mining bags without moving into an incompatible slot.
function RTB:FindProspectingMerge()
    local hasProfession, rank = self:GetJewelcraftingSkill()
    if not hasProfession or not IsSpellKnown(PROSPECT) then return end
    local groups, order = {}, {}
    local bagID, slotID
    for bagID, slotID in self:IterateContainerSlots(self.BAG_IDS) do
        local slot = { bagID = bagID, slotID = slotID }
        local key, count, locked, state = self:GetContainerSlotState(slot)
        local required = ORES[tonumber(key)]
        if state == "occupied" and not locked and required
            and count > 0 and count < 5 and (not rank or rank >= required) then
            local link = GetContainerItemLink(bagID, slotID)
            local name, _, _, _, _, _, _, maxStack = GetItemInfo(link or tonumber(key))
            if name and tonumber(maxStack) and maxStack >= 5 then
                local group = groups[key]
                if not group then
                    group = { total = 0, slots = {} }
                    groups[key] = group
                    table.insert(order, key)
                end
                slot.itemKey, slot.count, slot.maxStack = key, count, maxStack
                group.total = group.total + count
                table.insert(group.slots, slot)
            end
        end
    end
    local _, key
    for _, key in ipairs(order) do
        local group = groups[key]
        if group.total >= 5 then
            local targetIndex, target
            for targetIndex, target in ipairs(group.slots) do
                local sourceIndex
                for sourceIndex = targetIndex + 1, #group.slots do
                    local source = group.slots[sourceIndex]
                    if target.count + source.count <= target.maxStack then
                        return source, target
                    end
                end
            end
        end
    end
end

function RTB:FinishProspectingMerge(message)
    if not self.ProspectMergeSession then return end
    self.ProspectMergeSession = nil
    if message then self:Print(message) end
end

function RTB:BeginProspectingMerge()
    if not self:GetProspectingAutoMerge() or self:GetProspectingBlockReason() then
        return false
    end
    if not self:FindProspectingMerge() then return false end
    local limit = 0
    for _ in self:IterateContainerSlots(self.BAG_IDS) do limit = limit + 1 end
    self.ProspectMergeSession = {
        started = Now(), moves = 0, limit = limit,
        topology = self:GetInventorySortTopologyFingerprint()
    }
    self:Print("Combining small ore stacks. Click Prospect again when ready.")
    return true
end

function RTB:ContinueProspectingMerge()
    local session = self.ProspectMergeSession
    if not session then return end
    local blocked = self:GetProspectingBlockReason(true)
    local profession = self:GetJewelcraftingSkill()
    if blocked or not self:GetProspectingAutoMerge()
        or not profession or not IsSpellKnown(PROSPECT) then
        self:FinishProspectingMerge(blocked or "Ore merging stopped.")
        return
    end
    if Now() - session.started > 30 or session.moves >= session.limit then
        self:FinishProspectingMerge("Ore merging stopped at its safety limit.")
        return
    end
    if session.topology ~= self:GetInventorySortTopologyFingerprint() then
        self:FinishProspectingMerge("Bag layout changed. Ore merging stopped.")
        return
    end
    local pending = session.pending
    if pending then
        local sourceKey, sourceCount, sourceLocked, sourceState =
            self:GetContainerSlotState(pending.source)
        local targetKey, targetCount, targetLocked, targetState =
            self:GetContainerSlotState(pending.target)
        if sourceState == "empty" and not sourceLocked
            and targetState == "occupied" and not targetLocked
            and targetKey == pending.target.itemKey
            and targetCount == pending.source.count + pending.target.count then
            session.pending = nil
            session.moves = session.moves + 1
            -- Rebuild from live counts on a later tick, never while handling
            -- a synchronous BAG_UPDATE from the native pickup sequence.
            return
        end
        if (sourceState == "occupied" and sourceKey ~= pending.source.itemKey)
            or (targetState == "occupied" and targetKey ~= pending.target.itemKey) then
            self:FinishProspectingMerge("Ore changed during merging. Stopped.")
        elseif Now() - pending.started > 5 then
            self:FinishProspectingMerge("The client did not confirm the ore merge.")
        end
        return
    end
    if self:FindProspectingTarget() then
        self:FinishProspectingMerge("Ore ready. Click Prospect to process five ore.")
        return
    end
    local source, target = self:FindProspectingMerge()
    if not source then
        self:FinishProspectingMerge("No further ore stacks can form a batch of five.")
        return
    end
    -- Revalidate both snapshots immediately before the existing pickup helper.
    local sourceKey, sourceCount, sourceLocked, sourceState = self:GetContainerSlotState(source)
    local targetKey, targetCount, targetLocked, targetState = self:GetContainerSlotState(target)
    if sourceLocked or targetLocked or sourceState == "unknown" or targetState == "unknown" then return end
    if sourceKey ~= source.itemKey or sourceCount ~= source.count
        or targetKey ~= target.itemKey or targetCount ~= target.count then
        self:FinishProspectingMerge("Ore changed before merging. Try again.")
        return
    end
    session.pending = { source = source, target = target, started = Now() }
    local ok, err = self:SwapInventorySlots(source, target)
    if not ok then self:FinishProspectingMerge(err) end
end

function RTB:FindProspectingTarget()
    local topology = self:GetInventorySortTopologyFingerprint()
    if self.ProspectTopology ~= topology then
        self.ProspectSkipped = {}
        self.ProspectTopology = topology
    end
    local hasProfession, rank = self:GetJewelcraftingSkill()
    if not hasProfession then return nil, 0, "Requires Jewelcrafting." end
    if not IsSpellKnown(PROSPECT) then
        return nil, 0, "Learn Prospecting from your trainer first."
    end
    local target, batches, waiting = nil, 0, false
    local bagID, slotID
    for bagID, slotID in self:IterateContainerSlots(self.BAG_IDS) do
        local slot = { bagID = bagID, slotID = slotID }
        local itemKey, count, locked, state = self:GetContainerSlotState(slot)
        local required = ORES[tonumber(itemKey)]
        if state == "unknown" then waiting = true end
        if required and count >= 5 and (not rank or rank >= required) then
            local signature = Signature(slot, itemKey, count)
            if locked then
                waiting = true
            elseif not (self.ProspectSkipped and self.ProspectSkipped[signature]) then
                batches = batches + math.floor(count / 5)
                if not target then
                    slot.itemKey, slot.count, slot.signature = itemKey, count, signature
                    target = slot
                end
            end
        end
    end
    return target, batches, target and "Ready: one click prospects 5 ore."
        or (waiting and "Waiting for locked or uncached items."
            or "No eligible ore. Click to finish this pass; right-click to retry.")
end

function RTB:UpdateProspectingPending()
    local pending = self.ProspectPending
    if not pending then return end
    local key, count, locked, state = self:GetContainerSlotState(pending)
    local consumed = state ~= "unknown" and not locked
        and (key ~= pending.itemKey or count <= pending.count - 5)
    if pending.succeeded and consumed and not self.ProspectLootOpen
        and (GetNumLootItems() or 0) == 0 and not Casting()
        and Now() - pending.started >= 0.5 then
        self.ProspectPending = nil
    elseif Now() - pending.started > 30 and not Casting()
        and not self.ProspectLootOpen and (GetNumLootItems() or 0) == 0 then
        -- Bounded recovery after a rejected click or missing server event.
        -- Skip only this exact stack snapshot; right-click explicitly retries.
        self.ProspectSkipped = self.ProspectSkipped or {}
        self.ProspectSkipped[pending.signature] = true
        self.ProspectPending = nil
    end
end

function RTB:GetProspectingBlockReason(ignoreMerge)
    if InCombatLockdown() then return "Unavailable in combat." end
    if not self:GetProspectingEnabled() then return "Disabled in settings." end
    if not self.MainFrame or not self.MainFrame:IsShown() then return "Open inventory first." end
    if self.SortInProgress or self.SortSession or self.TransferSession then return "Wait for sorting or transfer to finish." end
    if self.ProspectMergeSession and not ignoreMerge then return "Wait for ore merging to finish." end
    if self:IsProspectingBusy(ignoreMerge) then return "Finish casting and collect all loot first." end
    if CursorHasItem() or (SpellIsTargeting and SpellIsTargeting()) then return "Clear your cursor first." end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "Unavailable while dead." end
    if GetUnitSpeed and GetUnitSpeed("player") > 0 then return "Stand still to prospect." end
end

function RTB:PrepareProspectingClick(button, mouseButton)
    if InCombatLockdown() then return end
    -- Never retain a target across clicks: sorting, bag swaps and user moves
    -- can invalidate coordinates between frames.
    button:SetAttribute("type", nil)
    button:SetAttribute("target-bag", nil)
    button:SetAttribute("target-slot", nil)
    self:UpdateProspectingPending()
    if mouseButton == "RightButton" then
        self.ProspectSkipped = {}
        self:RefreshProspecting()
        return
    end
    if mouseButton ~= "LeftButton" then return end
    local blocked = self:GetProspectingBlockReason()
    local target, _, reason = self:FindProspectingTarget()
    if blocked or not target then
        if not blocked and self:BeginProspectingMerge() then return end
        if not blocked and self.ProspectSkipped and next(self.ProspectSkipped) then
            self.ProspectSkipped = {}
            self:Print("Prospecting pass finished. Click again to retry remaining ore.")
            return
        end
        self:Print(blocked or reason)
        return
    end
    target.started = Now()
    self.ProspectPending = target
    button:SetAttribute("spell", GetSpellInfo(PROSPECT))
    button:SetAttribute("target-bag", target.bagID)
    button:SetAttribute("target-slot", target.slotID)
    button:SetAttribute("type", "spell")
end

function RTB:CreateProspectingButton()
    if self.ProspectButton or InCombatLockdown() then return end
    -- No parent/anchor relationship to the normal inventory window: a secure
    -- child would protect its ancestors and break bag movement/closing in combat.
    local button = CreateFrame("Button", "RaidThreeBagsProspectButton", UIParent,
        "SecureActionButtonTemplate")
    Style:CreateSquareIconChrome(button, select(3, GetSpellInfo(PROSPECT)))
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("PreClick", function(self, mouseButton)
        RTB:PrepareProspectingClick(self, mouseButton)
    end)
    button:SetScript("PostClick", function(self)
        if not InCombatLockdown() then self:SetAttribute("type", nil) end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Prospect ore")
        local target, batches, reason = RTB:FindProspectingTarget()
        if not target and RTB:GetProspectingAutoMerge() and RTB:FindProspectingMerge() then
            reason = "Click to combine ore into a batch of five."
        end
        GameTooltip:AddLine(RTB:GetProspectingBlockReason() or reason, 1, 1, 1, true)
        if target then
            GameTooltip:AddLine(GetContainerItemLink(target.bagID, target.slotID) or "Ore")
            GameTooltip:AddLine("Available batches: " .. batches)
        end
        GameTooltip:AddLine("Each cast consumes 5 ore. Collect loot, then click again.", 1, 1, 1, true)
        if RTB:GetProspectingAutoMerge() then
            GameTooltip:AddLine("No ready dose? Click to combine small ore stacks first. The next click casts.", 1, 1, 1, true)
        end
        GameTooltip:AddLine("Right-click: retry skipped slots. Disable in settings.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button:Hide()
    self.ProspectButton = button
end

function RTB:RefreshProspecting()
    if self.ProspectMergeSession and (not self:GetProspectingEnabled()
        or not self.MainFrame or not self.MainFrame:IsShown()) then
        self:FinishProspectingMerge("Ore merging stopped because inventory or Prospect was closed.")
    end
    if InCombatLockdown() then return end
    self:UpdateProspectingPending()
    local hasProfession = self:GetJewelcraftingSkill()
    local anchor = self.InventoryProspectAnchor
    if not self.ProspectButton and hasProfession and anchor then
        self:CreateProspectingButton()
    end
    local button = self.ProspectButton
    if not button then return end
    local visible = hasProfession and self:GetProspectingEnabled()
        and self.MainFrame and self.MainFrame:IsShown() and anchor
        and anchor:GetLeft() and anchor:GetBottom()
    local visibility = visible and "[combat] hide; show" or "hide"
    if button.rtbVisibility ~= visibility then
        RegisterStateDriver(button, "visibility", visibility)
        button.rtbVisibility = visibility
    end
    if visible then
        local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y = anchor:GetLeft() * scale, anchor:GetBottom() * scale
        if x ~= button.rtbX or y ~= button.rtbY or scale ~= button.rtbScale then
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            button:SetWidth(30 * scale)
            button:SetHeight(30 * scale)
            button.rtbX, button.rtbY, button.rtbScale = x, y, scale
        end
        button:SetFrameStrata(self.MainFrame:GetFrameStrata())
        button:SetFrameLevel(self.MainFrame:GetFrameLevel() + 10)
        local target = self:FindProspectingTarget()
        local actionable = target or (self:GetProspectingAutoMerge() and self:FindProspectingMerge())
        button:SetAlpha((actionable and not self:GetProspectingBlockReason()) and 1 or 0.45)
    end
end

function RTB:OnProspectingEvent(event, unit, spellName)
    if event == "LOOT_OPENED" then
        self.ProspectLootOpen = true
    elseif event == "LOOT_CLOSED" then
        self.ProspectLootOpen = false
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:FinishProspectingMerge("Ore merging stopped when combat began.")
        -- The secure visibility driver hides the button; no protected writes.
        return
    elseif self.ProspectPending and unit == "player"
        and spellName == GetSpellInfo(PROSPECT) then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            self.ProspectPending.succeeded = true
        elseif event == "UNIT_SPELLCAST_FAILED" then
            if not (GetUnitSpeed and GetUnitSpeed("player") > 0) then
                self.ProspectSkipped = self.ProspectSkipped or {}
                self.ProspectSkipped[self.ProspectPending.signature] = true
            end
            self.ProspectPending = nil
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            self.ProspectPending = nil
        end
    end
    self:RefreshProspecting()
end

local driver = CreateFrame("Frame")
local _, event
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED",
    "SPELLS_CHANGED", "BAG_UPDATE", "ITEM_LOCK_CHANGED", "LOOT_OPENED",
    "LOOT_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, ...)
    RTB:OnProspectingEvent(event, ...)
end)
driver:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.1 then return end
    self.elapsed = 0
    RTB:ContinueProspectingMerge()
    RTB:RefreshProspecting()
end)
