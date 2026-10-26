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
    C_Timer.After(0.05, step)
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
    waitTimer = C_Timer.NewTimer(2.5, finishItem)
    if qIndex % 25 == 0 then
        SFP:Print(string.format("Scanning prices... %d/%d", qIndex, #queue))
        SFP:RefreshAll()
    end
end

function SFP:StartScan(force)
    if not ahOpen then
        self:Print("Open the auction house first.")
        return
    end
    if scanning then return end
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
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "AUCTION_HOUSE_SHOW" then
        ahOpen = true
        local age = time() - (SFP.db.lastScan or 0)
        local stale = age > (SFP.db.rescanHours or 12) * 3600
        local resume = qIndex > 0 and qIndex < #queue
        if stale or resume then
            C_Timer.After(1, function() SFP:StartScan(false) end)
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
