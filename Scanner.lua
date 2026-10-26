-- SeviathsUsefulTools - item scanner
--
-- The game has no list of "all crafting materials", but it answers when asked about an item ID.
-- This asks slowly in the background (only when you are not in combat), keeps every tradeskill
-- material it finds in the saved variables, and remembers where it stopped, so after a few
-- play sessions the Codex knows every material of the game. /sfp scanitems shows the progress.

local ADDON, SFP = ...

local LAST_ID = 112000       -- a little above the last Mists of Pandaria item
local PER_TICK = 30          -- item IDs asked per tick
local TICK = 0.6             -- seconds between ticks
local waiting = {}

local function stepSize()
    return PER_TICK
end

local function checkItem(id)
    if not SFP.db.knownItems[id] and SFP.RecordItem then
        -- RecordItem stores everything it is given: only materials are kept
        local name, _, q, ilvl, minLvl, itype, subtype, _, equip, _, price, classID, subID, bind = C_Item.GetItemInfo(id)
        if name and classID == 7 then SFP.RecordItem(id) end
    end
end

local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, _, id, success)
    if id and waiting[id] then
        waiting[id] = nil
        if success ~= false then SFP:Safe("scan item", checkItem, id) end
    end
end)

local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    if not SFP.db or SFP.db.scanItems == false or SFP.scanPaused then return end
    acc = acc + dt
    if acc < TICK then return end
    acc = 0
    if InCombatLockdown() or (UnitOnTaxi and UnitOnTaxi("player")) then return end
    local nextId = SFP.db.scanNext or 1
    if nextId > LAST_ID then
        if not SFP.db.scanDone then
            SFP.db.scanDone = true
            SFP:Print("Item scan finished: every crafting material of the game is known now.")
            if SFP.db.knownItems then SFP.dropIndex = nil end
        end
        return
    end
    for id = nextId, math.min(LAST_ID, nextId + stepSize() - 1) do
        if C_Item.GetItemInfo(id) then
            SFP:Safe("scan item", checkItem, id)
        else
            waiting[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
    end
    SFP.db.scanNext = math.min(LAST_ID + 1, nextId + stepSize())
end)

function SFP:ScanProgress()
    local n = (self.db and self.db.scanNext or 1) - 1
    local mats = 0
    for _, it in pairs(self.db.knownItems or {}) do if it.c == 7 then mats = mats + 1 end end
    return math.min(100, math.floor(n * 100 / LAST_ID)), mats
end

SFP:OnLogin(function()
    if SFP.db.scanItems == nil then SFP.db.scanItems = true end
end)
