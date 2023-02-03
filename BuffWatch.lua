-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- // BuffWatch
-- //     by Tyrrael aka Paul2200
-- //
-- //     fixes and new features by Pup
-- //
-- // TODO:
-- //     Maintain locked buff settings when raid/party is adjusted
-- //     Keybinding to scan list and recast any expired buffs (probably need to tie in with below)
-- //     Option to only add castable buffs (key combination to override this for a player?)
-- //     Option to only show debuffs I can cleanse
-- //     Allow cleansing of debuffs
-- //     Lower spell rank support
-- //     Show poisons and weapon buffs for player
-- //
-- // CHANGES:
-- // 
-- //     Alt-RightClick to remove all buffs OTHER than this one 
-- //     Optional warning message for when a monitored buff expires
-- //     Added support for 16 debuffs
-- //     Updated Interface number to 1700
-- //
-- //     
-- //////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Variables
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

BINDING_HEADER_BUFFWATCHHEADER = "BuffWatch"

BuffWatchConfig = { runCount, alpha, rightMouseSpell, show_on_startup, 
    ShowPets, ShowDebuffs, AlignBuffs, ExpiredWarning }

local UNIT_IDs = { }
local lastspellcast
local lastgrouptype
local buttonalignposition
local buffexpired 

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //
-- //                Standard Functions
-- //
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_OnLoad()

    this:RegisterEvent("PARTY_MEMBERS_CHANGED")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("RAID_ROSTER_UPDATE")
    this:RegisterEvent("SPELLCAST_START")
    this:RegisterEvent("UNIT_AURA")
    this:RegisterEvent("UNIT_PET")
    this:RegisterEvent("VARIABLES_LOADED")
--    this:RegisterEvent("UI_ERROR_MESSAGE")

    SlashCmdList["BUFFWATCH"] = BW_SlashHandler
    SLASH_BUFFWATCH1 = "/buffwatch"
    SLASH_BUFFWATCH2 = "/bw"

end


function BW_OnEvent()

    if event == "VARIABLES_LOADED" then

        -----------------------
        -- support for myAddons
        -----------------------
        if(myAddOnsFrame_Register) then
            BuffWatchDetails = {
                name = "BuffWatch",
                description = "Keeps track of party/raid buffs",
                version = "0.621",
                releaseDate = "September 14, 2005",
                author = "Tyrrael & Pup",
                category = MYADDONS_CATEGORY_OTHERS,
                frame = "BuffWatchFrame",
                optionsframe = "BuffWatchOptionsFrame"
            }

        BuffWatchHelp = { "              - BuffWatch Usage - v 0.621 -\n\n" ..
            "  Show/Hide the BuffWatch window:\n    - Bind a keyboard button to show/hide the window\n" ..
            "    - You can also close it by right clicking the \"BuffWatch\" label (appears on mouseover)\n\n" ..
            "  Showing Buffs:\n    - Left click the BuffWatch label\n    - Also occurs automatically whenever your gain/lose a party or raid member\n\n" ..
            "  Locking a player's watched buffs:\n    - If the checkbox to the left is unchecked, buffs will be added automatically whenever they gain a buff\n" ..
            "    - If checked, buffs will not be added\n\n",
            "  Rebuffing:\n    - Left click an icon (will auto-target)\n\n" ..
            "  Right click spell:\n" ..
            "    - Cast any spell with a cast time (not instant).\n        Then type \"/bw set\"\n    - To cast it, right click any icon (will auto-target)\n\n" ..
            "  Deleting buffs:\n    - Lock the player's buffs (check the box).\n        Then [ CTRL + Right Click ] on the buff\n" ..
            "    - Optionally, [ ALT + Right Click ] to delete all but the selected one.\n\n",
            "  Slash Commands ( Use /buffwatch or /bw )\n" ..
            "    - /bw alpha # : Set the background opacity (0.0 to 1.0)\n" ..
            "    - /bw toggle : shows/hides the window\n" ..
            "    - /bw [showonstartup / hideonstartup] : set to show or hide the window on startup\n" ..
            "    - /bw pets : toggle to show or hide pets in the buffwatch window\n" ..
            "    - /bw debuffs : toggle to show or hide debuffs in the buffwatch window\n" ..
            "    - /bw alignbuffs : toggle aligning of buff icons\n" ..
            "    - /bw expiredwarning : toggle expired buff warning message\n" ..
            "    - /bw options : shows/hides the options window\n" ..
            "    - /bw : shows this help menu :)\n\n" ..
            "  Verbosity:\n" ..
            "    - Hold [ Shift ] while left or right-clicking a buff icon to send a cast message to your party\n"
        }

            myAddOnsFrame_Register(BuffWatchDetails, BuffWatchHelp)
        end

        ---------------------
        -- support for Cosmos
        ---------------------
        if(EarthFeature_AddButton) then
            EarthFeature_AddButton({
                id = "BuffWatch";
                name = "BuffWatch";
                subtext = "Buff monitoring";
                tooltip = "Monitor Party or Raid buffs";
                icon = "Interface\\Icons\\INV_Misc_Spyglass_03";
                callback = BW_OptionsToggle;
                test = nil
            })
        elseif(Cosmos_RegisterButton) then
            Cosmos_RegisterButton(
                "BuffWatch",
                "Buff monitoring",
                "Monitor Party or Raid buffs",
                "Interface\\Icons\\INV_Misc_Spyglass_03",
                BW_OptionsToggle
            )
        end
        
        --------------------
        -- support for CTMod
        --------------------
        if(CT_RegisterMod) then
            CT_RegisterMod(
                "BuffWatch",
                "Buff monitoring",
                5,
                "Interface\\Icons\\INV_Misc_Spyglass_03",
                "Monitor Party or Raid buffs",
                "switch",
                "",
                BW_OptionsToggle
            )
        end             
        
        BW_Print("Tyrrael's BuffWatch loaded. Please type \"/buffwatch\" or \"/bw\" for usage. Use \"/bw toggle\" to show window.", 0.2, 0.9, 0.9 )
        
        getglobal("BuffWatchFrameHeaderText"):SetText("BuffWatch")
        getglobal("BuffWatchFrameHeaderText"):SetTextColor(0.2, 0.9, 0.9)
        BuffWatchBackdropFrame:SetBackdropBorderColor(0, 0, 0)

        if BuffWatchConfig.runCount == nil then
            BuffWatchConfig.runCount = 1 
        end

        if BuffWatchConfig.runCount == 1 then
        
            BW_Print("First Run Detected: Bind a keyboard button to show/hide the BuffWatch Frame", 0.2, 0.9, 0.9)
            BW_Print("Or type \"/buffwatch toggle\", then \"/buffwatch\" for usage", 0.2, 0.9, 0.9)
            BuffWatchConfig.runCount = BuffWatchConfig.runCount + 1
            
        else
            BuffWatchConfig.runCount = BuffWatchConfig.runCount + 1
        end

        if BuffWatchConfig.alpha == nil then
            BuffWatchConfig.alpha = 0.5
        end

        BuffWatchBackdropFrame:SetAlpha( BuffWatchConfig.alpha )

        if BuffWatchConfig.show_on_startup == nil then
        
            BuffWatchConfig.show_on_startup = true
            BuffWatchFrame:Show()
            
        elseif BuffWatchConfig.show_on_startup == true then
            BuffWatchFrame:Show()
        elseif BuffWatchConfig.show_on_startup == false then
            BuffWatchFrame:Hide()
        end
        
        if BuffWatchConfig.ShowPets == nil then
            BuffWatchConfig.ShowPets = true
        end
        
        if BuffWatchConfig.ShowDebuffs == nil then
            BuffWatchConfig.ShowDebuffs = true
        end
        
        if BuffWatchConfig.AlignBuffs == nil then
            BuffWatchConfig.AlignBuffs = true
        end

        if BuffWatchConfig.ExpiredWarning == nil then
            BuffWatchConfig.ExpiredWarning = true
        end
        
        BuffWatchOptions_Init()
        
    end

    if BuffWatchFrame:IsVisible() then        

        if event == "PLAYER_ENTERING_WORLD" then

            BW_Set_UNIT_IDs()
            BW_GetAllBuffs()
            
        end

        if event == "SPELLCAST_START" then
            lastspellcast = arg1
        end

        if event == "UNIT_AURA" then

            for i=1,table.getn(UNIT_IDs) do
            
                if arg1 == UNIT_IDs[i] then
                    BW_Player_GetBuffs(i)
                    break
                end
                
            end
            
        end

        if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or (event == "UNIT_PET" and BuffWatchConfig.ShowPets == true) then

            BW_Set_UNIT_IDs()
            BW_GetAllBuffs()
            BW_UpdateBuffStatus()
            BW_ResizeWindow()
            
        end
        
    end
    
end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //
-- //                Main Functions
-- //
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_Set_UNIT_IDs(forced)

    local numRaidMembers = GetNumRaidMembers();

    if numRaidMembers > 0 then

        if lastgrouptype ~= "raid" or forced == true then

            UNIT_IDs = { }
            
            for i=1,40 do
                UNIT_IDs[i] = "raid" .. i
            end
            
            if BuffWatchConfig.ShowPets == true then
                for i=1,40 do
                    UNIT_IDs[i+40] = "raidpet" ..    i
                end
            elseif lastgrouptype == "raid" then
                for i = 41, 80 do
                    if getglobal("BW_Player" .. i):IsVisible() then
                        getglobal("BW_Player" .. i):Hide()
                        getglobal("BW_Player" .. i .. "_Name"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):SetText(nil)
                    end
                end         
            end

            lastgrouptype = "raid"
            
        end

    elseif lastgrouptype ~= "party" or forced == true then

        UNIT_IDs = { }
        
        UNIT_IDs[1] = "player"
        UNIT_IDs[2] = "party1"
        UNIT_IDs[3] = "party2"
        UNIT_IDs[4] = "party3"
        UNIT_IDs[5] = "party4"
        
        if BuffWatchConfig.ShowPets == true then
            UNIT_IDs[6] = "pet"
            UNIT_IDs[7] = "partypet1"
            UNIT_IDs[8] = "partypet2"
            UNIT_IDs[9] = "partypet3"
            UNIT_IDs[10] = "partypet4"
            
            if lastgrouptype == "raid" then
            
                for i = 11, 80 do
                    if getglobal("BW_Player" .. i):IsVisible() then
                        getglobal("BW_Player" .. i):Hide()
                        getglobal("BW_Player" .. i .. "_Name"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):SetText(nil)
                    end
                end
                
            end
            
        else

            if lastgrouptype == "raid" then
                for i = 6, 40 do
                    if getglobal("BW_Player" .. i):IsVisible() then
                        getglobal("BW_Player" .. i):Hide()
                        getglobal("BW_Player" .. i .. "_Name"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):SetText(nil)
                    end
                end         
            else
                for i = 6, 10 do
                    if getglobal("BW_Player" .. i):IsVisible() then
                        getglobal("BW_Player" .. i):Hide()
                        getglobal("BW_Player" .. i .. "_Name"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):Hide()
                        getglobal("BW_Player" .. i .. "_NameText"):SetText(nil)
                    end
                end 
            end
        end

        lastgrouptype = "party"

    end
end


function BW_GetAllBuffs()

    local firstvisibleplayer = true
    local previousvisibleplayer
    
    buttonalignposition = 0

    for i=1,table.getn(UNIT_IDs) do

        local curr_playerframe = getglobal("BW_Player" .. i)
        local curr_name_button = getglobal("BW_Player" .. i .. "_Name")
        local curr_name_fontstring = getglobal("BW_Player" .. i .. "_NameText")
        local curr_lock = getglobal("BW_Player" .. i .. "_Lock")

        local unitname = UnitName(UNIT_IDs[i])

        if unitname == nil then

            curr_playerframe:Hide()
            curr_name_button:Hide()
            curr_name_fontstring:Hide()
            curr_name_fontstring:SetText(nil)

        else

            curr_playerframe:Show()
            curr_name_button:Show()
            curr_name_fontstring:Show()
            curr_name_fontstring:SetText(unitname)
            curr_name_button:SetWidth(curr_name_fontstring:GetStringWidth())
            
            if BuffWatchConfig.AlignBuffs == true then

                if buttonalignposition < curr_name_fontstring:GetStringWidth() then
                    buttonalignposition = curr_name_fontstring:GetStringWidth()
                end
            
            end

            local className = UnitClass(UNIT_IDs[i])
            
            if (className) then 
            
                className = string.upper(className)
                local color = RAID_CLASS_COLORS[className]
                
                if (color) then
                    curr_name_fontstring:SetTextColor(color.r, color.g, color.b)
                else
                    curr_name_fontstring:SetTextColor(1, 1, 1)
                end
                
            else
                curr_name_fontstring:SetTextColor(1, 1, 1)
            end

            if firstvisibleplayer then

                curr_name_button:ClearAllPoints()
                curr_name_button:SetPoint("TOPLEFT","BuffWatchBackdropFrame","TOPLEFT",15,-15)
                previousvisibleplayer = i
                firstvisibleplayer = false

            else

                curr_name_button:ClearAllPoints()
                curr_name_button:SetPoint("TOPLEFT","BW_Player" .. previousvisibleplayer .. "_Name","BOTTOMLEFT",0,0)
                previousvisibleplayer = i

            end
            
            curr_lock:ClearAllPoints()
            curr_lock:SetPoint("TOPRIGHT","BW_Player" .. i .. "_Name","TOPLEFT",1,-2)

        end

    end
    
    for i=1,table.getn(UNIT_IDs) do
        BW_Player_GetBuffs(i)
    end

end


function BW_Player_GetBuffs(i)

    local curr_lock = getglobal("BW_Player" .. i .. "_Lock")

    if not curr_lock:GetChecked() then

        for j=1,16 do

            local unit = UNIT_IDs[i]

            local texture = UnitBuff(unit,j)
            local curr_buff = getglobal("BW_Player" .. i .. "_Buff" .. j)
            local curr_buff_icon = getglobal("BW_Player" .. i .. "_Buff" .. j .. "Icon")
            local curr_buff_iconpath = getglobal("BW_Player" .. i .. "_Buff" .. j .. "TexturePath")

            if texture == nil then

                curr_buff:Hide()
                curr_buff_icon:Hide()
                curr_buff_iconpath:Hide()
                curr_buff_iconpath:SetText(nil)

            elseif texture then

                curr_buff:Show()
                curr_buff_icon:SetTexture(texture)
                curr_buff_icon:Show()
                curr_buff_iconpath:SetText(texture)
                curr_buff_iconpath:Hide()

            end

        end
    
    end

    for j=1,16 do

        local unit = UNIT_IDs[i]

        local texture = UnitDebuff(unit,j)
        local curr_buff = getglobal("BW_Player" .. i .. "_Debuff" .. j)
        local curr_buff_icon = getglobal("BW_Player" .. i .. "_Debuff" .. j .. "Icon")
        local curr_buff_iconpath = getglobal("BW_Player" .. i .. "_Debuff" .. j .. "TexturePath")

        if texture == nil or BuffWatchConfig.ShowDebuffs == false then

            curr_buff:Hide()
            curr_buff_icon:Hide()
            curr_buff_iconpath:Hide()
            curr_buff_iconpath:SetText(nil)

        elseif texture then

            curr_buff:Show()
            curr_buff_icon:SetTexture(texture)
            curr_buff_icon:Show()
            curr_buff_iconpath:SetText(texture)
            curr_buff_iconpath:Hide()

        end

    end
    
    BW_Player_AdjustBuffs(i)
    
end


function BW_Player_AdjustBuffs(i)

    local firstvisiblebutton = true
    local previousvisiblebutton

    for j=1,16 do

        local curr_buff = getglobal("BW_Player" .. i .. "_Buff" .. j)

        if curr_buff:IsVisible() then

            curr_buff:ClearAllPoints()

            if firstvisiblebutton then
                if buttonalignposition == 0 then
                    curr_buff:SetPoint("TOPLEFT","BW_Player" .. i .. "_NameText","TOPRIGHT",5,2)
                else
                    curr_buff:SetPoint("TOPLEFT","BW_Player" .. i .. "_NameText","TOPLEFT",buttonalignposition + 5,2)
                end                    
                firstvisiblebutton = false
                previousvisiblebutton = j
            else
                curr_buff:SetPoint("TOPLEFT","BW_Player" .. i .. "_Buff" .. previousvisiblebutton,"TOPRIGHT",0,0)
                previousvisiblebutton = j
            end
            
        end
        
    end

    local firstvisibledebuff = true
    local previousvisibledebuff

    for j=1,16 do

        local curr_debuff = getglobal("BW_Player" .. i .. "_Debuff" .. j)

        if curr_debuff:IsVisible() then

            curr_debuff:ClearAllPoints()

            if firstvisiblebutton then

                if buttonalignposition == 0 then
                    curr_debuff:SetPoint("TOPLEFT","BW_Player" .. i .. "_NameText","TOPRIGHT",5,2)
                else
                    curr_debuff:SetPoint("TOPLEFT","BW_Player" .. i .. "_NameText","TOPLEFT",buttonalignposition + 5,2)
                end
                firstvisiblebutton = false
                previousvisiblebutton = j
                firstvisibledebuff = false
                previousvisibledebuff = j

            elseif firstvisibledebuff then

                curr_debuff:SetPoint("TOPLEFT","BW_Player" .. i .. "_Buff" .. previousvisiblebutton,"TOPRIGHT",0,0)
                firstvisibledebuff = false
                previousvisibledebuff = j

            else

                curr_debuff:SetPoint("TOPLEFT","BW_Player" .. i .. "_Debuff" .. previousvisibledebuff,"TOPRIGHT",0,0)
                previousvisibledebuff = j

            end
            
        end
        
    end

end


function BW_UpdateBuffStatus()

    local hasbuffexpired = false

    for i=1,table.getn(UNIT_IDs) do
    
        local playerframe = "BW_Player" .. i
        
        if getglobal(playerframe):IsVisible() then

            for j=1,16 do
            
                if getglobal(playerframe .. "_Buff" .. j):IsVisible() then
                
                    local Flag_BuffFound = false
    
                    for k=1,16 do
                        if UnitBuff(UNIT_IDs[i],k) == getglobal(playerframe .. "_Buff" .. j .. "TexturePath"):GetText() then
                            Flag_BuffFound = true
                        end
                    end
    
                    if Flag_BuffFound then
                        getglobal(playerframe .. "_Buff" .. j .. "Icon"):SetVertexColor(1,1,1)
                    else
                        getglobal(playerframe .. "_Buff" .. j .. "Icon"):SetVertexColor(1,0,0)
                        
                        if BuffWatchConfig.ExpiredWarning and buffexpired ~= true then
                            UIErrorsFrame:AddMessage("A buffwatch monitored buff has expired!", 0.2, 0.9, 0.9, 1.0, UIERRORS_HOLD_TIME * 2)
                            buffexpired = true
                        end
                        hasbuffexpired = true
                    end

                end
                
            end
            
        end
        
    end
    
    buffexpired = hasbuffexpired

end


function BW_ResizeWindow()

    local rightcoord = 0
    local bottomcoord = 0
    local width = 0
    local height = 0

    for i=1,table.getn(UNIT_IDs) do

        local curr_name_button = getglobal("BW_Player" .. i .. "_Name")
        local curr_name_fontstring = getglobal("BW_Player" .. i .. "_NameText")

        if curr_name_fontstring:GetText() then --isvisible
            bottomcoord = curr_name_button:GetBottom()
        end

        for j=1,16 do
            local curr_buff = getglobal("BW_Player" .. i .. "_Buff" .. j)

            if curr_buff:IsVisible() and curr_buff:GetRight() then
                if curr_buff:GetRight() > rightcoord then
                    rightcoord = curr_buff:GetRight()
                end
            end
        end

        for j=1,16 do
            local curr_buff = getglobal("BW_Player" .. i .. "_Debuff" .. j)

            if curr_buff:IsVisible() and curr_buff:GetRight() then
                if curr_buff:GetRight() > rightcoord then
                    rightcoord = curr_buff:GetRight()
                end
            end
        end

    end

    if rightcoord and rightcoord ~= 0 then
        width = rightcoord - BuffWatchBackdropFrame:GetLeft()
        if width < 90 then width = 90 end
    end
    if bottomcoord and bottomcoord ~= 0 then
        height = BuffWatchBackdropFrame:GetTop() - bottomcoord
    end

    if width > 0 then
        BuffWatchBackdropFrame:SetWidth(width + 15)
        BuffWatchFrame:SetWidth(width + 15)
    else
        BuffWatchBackdropFrame:SetWidth(150)
        BuffWatchFrame:SetWidth(150)
    end
    
    if height > 0 then
        BuffWatchBackdropFrame:SetHeight(height + 15)
        BuffWatchFrame:SetHeight(height + 15)
    else
        BuffWatchBackdropFrame:SetHeight(50)
        BuffWatchFrame:SetHeight(50)
    end

end

function BW_Set_AllChecks(checked)
    
    for i=1,table.getn(UNIT_IDs) do
    
        local curr_lock = getglobal("BW_Player" .. i .. "_Lock")
        
        if curr_lock:IsVisible() then
            curr_lock:SetChecked(checked)
        end
    
    end

end

function BW_TimeControl(Time_Interval, Time_Precision)

    local blah = math.mod(GetTime(), Time_Interval)

    if blah <= Time_Precision then
        return true
    else
        return false
    end

end

function BW_MouseIsOverFrame()

    if MouseIsOver(BuffWatchFrame) then

        BuffWatchFrameHeader:Show()
        BuffWatchFrameHeaderText:Show()
        BW_AllPlayer_Lock:Show()
        BuffWatchOptionsButton:Show()

        for i=1,table.getn(UNIT_IDs) do
            if getglobal("BW_Player" .. i .. "_Name"):IsVisible() then
                getglobal("BW_Player" .. i .. "_Lock"):Show()
            end
        end

    else

        BuffWatchFrameHeader:Hide()
        BuffWatchFrameHeaderText:Hide()
        BW_AllPlayer_Lock:Hide()
        BuffWatchOptionsButton:Hide()

        for i=1,table.getn(UNIT_IDs) do
            getglobal("BW_Player" .. i .. "_Lock"):Hide()
        end

    end

end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //
-- //                Slash Commands
-- //
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_SlashHandler(msg)

    msg = string.lower(msg)

    local index = string.find(msg, " ")

    if index then

        param = string.sub(msg, index+1)
        msg = string.sub(msg, 1, index-1)

    end

    if msg == "alpha" and tonumber(param) and tonumber(param) <= 1 and tonumber(param) >= 0 then

        BuffWatchConfig.alpha = param
        BuffWatchBackdropFrame:SetAlpha(BuffWatchConfig.alpha)
        BW_Print("BuffWatch window opacity set to: " .. BuffWatchConfig.alpha)
        BuffWatchOptions_Init()

    elseif msg == "toggle" then

        BW_Toggle()

    elseif msg == "set" then

        BW_SetRightMouse()

    elseif msg == "showonstartup" then

        BuffWatchConfig.show_on_startup = true
        BW_Print("BuffWatch window will now be shown on startup.", 0.2, 0.9, 0.9 )
        BuffWatchOptions_Init()

    elseif msg == "hideonstartup" then

        BuffWatchConfig.show_on_startup = false
        BW_Print("BuffWatch window will now be hidden on startup.", 0.2, 0.9, 0.9 )
        BuffWatchOptions_Init()
        
    elseif msg == "pets" then
    
        if BuffWatchConfig.ShowPets == false then    
            BuffWatchConfig.ShowPets = true
            BW_Print("BuffWatch will now show pets.", 0.2, 0.9, 0.9 )
        else    
            BuffWatchConfig.ShowPets = false
            BW_Print("BuffWatch will now hide pets.", 0.2, 0.9, 0.9 )
        end
        
        BW_Set_UNIT_IDs(true)
        BW_GetAllBuffs()
        BW_UpdateBuffStatus()
        BW_ResizeWindow()
        BuffWatchOptions_Init()
        
    elseif msg == "debuffs" then
    
        if BuffWatchConfig.ShowDebuffs == false then    
            BuffWatchConfig.ShowDebuffs = true
            BW_Print("BuffWatch will now show debuffs.", 0.2, 0.9, 0.9 )
        else    
            BuffWatchConfig.ShowDebuffs = false
            BW_Print("BuffWatch will now hide debuffs.", 0.2, 0.9, 0.9 )
        end
        
        BuffWatchOptions_Init()
        
    elseif msg == "alignbuffs" then
    
        if BuffWatchConfig.AlignBuffs == false then    
            BuffWatchConfig.AlignBuffs = true
            BW_Print("BuffWatch will align buffs.", 0.2, 0.9, 0.9 )
        else    
            BuffWatchConfig.AlignBuffs = false
            BW_Print("BuffWatch will not align buffs.", 0.2, 0.9, 0.9 )
        end
        
        BuffWatchOptions_Init()
    
    elseif msg == "expiredwarning" then
    
        if BuffWatchConfig.ExpiredWarning == false then    
            BuffWatchConfig.ExpiredWarning = true
            BW_Print("BuffWatch warning message will be displayed.", 0.2, 0.9, 0.9 )
        else    
            BuffWatchConfig.ExpiredWarning = false
            BW_Print("BuffWatch message will not be displayed.", 0.2, 0.9, 0.9 )
        end
        
        BuffWatchOptions_Init()    	

    elseif msg == "options" then
    
        BW_OptionsToggle()
    
    elseif msg == "" or msg == "help" then

        BW_ShowHelp()

    else

        BW_Print("BuffWatch: Invalid Command or Parameter")

    end

end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Slash Command Functions
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_Toggle()

    if not BuffWatchFrame:IsVisible() then
        ShowUIPanel(BuffWatchFrame)
    else
        HideUIPanel(BuffWatchFrame)
    end

end

function BW_OptionsToggle()

    if not BuffWatchOptionsFrame:IsVisible() then
        ShowUIPanel(BuffWatchOptionsFrame)
    else
        HideUIPanel(BuffWatchOptionsFrame)
    end

end

function BW_SetRightMouse()

    if lastspellcast == nil then

        BW_Print("     BuffWatch: You have not cast any timed spells yet:")
        BW_Print("                        Cast one, and then try \"/bw set\" again")

    else

        for i=1,300 do
            if GetSpellName(i,1) == lastspellcast then
                BuffWatchConfig.rightMouseSpell = i
--                    break
            end
        end

        if BuffWatchConfig.rightMouseSpell then
            BW_Print( format("BuffWatch: Right mouse button set to %s (%s)",
              GetSpellName(BuffWatchConfig.rightMouseSpell,1) ), 0.2, 0.9, 0.9 )
        end

    end

end


-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //
-- //                Mouse Functions
-- //
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_OnMouseDown(arg1)
    if arg1 == "LeftButton" then
        BuffWatchFrame:StartMoving()
    end
end


function BW_OnMouseUp(arg1)
    if arg1 == "LeftButton" then
        BuffWatchFrame:StopMovingOrSizing()
    end
end


function BW_Name_Clicked(button)

    local id = this:GetParent():GetID()
    
    local playername = getglobal("BW_Player" .. id .. "_NameText"):GetText()

    if button == "LeftButton" then
    
        if playername then
            TargetByName(playername)
        end
        
    elseif button == "RightButton" then
        AssistByName(playername)
    end
    
end


function BW_Check_Clicked()

    local checked = this:GetChecked()

    if checked then

        for i=1,table.getn(UNIT_IDs) do

            local curr_lock = getglobal("BW_Player" .. i .. "_Lock")

            if curr_lock:IsVisible() then            
                if not curr_lock:GetChecked() then
                    checked = nil
                    break
                end                                
            end

        end 
        
        if checked then
            BW_AllPlayer_Lock:SetChecked(true)
        end
    
    else
        BW_AllPlayer_Lock:SetChecked(false)    
    end
end


function BW_Buff_Clicked(button)

    local buffid = this:GetID()
    local playerid = this:GetParent():GetID()    
    local playername = getglobal("BW_Player" .. playerid .. "_NameText"):GetText()
    local playerframe =  "BW_Player" .. playerid

    if button == "LeftButton" then

        local spellid = nil

        for i=1,300 do
            if GetSpellTexture(i,1) == getglobal(this:GetName() .. "TexturePath"):GetText() then
                spellid = i
--BW_Print("Matched : " .. GetSpellTexture(i,1))
--                    break
            end
        end
        
        if UnitIsVisible(Dcr_NameToUnit(playername)) then

            if UnitName("target") and not UnitIsEnemy("target","player") then
                if UnitName("target") ~= playername then
                    TargetByName(playername)
                end
            end
    
            if IsShiftKeyDown() then
                SendChatMessage(format("BW: Casting %s on %s", GetSpellName(spellid,1), playername), "PARTY")
            end
 
            if spellid then CastSpell(spellid,1) end

            if SpellIsTargeting() then
                TargetByName(playername)
            end
        
        else
        
            BW_Print(playername .. " is out of range or not visible.")
            
        end

    elseif button == "RightButton" then

        if getglobal(playerframe .. "_Lock"):GetChecked() and IsControlKeyDown() then

            this:Hide()
            BW_Player_AdjustBuffs(playerid)
            BW_ResizeWindow()

        elseif getglobal(playerframe .. "_Lock"):GetChecked() and IsAltKeyDown() then
        
            for i=1,16 do
                if i ~= buffid then
                    getglobal(playerframe .. "_Buff" .. i):Hide()
                end
            end
            
            BW_Player_AdjustBuffs(playerid)
            BW_ResizeWindow()
            
        else

            if BuffWatchConfig.rightMouseSpell then
                if UnitName("target") and not UnitIsEnemy("target","player") then
                    if UnitName("target") ~= playername then
                        TargetByName(playername)
                    end
                end

                if IsShiftKeyDown() then
                    SendChatMessage(format("BW: Casting %s on %s", GetSpellName(BuffWatchConfig.rightMouseSpell,1), playername), "PARTY")
                end

                CastSpell(BuffWatchConfig.rightMouseSpell,1)

                if SpellIsTargeting() then
                    TargetByName(playername)
                end

            else

                BW_Print("     BuffWatch: Right mouse button spell has not yet been set.")
                BW_Print("                Cast any spell with a duration. Then type \"/bw set\"")

            end

        end

    end

end


function BW_BuffTooltip()
 
    local id = this:GetParent():GetID()

    local buffbuttonid = nil
    local debuffbuttonid = nil
    local texture = getglobal(this:GetName() .. "TexturePath"):GetText()

    for i=1,16 do
        if UnitBuff( UNIT_IDs[id],i ) == texture then
            buffbuttonid = i
            break
        end
    end

    if buffbuttonid == nil then
        for i_2=1,16 do
            if UnitDebuff( UNIT_IDs[id],i_2 ) == texture then
                debuffbuttonid = i_2
                break
            end
        end
    end

    if buffbuttonid then
        GameTooltip:SetOwner( this, "ANCHOR_BOTTOM" )
        GameTooltip:SetUnitBuff( UNIT_IDs[id], buffbuttonid )
    elseif debuffbuttonid then
        GameTooltip:SetOwner( this, "ANCHOR_BOTTOM" )
        GameTooltip:SetUnitDebuff( UNIT_IDs[id], debuffbuttonid )
    end
end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //
-- //                Other Stuff
-- //
-- //
-- //////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- // showAllUnitBuffs()
-- //
-- // Purpose: Queries the texture name of a buff
-- // Usage:
-- //        /script showAllUnitBuffs("player")
-- //        /script showAllUnitBuffs("target")
-- // Example Output: Interface\Icons\Spell_Holy_FistOfJustice
-- // Source: http://www.wowwiki.com/Check_Hunter_Aspect
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function showAllUnitBuffs(sUnitname)
    local iIterator = 1
    DEFAULT_CHAT_FRAME:AddMessage(format("[%s] Buffs", sUnitname))
    while (UnitBuff(sUnitname, iIterator)) do
        DEFAULT_CHAT_FRAME:AddMessage(UnitBuff(sUnitname, iIterator), 1, 1, 0)
        iIterator = iIterator + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("---", 1, 1, 0)
end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- // Dcr_NameToUnit()
-- // Borrowed from the decursive mod :)
-- //
-- // Raid/Party Name Check Function
-- // this returns the UnitID that the Name points to
-- // this does not check "target" or "mouseover"
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function Dcr_NameToUnit(Name)
        if (not Name) then
                return false;
        elseif (Name == UnitName("player")) then
                return "player";
        elseif (Name == UnitName("pet")) then
                return "pet";
        elseif (Name == UnitName("party1")) then
                return "party1";
        elseif (Name == UnitName("party2")) then
                return "party2";
        elseif (Name == UnitName("party3")) then
                return "party3";
        elseif (Name == UnitName("party4")) then
                return "party4";
        elseif (Name == UnitName("partypet1")) then
                return "partypet1";
        elseif (Name == UnitName("partypet2")) then
                return "partypet2";
        elseif (Name == UnitName("partypet3")) then
                return "partypet3";
        elseif (Name == UnitName("partypet4")) then
                return "partypet4";
        else
                local numRaidMembers = GetNumRaidMembers();
                if (numRaidMembers > 0) then
                        -- we are in a raid
                        local i;
                        for i=1, numRaidMembers do
                                local RaidName = GetRaidRosterInfo(i);
                                if ( Name == RaidName) then
                                        return "raid"..i;
                                end
                                if ( Name == UnitName("raidpet"..i)) then
                                        return "raidpet"..i;
                                end
                        end
                end
        end
        return false;
end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //    BuffWatch Print Function
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_Print(msg, R, G, B)

    DEFAULT_CHAT_FRAME:AddMessage(msg, R, G, B);

end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //    BuffWatch Help
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_ShowHelp()

    BW_HelpFrame:Show()
    BW_HelpFrame:ClearAllPoints()
    BW_HelpFrame:SetPoint("CENTER","UIParent","CENTER",0,-32)

    BW_HelpFrame_Text:SetText(

        [[
        - BuffWatch Usage - v 0.621 -

        Show/Hide the BuffWatch window:
             - Bind a keyboard button to show/hide the window
             - You can also close it by right clicking the "BuffWatch" label (appears on mouseover)

        Showing Buffs:
             - Left click the BuffWatch label
             - Also occurs automatically whenever your gain/lose a party or raid member

        Locking a player's watched buffs:
             - If the checkbox to the left is unchecked, buffs will be added automatically whenever they gain a buff
             - If checked, buffs will not be added

        Rebuffing:
             - Left click an icon (will auto-target)

        Right click spell:
             - Cast any spell with a cast time (not instant). Then type "/bw set"
             - To cast it, right click any icon (will auto-target)

        Deleting buffs:
             - Lock the player's buffs (check the box). Then [ CTRL + Right Click ] on the buff
             - Optionally, [ ALT + Right Click ] to delete all but the selected one.

        Slash Commands ( Use /buffwatch or /bw )
             - /bw alpha # : Set the background opacity (0.0 to 1.0)
             - /bw toggle : shows/hides the window
             - /bw [showonstartup / hideonstartup] : set to show or hide the window on startup
             - /bw pets : toggle to show or hide pets in the buffwatch window
             - /bw debuffs : toggle to show or hide debuffs in the buffwatch window
             - /bw alignbuffs : toggle aligning of buff icons
             - /bw expiredwarning : toggle expired buff warning message
             - /bw options : shows/hides the options window
             - /bw : shows this help menu :)

        Verbosity:
             - Hold [ Shift ] while left or right-clicking a buff icon to send a cast message to your party
        ]] )

end

-- //////////////////////////////////////////////////////////////////////////////////////
