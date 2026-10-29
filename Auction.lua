-- SeviathsUsefulTools - auction house prices
-- The first time you open the auction house (and again when prices are older
-- than db.rescanHours) every tracked item is looked up once, throttled, and the
-- cheapest unit price is saved. /sfp scan forces a new scan.

local _, SFP = ...

local queue, qIndex = {}, 0
local scanning, waitingFor, waitTimer = false, nil, nil
local ahOpen = false

local function buildQueue()
    wipe(queue)
    for id in pairs(SFP.trackedIDs) do queue[#queue + 1] = id end
    table.sort(queue)
    qIndex = 0
end

local function savePrice(itemID, copper)
    if not itemID then return end
    if copper and copper > 0 then
        SFP.db.prices[itemID] = { p = copper, t = time() }
    end
end

local step  -- forward declared

local function finishItem()
    if waitTimer then waitTimer:Cancel(); waitTimer = nil end
    waitingFor = nil
    C_Timer.After(0, step)
end

step = function()
    if not scanning then return end
    if not ahOpen then
        scanning = false
        SFP:Print(string.format("Price scan paused at %d/%d - it continues next time you open the auction house.", qIndex, #queue))
        SFP:RefreshAll()
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        return -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY resumes us
    end
    qIndex = qIndex + 1
    local id = queue[qIndex]
    if not id then
        scanning = false
        SFP.db.lastScan = time()
        SFP:Print(string.format("Prices updated for %d items.", #queue))
        SFP:RefreshAll()
        return
    end
    waitingFor = id
    local key = C_AuctionHouse.MakeItemKey(id)
    local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    C_AuctionHouse.SendSearchQuery(key, sorts, true)
    -- nothing listed -> no result event; move on after a short wait
    waitTimer = C_Timer.NewTimer(1.2, finishItem)
    if qIndex % 25 == 0 then
        SFP:Print(string.format("Scanning prices... %d/%d", qIndex, #queue))
        SFP:RefreshAll()
    end
end

-- full scan: the whole auction house in one request (like other addons), instead of one search per item
local fullWaiting, fullTimer = false, nil

local function processReplicate()
    local n = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or 0
    local best, i, found = {}, 0, 0
    local function chunk()
        local stop = math.min(n, i + 600)
        while i < stop do
            local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
            i = i + 1
            if itemID and buyout and buyout > 0 and SFP.trackedIDs[itemID] then
                local unit = math.floor(buyout / ((count and count > 0) and count or 1))
                if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
            end
        end
        if i < n then
            C_Timer.After(0, chunk)
        else
            for id, p in pairs(best) do savePrice(id, p); found = found + 1 end
            scanning = false
            SFP.db.lastScan = time()
            SFP:Print(("Full auction scan done: %d auctions read, prices for %d items."):format(n, found))
            SFP:RefreshAll()
        end
    end
    chunk()
end

function SFP:TryFullScan()
    if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetReplicateItemInfo) then return false end
    local ok = pcall(C_AuctionHouse.ReplicateItems)
    if not ok then return false end
    fullWaiting, scanning = true, true
    self:Print("Full auction scan started (one request for the whole auction house)...")
    if fullTimer then fullTimer:Cancel() end
    fullTimer = C_Timer.NewTimer(25, function()
        if fullWaiting then
            -- no answer (scan cooldown?): fall back to searching the items one by one
            fullWaiting, scanning = false, false
            SFP:Print("No full scan answer - searching the items one by one.")
            SFP:StartScan(true, true)
        end
    end)
    return true
end

function SFP:StartScan(force, noFull)
    if not ahOpen then
        self:Print("Open the auction house first.")
        return
    end
    if scanning then return end
    if not noFull and self:TryFullScan() then return end
    if not force and qIndex > 0 and qIndex < #queue then
        qIndex = qIndex - 1 -- resume the interrupted scan
    else
        buildQueue()
    end
    scanning = true
    self:Print(string.format("Loading auction house prices for %d farm items...", #queue))
    step()
end

local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_SHOW")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_CLOSED")
pcall(f.RegisterEvent, f, "COMMODITY_SEARCH_RESULTS_UPDATED")
pcall(f.RegisterEvent, f, "ITEM_SEARCH_RESULTS_UPDATED")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
pcall(f.RegisterEvent, f, "REPLICATE_ITEM_LIST_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "AUCTION_HOUSE_SHOW" then
        ahOpen = true
        local age = time() - (SFP.db.lastScan or 0)
        local stale = age > (SFP.db.rescanHours or 12) * 3600
        local resume = qIndex > 0 and qIndex < #queue
        if stale or resume then
            C_Timer.After(1, function() SFP:StartScan(false) end)
        end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        if fullWaiting then
            fullWaiting = false
            if fullTimer then fullTimer:Cancel(); fullTimer = nil end
            SFP:Safe("full scan", processReplicate)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahOpen = false
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if scanning and not waitingFor then step() end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = arg1
        if itemID and C_AuctionHouse.GetNumCommoditySearchResults(itemID) > 0 then
            local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
            if r then savePrice(itemID, r.unitPrice) end
        end
        if scanning and waitingFor == itemID then finishItem() end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = arg1
        local itemID = itemKey and itemKey.itemID
        if itemID and C_AuctionHouse.GetNumItemSearchResults(itemKey) > 0 then
            local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
            if r and r.buyoutAmount then
                local qty = (r.quantity and r.quantity > 0) and r.quantity or 1
                savePrice(itemID, math.floor(r.buyoutAmount / qty))
            end
        end
        if scanning and waitingFor == itemID then finishItem() end
    end
end)

function SFP:IsScanning() return scanning, qIndex, #queue end
