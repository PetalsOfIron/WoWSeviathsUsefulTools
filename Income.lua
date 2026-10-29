-- SeviathsUsefulTools - tells you in chat (yellow) how much gold you took from the mailbox or got from a vendor
local _, SFP = ...

local YELLOW = "|cffffff00"
local last, pendingMail, pendingVendor, timer = nil, 0, 0, nil

local function money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. text .. "|r") end
end

local function flush()
    timer = nil
    if pendingMail > 0 then say("[Mailbox] You took " .. money(pendingMail)) end
    if pendingVendor > 0 then say("[Vendor] You sold items for " .. money(pendingVendor)) end
    pendingMail, pendingVendor = 0, 0
end

SFP:OnLogin(function()
    if SFP.db.incomeMessages == nil then SFP.db.incomeMessages = true end
    last = GetMoney()
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "PLAYER_MONEY")
    f:SetScript("OnEvent", function()
        local now = GetMoney()
        local delta = now - (last or now)
        last = now
        if delta <= 0 or not SFP.db.incomeMessages then return end
        if _G.MailFrame and MailFrame:IsShown() then pendingMail = pendingMail + delta
        elseif _G.MerchantFrame and MerchantFrame:IsShown() then pendingVendor = pendingVendor + delta
        else return end
        -- many items in a row arrive as many small changes: one line for the lot
        if not timer then timer = true; C_Timer.After(0.8, flush) end
    end)
end)

function SFP:ToggleIncomeMessages()
    SFP.db.incomeMessages = not SFP.db.incomeMessages
    SFP:Print("Mailbox / vendor gold messages " .. (SFP.db.incomeMessages and "ON" or "OFF"))
end
