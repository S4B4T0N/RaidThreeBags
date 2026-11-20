-- Automatic candidate selection, one hardware-clicked Disenchant per item.
-- Quality 4+ can never pass the target predicate, even with saved-data changes.
local RTB = RaidThreeBags
local Style = RaidThreeUIStyle
local DISENCHANT = 13262
local ENCHANTING_RANKS = { 7411, 7412, 7413, 13920, 28029, 51313 }
-- Locale-independent wearable weapon/armor locations. No bags, quivers,
-- ammo, shirts, tabards or items with an empty equipment location.
local EQUIPMENT = {
    INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_WAIST = true,
    INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true,
    INVTYPE_HAND = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true, INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true
}

function RTB:GetDisenchantingEnabled()
    return not self.DB or self.DB.disenchantingEnabled ~= false
end

function RTB:SetDisenchantingEnabled(enabled)
    self:InitializeDB()
    self.DB.disenchantingEnabled = enabled and true or false
    self:RefreshDisenchanting()
end

function RTB:GetDisenchantBlueEnabled()
    return self.DB and self.DB.disenchantBlueEnabled == true or false
end

function RTB:SetDisenchantBlueEnabled(enabled)
    self:InitializeDB()
    self.DB.disenchantBlueEnabled = enabled and true or false
    self:RefreshDisenchanting()
end

function RTB:HasEnchanting()
    local name = GetSpellInfo(7411)
    if name then
        local index
        for index = 1, GetNumSkillLines() do
            local skillName, header = GetSkillLineInfo(index)
            if not header and skillName == name then return true end
        end
    end
    local _, spellID
    for _, spellID in ipairs(ENCHANTING_RANKS) do
        if IsSpellKnown(spellID) then return true end
    end
    return false
end

function RTB:IsDisenchantingBusy()
    return self.DisenchantPending ~= nil
end

function RTB:ReadDisenchantCandidate(slot)
    -- Explicit physical bag boundary: never equipment, bank or keyring.
    if slot.bagID < 0 or slot.bagID > 4 then return end
    local key, count, locked, state = self:GetContainerSlotState(slot)
    if state ~= "occupied" or locked or count ~= 1 then return end
    local _, _, _, slotQuality, _, _, link = GetContainerItemInfo(slot.bagID, slot.slotID)
    if not link then return end
    local name, _, quality, _, _, _, _, _, equipLocation = GetItemInfo(link)
    if not name or not EQUIPMENT[equipLocation] then return end
    if quality ~= 2 and not (quality == 3 and self:GetDisenchantBlueEnabled()) then return end
    -- An uncached/contradictory container quality cannot authorize destruction.
    if slotQuality ~= quality then return end
    slot.itemKey, slot.link, slot.count, slot.quality = key, link, count, quality
    slot.signature = slot.bagID .. ":" .. slot.slotID .. ":" .. link
    return slot
end

function RTB:FindDisenchantTarget()
    if not self:HasEnchanting() then return nil, 0, "Requires Enchanting." end
    if not IsSpellKnown(DISENCHANT) then return nil, 0, "Learn Disenchant from your trainer first." end
    local topology = self:GetInventorySortTopologyFingerprint()
    if self.DisenchantTopology ~= topology then
        self.DisenchantSkipped = {}
        self.DisenchantTopology = topology
    end
    local target, candidates = nil, 0
    local bagID, slotID
    for bagID, slotID in self:IterateContainerSlots(self.BAG_IDS) do
        local candidate = self:ReadDisenchantCandidate({ bagID = bagID, slotID = slotID })
        if candidate and not (self.DisenchantSkipped and self.DisenchantSkipped[candidate.signature]) then
            candidates = candidates + 1
            if not target then target = candidate end
        end
    end
    return target, candidates, target and "Click to permanently disenchant the item below."
        or "No eligible gear. Right-click to retry skipped items."
end

function RTB:GetDisenchantBlockReason()
    if InCombatLockdown() then return "Unavailable in combat." end
    if not self:GetDisenchantingEnabled() then return "Disabled in settings." end
    if not self.MainFrame or not self.MainFrame:IsShown() then return "Open inventory first." end
    if self.SortInProgress or self.SortSession or self.TransferSession then return "Wait for sorting or transfer." end
    if self:IsProspectingBusy() then return "Finish the profession action and collect all loot first." end
    if CursorHasItem() or (SpellIsTargeting and SpellIsTargeting()) then return "Clear your cursor first." end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "Unavailable while dead." end
    if GetUnitSpeed and GetUnitSpeed("player") > 0 then return "Stand still to disenchant." end
end

function RTB:UpdateDisenchantPending()
    local pending = self.DisenchantPending
    if not pending then return end
    local key, _, locked, state = self:GetContainerSlotState(pending)
    local consumed = not locked and state ~= "unknown" and key ~= pending.itemKey
    local casting = UnitCastingInfo("player") or UnitChannelInfo("player")
    local looting = self.ProspectLootOpen or (GetNumLootItems() or 0) > 0
    if pending.succeeded and consumed and not casting and not looting
        and GetTime() - pending.started >= 0.5 then
        self.DisenchantPending = nil
    elseif GetTime() - pending.started > 30 and not casting and not looting then
        self.DisenchantSkipped = self.DisenchantSkipped or {}
        self.DisenchantSkipped[pending.signature] = true
        self.DisenchantPending = nil
    end
end

function RTB:ClearDisenchantAction(button)
    button:SetAttribute("type", nil)
    button:SetAttribute("macrotext", nil)
    local cast = self.DisenchantCastButton
    if cast then
        cast:SetAttribute("type", nil)
        cast:SetAttribute("target-bag", nil)
        cast:SetAttribute("target-slot", nil)
    end
end

function RTB:PrepareDisenchantClick(button, mouseButton)
    if InCombatLockdown() then return end
    self:ClearDisenchantAction(button)
    self:UpdateDisenchantPending()
    if mouseButton == "RightButton" then
        self.DisenchantSkipped = {}
        self:RefreshDisenchanting()
        return
    end
    if mouseButton ~= "LeftButton" then return end
    local blocked = self:GetDisenchantBlockReason()
    local target, _, reason = self:FindDisenchantTarget()
    if blocked or not target then
        if not blocked and self.DisenchantSkipped and next(self.DisenchantSkipped) then
            self.DisenchantSkipped = {}
            self:Print("Disenchant pass finished. Click again to retry remaining eligible gear.")
        else
            self:Print(blocked or reason)
        end
        return
    end
    -- Never cast from stale tooltip coordinates, and recheck the hard quality
    -- restriction immediately before exposing the secure action attributes.
    local verified = self:ReadDisenchantCandidate({ bagID = target.bagID, slotID = target.slotID })
    if not verified or verified.link ~= target.link then
        self:Print("The selected item changed. Try again.")
        return
    end
    verified.started = GetTime()
    self.DisenchantPending = verified
    local cast = self.DisenchantCastButton
    cast:SetAttribute("spell", GetSpellInfo(DISENCHANT))
    cast:SetAttribute("target-bag", verified.bagID)
    cast:SetAttribute("target-slot", verified.slotID)
    cast:SetAttribute("type", "spell")
    button:SetAttribute("macrotext", "/click RaidThreeBagsDisenchantCast\n/click RaidThreeBagsDisenchantStop")
    button:SetAttribute("type", "macro")
end

function RTB:CreateDisenchantButton()
    if self.DisenchantButton or InCombatLockdown() then return end
    -- The native spell action guards item use with SpellCanTargetItem. A
    -- separate secure stop action cancels rejected targeting without an
    -- unconditional /use fallback (which could otherwise equip the item).
    local cast = CreateFrame("Button", "RaidThreeBagsDisenchantCast", UIParent,
        "SecureActionButtonTemplate")
    cast:Hide()
    self.DisenchantCastButton = cast
    local stop = CreateFrame("Button", "RaidThreeBagsDisenchantStop", UIParent,
        "SecureActionButtonTemplate")
    stop:SetAttribute("type", "stop")
    stop:Hide()
    self.DisenchantStopButton = stop
    local button = CreateFrame("Button", "RaidThreeBagsDisenchantButton", UIParent,
        "SecureActionButtonTemplate")
    Style:CreateSquareIconChrome(button, select(3, GetSpellInfo(DISENCHANT)))
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("PreClick", function(self, mouseButton)
        RTB:PrepareDisenchantClick(self, mouseButton)
    end)
    button:SetScript("PostClick", function(self)
        if not InCombatLockdown() then RTB:ClearDisenchantAction(self) end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Disenchant gear")
        local target, candidates, reason = RTB:FindDisenchantTarget()
        GameTooltip:AddLine(RTB:GetDisenchantBlockReason() or reason, 1, 1, 1, true)
        if target then
            GameTooltip:AddLine(target.link)
            GameTooltip:AddLine("Candidate items: " .. candidates)
        end
        GameTooltip:AddLine(RTB:GetDisenchantBlueEnabled()
            and "Green and blue bag gear. Epic items are NEVER selected."
            or "Green bag gear only. Blue is OFF; epics are NEVER selected.", 1, 1, 1, true)
        GameTooltip:AddLine("One click destroys one item. The server checks Enchanting skill and item eligibility.", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click retries skipped items. Disable in settings.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button:Hide()
    self.DisenchantButton = button
end

function RTB:RefreshDisenchanting()
    if InCombatLockdown() then return end
    self:UpdateDisenchantPending()
    local hasProfession = self:HasEnchanting()
    local anchor = self.InventoryDisenchantAnchor
    if not self.DisenchantButton and hasProfession and anchor then self:CreateDisenchantButton() end
    local button = self.DisenchantButton
    if not button then return end
    local visible = hasProfession and self:GetDisenchantingEnabled()
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
        local target = self:FindDisenchantTarget()
        button:SetAlpha((target and not self:GetDisenchantBlockReason()) and 1 or 0.45)
    end
end

function RTB:OnDisenchantEvent(event, unit, spellName)
    local pending = self.DisenchantPending
    if pending and unit == "player" and spellName == GetSpellInfo(DISENCHANT) then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            pending.succeeded = true
        elseif event == "UNIT_SPELLCAST_FAILED" then
            if not (GetUnitSpeed and GetUnitSpeed("player") > 0) then
                self.DisenchantSkipped = self.DisenchantSkipped or {}
                self.DisenchantSkipped[pending.signature] = true
            end
            self.DisenchantPending = nil
        elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
            self.DisenchantPending = nil
        end
    end
    self:RefreshDisenchanting()
end

local driver = CreateFrame("Frame")
local _, event
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "SPELLS_CHANGED",
    "BAG_UPDATE", "ITEM_LOCK_CHANGED", "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, ...) RTB:OnDisenchantEvent(event, ...) end)
driver:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.1 then return end
    self.elapsed = 0
    RTB:RefreshDisenchanting()
end)
