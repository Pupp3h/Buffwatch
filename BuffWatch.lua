-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- // BuffWatch
-- //     by Pup
-- //
-- // TODO:
-- //
-- //     Window doesnt always properly resize
-- // 
-- //     Option to hide players with no locked buffs
-- //
-- //     Only show castable buffs (key combination to override this for a player?)
-- //     Keybinding to scan list and recast any expired buffs (probably need to tie in with above)
-- //     Show poisons and weapon buffs for player
-- //     Lower spell rank support
-- //     Allow cleansing of debuffs
-- //     Option to only show debuffs I can cleanse
-- //     Option to split into columns
-- //     UI Scaling
-- // 
-- // CHANGES:
-- //
-- //
-- //////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Variables
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

BINDING_HEADER_BUFFWATCHHEADER = "BuffWatch"
BW_SORTORDER_DROPDOWN_LIST = {
    "Raid Order",
    "Class",
    "Name"
}

BuffWatchConfig = { alpha, rightMouseSpell, show_on_startup, 
    ShowPets, ShowDebuffs, AlignBuffs, ExpiredWarning, SortOrder }

local lastspellcast
local lastgrouptype
local buttonalignposition
local buffexpired
local minimized

local Player_Info = { }
local Player_Left = { }
local UNIT_IDs = { }

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Events
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_OnLoad()

    this:RegisterEvent("PLAYER_LOGIN")
    this:RegisterEvent("PARTY_MEMBERS_CHANGED")
    this:RegisterEvent("RAID_ROSTER_UPDATE")
    this:RegisterEvent("SPELLCAST_START")
    this:RegisterEvent("UNIT_AURA")
    this:RegisterEvent("UNIT_PET")
    this:RegisterEvent("VARIABLES_LOADED")

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
                version = "1.01",
                releaseDate = "October 30, 2005",
                author = "Tyrrael & Pup",
                category = MYADDONS_CATEGORY_OTHERS,
                frame = "BW",
                optionsframe = "BW_Options"
            }

            BuffWatchHelp = { "              - BuffWatch Usage - v 1.01 -\n\n" ..
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
                "    - /bw toggle : shows/hides the window\n" ..
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
        if EarthFeature_AddButton then
            EarthFeature_AddButton({
                id = "BuffWatch";
                name = "BuffWatch";
                subtext = "Buff monitoring";
                tooltip = "Monitor Party or Raid buffs";
                icon = "Interface\\Icons\\INV_Misc_Spyglass_03";
                callback = BW_OptionsToggle;
                test = nil
            })
        elseif Cosmos_RegisterButton then
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
        if CT_RegisterMod then
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
        
        BW_Print("BuffWatch loaded. Please type \"/buffwatch\" or \"/bw\" for usage. Use \"/bw toggle\" to show window.", 0.2, 0.9, 0.9 )
        
        getglobal("BW_HeaderText"):SetText("BuffWatch")
        getglobal("BW_HeaderText"):SetTextColor(0.2, 0.9, 0.9)
        BW_Background:SetBackdropBorderColor(0, 0, 0)

        if BuffWatchConfig.alpha == nil then
            BuffWatchConfig.alpha = 0.5
        end
        
        BW_Background:SetAlpha(BuffWatchConfig.alpha)

        if BuffWatchConfig.show_on_startup == nil then
            BuffWatchConfig.show_on_startup = true
            BW:Show()
        elseif BuffWatchConfig.show_on_startup == true then
            BW:Show()
        elseif BuffWatchConfig.show_on_startup == false then
            BW:Hide()
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
        
        if BuffWatchConfig.SortOrder == nil then
            BuffWatchConfig.SortOrder = BW_SORTORDER_DROPDOWN_LIST[1]
        end

        BW_Options_Init()
        
    end

    if BW:IsVisible() then        

        if event == "PLAYER_LOGIN" then

            BW_Set_UNIT_IDs()
            BW_GetAllBuffs()
--BW_Print("PLAYER_LOGIN")
            BW_ResizeWindow()
        end

        if event == "SPELLCAST_START" then
            lastspellcast = arg1
        end

        if event == "UNIT_AURA" then

            for k, v in Player_Info do
            
                if arg1 == v.UNIT_ID then
                    BW_Player_GetBuffs(v)
--BW_Print("UNIT_AURA")                    
                    BW_ResizeWindow()
                    break
                end
                
            end
            
            BW_UpdateBuffStatus()
            
        end

        if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" or (event == "UNIT_PET" and BuffWatchConfig.ShowPets == true) then

            BW_Set_UNIT_IDs()
            BW_GetAllBuffs()
--BW_Print("PARTY_CHANGED")
            BW_ResizeWindow()
            
        end
                
    end
    
end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Main Functions
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_Set_UNIT_IDs(forced)

    local numRaidMembers = GetNumRaidMembers()

    if numRaidMembers > 0 then

        if lastgrouptype ~= "raid" or forced == true then

            UNIT_IDs = { }
            
            for i = 1, 40 do
                UNIT_IDs[i] = "raid" .. i
            end
            
            if BuffWatchConfig.ShowPets == true then
                for i = 1, 40 do
                    UNIT_IDs[i+40] = "raidpet" ..    i
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
        end

        lastgrouptype = "party"

    end
    
    BW_GetPlayerInfo()
    
end


function BW_GetPlayerInfo()

    for i = 1, table.getn(UNIT_IDs) do

        local unitname = UnitName(UNIT_IDs[i])

        if unitname ~= nil and unitname ~= "Unknown Entity" then

            if not Player_Info[unitname] then

                local id = BW_GetNextID(unitname)
                
                Player_Info[unitname] = { }
                Player_Info[unitname]["ID"] = id
                Player_Info[unitname]["Name"] = unitname
                
                local classname = UnitClass(UNIT_IDs[i])
                
                if classname then
                    Player_Info[unitname]["Class"] = string.upper(classname)
                else
                    Player_Info[unitname]["Class"] = ""
                end
                
                if (lastgrouptype == "party" and i > 5) or (lastgrouptype == "raid" and i > 40) then
                    Player_Info[unitname]["IsPet"] = 1
                else
                    Player_Info[unitname]["IsPet"] = 0
                end

            end

            Player_Info[unitname]["UNIT_ID"] = UNIT_IDs[i]
            
            if lastgrouptype == "raid" then
                local j = math.mod(i, 40)
                if j == 0 then j = 40 end
                _, _, Player_Info[unitname]["SubGroup"] = GetRaidRosterInfo(j)
            else
                Player_Info[unitname]["SubGroup"] = 1
            end
            
            Player_Info[unitname]["Checked"] = 1

        end

    end

    for k, v in Player_Info do

        if v.Checked == 1 then
            v.Checked = 0
        else
            getglobal("BW_Player" .. v.ID):Hide()
            getglobal("BW_Player" .. v.ID .. "_NameText"):SetText(nil)
            
            Player_Left[v.Name] = v.ID
            
            Player_Info[k] = nil
        end

    end
    
end


function BW_GetAllBuffs()

    local firstplayer = true
    local previousplayer
    local Player_Copy = { }

    buttonalignposition = 0    
    
    for k, v in Player_Info do
        table.insert(Player_Copy, v)
    end

    if BuffWatchConfig.SortOrder == "Class" then
    
        table.sort(Player_Copy, 
        function(a,b) 
                    
            if a.IsPet == b.IsPet then
            
                if a.Class == b.Class then 
                    return a.Name < b.Name
                else
                    return a.Class < b.Class
                end
            
            else
                return a.IsPet < b.IsPet
            end

        end)
        
    elseif BuffWatchConfig.SortOrder == "Name" then

        table.sort(Player_Copy,
        function(a,b) 

            if a.IsPet == b.IsPet then
                return a.Name < b.Name
            else
                return a.IsPet < b.IsPet
            end
            
        end)
                
    else -- Default

        table.sort(Player_Copy,
        function(a,b) 
        
            if a.IsPet == b.IsPet then
            
                if a.SubGroup == b.SubGroup then
                    return a.UNIT_ID < b.UNIT_ID
                else
                    return a.SubGroup < b.SubGroup
                end
                
            else        
                return a.IsPet < b.IsPet
            end
            
        end)   
    end
    
    for k, v in Player_Copy do
--BW_Print(v.ID .. " - " .. v.Name .. " - " .. v.Class .. " - Pet " .. v.IsPet .. " - " .. v.UNIT_ID .. " - " .. v.SubGroup) 
        local playerframe = getglobal("BW_Player" .. v.ID)
        local namebutton = getglobal("BW_Player" .. v.ID .. "_Name")
        local nametext = getglobal("BW_Player" .. v.ID .. "_NameText")
        local lock = getglobal("BW_Player" .. v.ID .. "_Lock")
        
        if minimized then
            playerframe:Hide()
        else
            
            lock:ClearAllPoints()
            
            if firstplayer then
                lock:SetPoint("TOPLEFT", "BW_Background", "TOPLEFT", 1, -18)
                previousplayer = v.ID
                firstplayer = false
            else
                lock:SetPoint("TOPLEFT", "BW_Player" .. previousplayer .. "_Lock", "BOTTOMLEFT", 0, -2)
                previousplayer = v.ID
            end

            nametext:SetText(v.Name)
            namebutton:SetWidth(nametext:GetStringWidth())                        

            if BuffWatchConfig.AlignBuffs == true then

                if buttonalignposition < nametext:GetStringWidth() then
                    buttonalignposition = nametext:GetStringWidth()
                end

            end

            if v.Class ~= "" then 

                local color = RAID_CLASS_COLORS[v.Class]

                if color then
                    nametext:SetTextColor(color.r, color.g, color.b)
                else
                    nametext:SetTextColor(1, 1, 1)
                end

            else
                nametext:SetTextColor(1, 1, 1)
            end

            playerframe:Show()
            
        end
        
    end
    
    for k, v in Player_Info do
        BW_Player_GetBuffs(v)
    end
    
end


function BW_Player_GetBuffs(v)
    
    local curr_lock = getglobal("BW_Player" .. v.ID .. "_Lock")

    if not curr_lock:GetChecked() then

        for j = 1, 16 do

            local texture = UnitBuff(v.UNIT_ID, j)
            local curr_buff = getglobal("BW_Player" .. v.ID .. "_Buff" .. j)
            local curr_buff_icon = getglobal("BW_Player" .. v.ID .. "_Buff" .. j .. "Icon")
            local curr_buff_iconpath = getglobal("BW_Player" .. v.ID .. "_Buff" .. j .. "TexturePath")

            if texture == nil then

                curr_buff:Hide()
                curr_buff_icon:Hide()
                curr_buff_iconpath:SetText(nil)

            elseif texture then

                curr_buff:Show()
                curr_buff_icon:SetTexture(texture)
                curr_buff_icon:Show()
                curr_buff_iconpath:SetText(texture)

            end

        end

    end

    for j = 1, 16 do

        local texture = UnitDebuff(v.UNIT_ID, j)
        local curr_buff = getglobal("BW_Player" .. v.ID .. "_Debuff" .. j)
        local curr_buff_icon = getglobal("BW_Player" .. v.ID .. "_Debuff" .. j .. "Icon")
        local curr_buff_iconpath = getglobal("BW_Player" .. v.ID .. "_Debuff" .. j .. "TexturePath")

        if texture == nil or BuffWatchConfig.ShowDebuffs == false then

            curr_buff:Hide()
            curr_buff_icon:Hide()
            curr_buff_iconpath:SetText(nil)

        elseif texture then

            curr_buff:Show()
            curr_buff_icon:SetTexture(texture)
            curr_buff_icon:Show()
            curr_buff_iconpath:SetText(texture)

        end

    end
    
    BW_Player_AdjustBuffs(v)    

end


function BW_Player_AdjustBuffs(v)

    local firstbutton = true
    local previousbutton

    for j = 1, 16 do

        local curr_buff = getglobal("BW_Player" .. v.ID .. "_Buff" .. j)

        if curr_buff:IsVisible() then

            curr_buff:ClearAllPoints()

            if firstbutton then
                if buttonalignposition == 0 then
                    curr_buff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_NameText", "TOPRIGHT", 5, 2)
                else
                    curr_buff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_NameText", "TOPLEFT", buttonalignposition + 5, 2)
                end                    
                firstbutton = false
                previousbutton = j
            else
                curr_buff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_Buff" .. previousbutton, "TOPRIGHT", 0, 0)
                previousbutton = j
            end
            
        end
        
    end

    local firstdebuff = true
    local previousdebuff

    for j = 1, 16 do

        local curr_debuff = getglobal("BW_Player" .. v.ID .. "_Debuff" .. j)

        if curr_debuff:IsVisible() then

            curr_debuff:ClearAllPoints()

            if firstbutton then

                if buttonalignposition == 0 then
                    curr_debuff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_NameText", "TOPRIGHT", 5, 2)
                else
                    curr_debuff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_NameText", "TOPLEFT", buttonalignposition + 5, 2)
                end
                firstbutton = false
                previousbutton = j
                firstdebuff = false
                previousdebuff = j

            elseif firstdebuff then

                curr_debuff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_Buff" .. previousbutton, "TOPRIGHT", 0, 0)
                firstdebuff = false
                previousdebuff = j

            else

                curr_debuff:SetPoint("TOPLEFT", "BW_Player" .. v.ID .. "_Debuff" .. previousdebuff, "TOPRIGHT", 0, 0)
                previousdebuff = j

            end
            
        end
        
    end

end


function BW_ResizeWindow()

    local bottomcoord = 0
    local height = 0
    local rightcoord = 0
    local width = 0

    for k, v in Player_Info do

        if not minimized then
            local curr_name_button = getglobal("BW_Player" .. v.ID .. "_Name")
--BW_Print("Player : " .. v.Name .. ", ID : " .. v.ID)            
            if curr_name_button:GetBottom() ~= nil then
--BW_Print("GetBottom = " .. curr_name_button:GetBottom())
                if bottomcoord > curr_name_button:GetBottom() or bottomcoord == 0 then
                    bottomcoord = curr_name_button:GetBottom()
--BW_Print("New Bottom = " .. bottomcoord)
                end
            else                
--BW_Print("GetBottom is nil")                
            end
        end

        for j = 1, 16 do
            local curr_buff = getglobal("BW_Player" .. v.ID .. "_Buff" .. j)
            local curr_buff_iconpath = getglobal("BW_Player" .. v.ID .. "_Buff" .. j .. "TexturePath")
            
            if curr_buff_iconpath:GetText() and curr_buff:GetRight() then
                if curr_buff:GetRight() > rightcoord then
                    rightcoord = curr_buff:GetRight()
                end
            end
        end

        for j = 1, 16 do
            local curr_buff = getglobal("BW_Player" .. v.ID .. "_Debuff" .. j)
            local curr_buff_iconpath = getglobal("BW_Player" .. v.ID .. "_Debuff" .. j .. "TexturePath")
            
            if curr_buff_iconpath:GetText() and curr_buff:GetRight() then
                if curr_buff:GetRight() > rightcoord then
                    rightcoord = curr_buff:GetRight()
                end
            end
        end

    end 

    if minimized then
        height = 20
    else
--BW_Print("Final Bottom = " .. bottomcoord)    
        if bottomcoord and bottomcoord ~= 0 then
            height = BW_Background:GetTop() - bottomcoord + 15
--BW_Print("Background top = " .. BW_Background:GetTop() .. ", Calc Height = " .. height)
            if height < 50 then height = 50 end
        else
            height = 50
        end
    end

    if rightcoord and rightcoord ~= 0 then
        width = rightcoord - BW_Background:GetLeft() + 20
        if width < 100 then width = 100 end
    else
        width = 100
    end 

--BW_Print("Set Height = " .. height)

    BW_Background:SetHeight(height)
    BW:SetHeight(height)
    
    BW_Background:SetWidth(width)
    BW:SetWidth(width)
    
end


function BW_UpdateBuffStatus()

    local hasbuffexpired = false

    for k, v in Player_Info do
    
        local playerframe = "BW_Player" .. v.ID

        for j = 1, 16 do

            if getglobal(playerframe .. "_Buff" .. j .. "TexturePath"):GetText() then

                if UnitIsDeadOrGhost(v.UNIT_ID) or UnitIsConnected(v.UNIT_ID) == nil then

                    getglobal(playerframe .. "_Buff" .. j .. "Icon"):SetVertexColor(0.4,0.4,0.4)

                else

                 local Flag_BuffFound = false

                    for j_2 = 1, 16 do
                        if UnitBuff(v.UNIT_ID, j_2) == getglobal(playerframe .. "_Buff" .. j .. "TexturePath"):GetText() then
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

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Slash Commands
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_SlashHandler(msg)

    msg = string.lower(msg)

    if msg == "toggle" then

        BW_Toggle()

    elseif msg == "set" then

        BW_SetRightMouse()

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
-- //                Mouse Events
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_OnMouseDown(arg1)
    if arg1 == "LeftButton" then
        BW:StartMoving()
    end
end


function BW_OnMouseUp(arg1)
    if arg1 == "LeftButton" then
        BW:StopMovingOrSizing()
    end
end


function BW_MouseIsOverFrame()

    if MouseIsOver(BW) then

        BW_Header:Show()
        BW_HeaderText:Show()        
        BW_MinimizeButton:Show()

        if not minimized then 
        
            BW_OptionsButton:Show()
            BW_Lock_All:Show()

            for k, v in Player_Info do
                getglobal("BW_Player" .. v.ID .. "_Lock"):Show()
            end
            
        else
        
            BW_OptionsButton:Hide()
            BW_Lock_All:Hide()
        
        end

    else

        if not minimized then 
            BW_Header:Hide()
            BW_HeaderText:Hide()
        end
        
        BW_MinimizeButton:Hide()
        BW_OptionsButton:Hide()

        BW_Lock_All:Hide()
        
        for k, v in Player_Info do
            getglobal("BW_Player" .. v.ID .. "_Lock"):Hide()
        end

    end

end


function BW_Check_Clicked()

    local checked = this:GetChecked()

    if checked then

        for k, v in Player_Info do

            local curr_lock = getglobal("BW_Player" .. v.ID .. "_Lock")

            if curr_lock:IsVisible() then            
                if not curr_lock:GetChecked() then
                    checked = nil
                    break
                end                                
            end

        end 
        
        if checked then
            BW_Lock_All:SetChecked(true)
        end
    
    else
        BW_Lock_All:SetChecked(false)    
    end

end


function BW_Name_Clicked(button)

    local id = this:GetParent():GetID()
    
    local playername = getglobal("BW_Player" .. id .. "_NameText"):GetText()

    if button == "LeftButton" then
        TargetByName(playername)
    elseif button == "RightButton" then
        AssistByName(playername)
    end
    
end


function BW_Buff_Clicked(button)

    local buffid = this:GetID()
    local playerid = this:GetParent():GetID()    
    local playername = getglobal("BW_Player" .. playerid .. "_NameText"):GetText()
    local playerframe =  "BW_Player" .. playerid

    if button == "LeftButton" then

        local spellid = nil

        for i = 1, 300 do
            if GetSpellTexture(i, 1) == getglobal(this:GetName() .. "TexturePath"):GetText() then
                spellid = i
            end
        end
        
        if spellid then

            if UnitIsVisible(Player_Info[playername].UNIT_ID) then

                if UnitName("target") and not UnitIsEnemy("target","player") then
                    if UnitName("target") ~= playername then
                        TargetByName(playername)
                    end
                end

                if IsShiftKeyDown() then
                    SendChatMessage(format("BW: Casting %s on %s", GetSpellName(spellid,1), playername), "PARTY")
                end

                if spellid then CastSpell(spellid, 1) end

                if SpellIsTargeting() then
                    TargetByName(playername)
                end

            else

                BW_Print(playername .. " is out of range or not visible.")

            end
           
        end

    elseif button == "RightButton" then

        if getglobal(playerframe .. "_Lock"):GetChecked() and IsControlKeyDown() then

            this:Hide()
            getglobal(playerframe .. "_Buff" .. buffid .. "TexturePath"):SetText(nil)
            BW_Player_AdjustBuffs(Player_Info[playername])
--BW_Print("BUFF HIDDEN")            
            BW_ResizeWindow()

        elseif getglobal(playerframe .. "_Lock"):GetChecked() and IsAltKeyDown() then
        
            for i = 1, 16 do
                if i ~= buffid then
                    getglobal(playerframe .. "_Buff" .. i):Hide()
                    getglobal(playerframe .. "_Buff" .. i .. "TexturePath"):SetText(nil)
                end
            end
            
            BW_Player_AdjustBuffs(Player_Info[playername])
--BW_Print("BUFF HIDDEN")            
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


function BW_Buff_Tooltip()

    local playername = getglobal("BW_Player" .. this:GetParent():GetID() .. "_NameText"):GetText()
    local buffbuttonid = nil
    local debuffbuttonid = nil
    local texture = getglobal(this:GetName() .. "TexturePath"):GetText()

    for i = 1, 16 do
        if UnitBuff(Player_Info[playername]["UNIT_ID"], i) == texture then
            buffbuttonid = i
            break
        end
    end

    if buffbuttonid == nil then
        for i_2 = 1, 16 do
            if UnitDebuff(Player_Info[playername]["UNIT_ID"], i_2) == texture then
                debuffbuttonid = i_2
                break
            end
        end
    end

    if buffbuttonid then
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:SetUnitBuff(Player_Info[playername]["UNIT_ID"], buffbuttonid)
    elseif debuffbuttonid then
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:SetUnitDebuff(Player_Info[playername]["UNIT_ID"], debuffbuttonid)
    end
    
end


function BW_Set_AllChecks(checked)

    for k, v in Player_Info do    
        getglobal("BW_Player" .. v.ID .. "_Lock"):SetChecked(checked)            
    end

end


function BW_Header_Clicked(button)
    
    if button == "LeftButton" then
        BW_Set_UNIT_IDs()
        BW_GetAllBuffs()
        BW_UpdateBuffStatus()
--BW_Print("HEADER CLICKED")
        BW_ResizeWindow()
    end
    
    if button == "RightButton" then
        BW_Toggle()
    end
    
end


function BW_MinimizeButton_Clicked()

    minimized = not minimized

    BW_GetAllBuffs()
    BW_UpdateBuffStatus()
--BW_Print("Minimised")
    BW_ResizeWindow()
    BW_MouseIsOverFrame()
    
end

-- //////////////////////////////////////////////////////////////////////////////////////
-- //
-- //                Miscellaneous
-- //
-- //////////////////////////////////////////////////////////////////////////////////////

function BW_Toggle()

    if BW:IsVisible() then
        HideUIPanel(BW)
    else
        ShowUIPanel(BW)
    end

end


function BW_OptionsToggle()

    if not BW_Options:IsVisible() then
        ShowUIPanel(BW_Options)
    else
        HideUIPanel(BW_Options)
    end

end


function BW_SetRightMouse()

    if lastspellcast == nil then

        BW_Print("     BuffWatch: You have not cast any timed spells yet:")
        BW_Print("                        Cast one, and then try \"/bw set\" again")

    else

        for i = 1, 300 do
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


function GetLen(arr)

    local len = 0
    
    if arr ~= nil then 
    
        for k, v in arr do
            len = len + 1
        end
        
    end

    return len
end


function BW_GetNextID(unitname)
    
    local i = 1

    if GetLen(Player_Info) == 0 then
    
        return i
    
    else
    
        local oldID = Player_Left[unitname]
    
        if oldID then
        
            local found = false
        
            for k, v in Player_Info do
                if v.ID == oldID then
                    found = true
                    break
                end
            end
            
            Player_Left[unitname] = nil
            
            if found == false then
                return oldID
            end
        
        end
    
        local Player_Copy = { }

        for k, v in Player_Info do
            table.insert(Player_Copy, v)
        end
        
        table.sort(Player_Copy, function(a,b) 
            return a.ID < b.ID 
            end)
    
        for k, v in Player_Copy do
       
            if i ~= v.ID then
                break
            end
        
            i = i + 1
    
        end

        Player_Copy = nil
        
    end
    
    getglobal("BW_Player" .. i .. "_Lock"):SetChecked(false)
    
    return i
        
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

    BW_HelpFrameText:SetText(

        [[            
        - BuffWatch Usage - v 1.01 -

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
             - /bw toggle : shows/hides the window
             - /bw options : shows/hides the options window
             - /bw : shows this help menu :)

        Verbosity:
             - Hold [ Shift ] while left or right-clicking a buff icon to send a cast message to your party
        ]] )

end

-- //////////////////////////////////////////////////////////////////////////////////////
