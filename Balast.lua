local defaultDB = {
    delay = 0.5,
    channel = "SAY",
    lines = {
        "Line one here",
        "Line two here",
        "Line three here",
    }
}

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Balast" then
        if not BalastDB then
            BalastDB = defaultDB
        else
            BalastDB.delay = BalastDB.delay or 0.5
            BalastDB.channel = BalastDB.channel or "SAY"
            BalastDB.lines = BalastDB.lines or defaultDB.lines
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

----------------------------------------------------
-- CHAT EXECUTION LOGIC
----------------------------------------------------
local runner = CreateFrame("Frame")
local queue = {}
local timer = 0
local isRunning = false
local lastPress = 0
local QUIET_TIME = 1.5  -- seconds with no /balast presses before it can start again

local function Finish()
    runner:SetScript("OnUpdate", nil)
    isRunning = false
end

local function OnUpdate(self, elapsed)
    timer = timer + elapsed
    local delay = BalastDB.delay or 0.5
    if timer >= delay then
        timer = 0
        if #queue > 0 then
            local msg = table.remove(queue, 1)
            if msg and msg ~= "" then
                SendChatMessage(msg, BalastDB.channel or "SAY")
            end
            if #queue == 0 then
                Finish()
            end
        else
            Finish()
        end
    end
end

SLASH_BALAST1 = "/balast"
SlashCmdList["BALAST"] = function()
    local now = GetTime()
    local sinceLast = now - lastPress
    lastPress = now  -- every press counts, even ignored ones

    if isRunning then return end
    if sinceLast < QUIET_TIME then return end  -- still spamming, ignore
    if not BalastDB or #BalastDB.lines == 0 then return end

    queue = {}
    for _, msg in ipairs(BalastDB.lines) do
        if msg and msg ~= "" then
            table.insert(queue, msg)
        end
    end

    if #queue == 0 then return end

    isRunning = true
    timer = BalastDB.delay or 0.5
    runner:SetScript("OnUpdate", OnUpdate)
end

----------------------------------------------------
-- IN-GAME CONFIGURATION MENU
----------------------------------------------------
local configFrame = nil

local function CreateConfigUI()
    if configFrame then return configFrame end

    local f = CreateFrame("Frame", "BalastConfigFrame", UIParent)
    f:SetSize(420, 500)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Balast Config")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Delay Input
    local delayLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    delayLabel:SetPoint("TOPLEFT", 20, -45)
    delayLabel:SetText("Delay (sec):")

    local delayInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    delayInput:SetSize(40, 20)
    delayInput:SetPoint("LEFT", delayLabel, "RIGHT", 10, 0)
    delayInput:SetAutoFocus(false)
    delayInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            BalastDB.delay = val
        end
    end)

    -- Channel Dropdown
    local channelLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    channelLabel:SetPoint("LEFT", delayInput, "RIGHT", 25, 0)
    channelLabel:SetText("Channel:")

    local dropdown = CreateFrame("Frame", "BalastChannelDropdown", f, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", channelLabel, "RIGHT", -12, -2)

    local channels = { "SAY", "PARTY", "RAID", "YELL" }

    local function Dropdown_OnClick(self)
        UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
        BalastDB.channel = channels[self:GetID()]
    end

    local function Dropdown_Init(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for i, ch in ipairs(channels) do
            info.text = ch
            info.value = ch
            info.func = Dropdown_OnClick
            info.checked = (BalastDB.channel == ch)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Dropdown_Init)
    UIDropDownMenu_SetWidth(dropdown, 80)
    UIDropDownMenu_SetText(dropdown, "SAY")

    -- Instruction text
    local instruct = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    instruct:SetPoint("TOPLEFT", 20, -80)
    instruct:SetText("Enter your chat lines below (one per line):")

    -- Scroll Frame & Text Box
    local scrollFrame = CreateFrame("ScrollFrame", "BalastScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(350, 330)
    scrollFrame:SetPoint("TOPLEFT", 20, -100)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(350, 330)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(2000)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetAutoFocus(false)
    scrollFrame:SetScrollChild(editBox)

    f:SetScript("OnShow", function()
        delayInput:SetText(tostring(BalastDB.delay or 0.5))

        local currentChan = BalastDB.channel or "SAY"
        for id, ch in ipairs(channels) do
            if ch == currentChan then
                UIDropDownMenu_SetSelectedID(dropdown, id)
                UIDropDownMenu_SetText(dropdown, ch)
                break
            end
        end

        if BalastDB.lines then
            editBox:SetText(table.concat(BalastDB.lines, "\n"))
        end
    end)

    -- Save Button
    local saveBtn = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    saveBtn:SetSize(100, 25)
    saveBtn:SetPoint("BOTTOM", 0, 15)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        local newLines = {}
        for line in string.gmatch(text, "[^\r\n]+") do
            if line and line:match("%S") then
                table.insert(newLines, line)
            end
        end
        BalastDB.lines = newLines
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[Balast]|r Saved " .. #newLines .. " line(s) for [" .. (BalastDB.channel or "SAY") .. "].")
        f:Hide()
    end)

    configFrame = f
    return f
end

SLASH_BALASTCONFIG1 = "/balastconfig"
SlashCmdList["BALASTCONFIG"] = function()
    local ui = CreateConfigUI()
    if ui:IsShown() then
        ui:Hide()
    else
        ui:Show()
    end
end
