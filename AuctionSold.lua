-- SeviathsUsefulTools - tells you in chat (yellow) when something you put on the Auction House has sold
local _, SFP = ...

local YELLOW = "|cffffff00"
local seen = {}   -- invoices already announced this session

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "[Auction House] " .. text .. "|r") end
end

local function money(c)
    if not c or c <= 0 then return "" end
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

-- "A buyer has been found for your auction of %s." -> pattern
local soldPattern
do
    local g = _G.ERR_AUCTION_SOLD_S
    if g then soldPattern = "^" .. g:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)") .. "$" end
end

-- sale invoices waiting in the mailbox: who bought what for how much (after the Auction House cut)
local function scanInbox()
    if not (GetInboxNumItems and GetInboxInvoiceInfo) then return end
    for i = 1, (GetInboxNumItems()) do
        local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(i)
        if invoiceType == "seller" and itemName then
            local key = itemName .. ":" .. (playerName or "") .. ":" .. (bid or 0)
            local _, _, sender, subject = GetInboxHeaderInfo(i)
            key = key .. ":" .. (subject or "") .. ":" .. i
            if not seen[key] then
                seen[key] = true
                local got = (bid or 0) - (consignment or 0)
                say(("Sold %s%s for %s (you receive %s)"):format(itemName,
                    playerName and playerName ~= "" and (" to " .. playerName) or "", money(bid), money(got)))
            end
        end
    end
end

SFP:OnLogin(function()
    if SFP.db.auctionSold == nil then SFP.db.auctionSold = true end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "CHAT_MSG_SYSTEM")
    pcall(f.RegisterEvent, f, "MAIL_INBOX_UPDATE")
    f:SetScript("OnEvent", function(_, event, msg)
        if not SFP.db.auctionSold then return end
        if event == "CHAT_MSG_SYSTEM" then
            local item = msg and soldPattern and msg:match(soldPattern)
            if item then
                say("Sold: " .. item)
                pcall(PlaySound, 120)   -- coin sound
            end
        else
            SFP:Safe("auction invoices", scanInbox)
        end
    end)
end)

function SFP:ToggleAuctionSold()
    SFP.db.auctionSold = not SFP.db.auctionSold
    SFP:Print("Auction sold messages " .. (SFP.db.auctionSold and "ON" or "OFF"))
end
