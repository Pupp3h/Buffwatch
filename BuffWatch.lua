
-- ** Buffwatch
-- **
-- ** TODO:
-- **

-- ** Add seperate frame for debuffs, so it can be shown/hidden/resized in combat?

-- ** Alt click for Lesser/Greater Buffs (?)
-- ** Timers for buffs expiring
-- ** Warning message for buff expiring
-- ** Debuffs

-- Changes
--
-- Added option to only show buffs cast by player
-- Added option to hide players with no locked buffs
-- Added combat icon
-- Fixed UIDropDownMenu SetAnchor error

-- ****************************************************************************
-- **                                                                        **
-- **  Variables                                                             **
-- **                                                                        **
-- ****************************************************************************

BW_VERSION = "3.10";
BW_RELEASE_DATE = "11 October 2008";
BW_SORTORDER_DROPDOWN_LIST = {
    "Raid Order",
    "Class",
    "Name"
};

local grouptype;                -- 'raid' or 'party'
local maxnamewidth = 0;         -- Width of the longest player name, to set buff button alignment
local maxnameid = 1;            -- The frame ID with the longest player name
--local buffexpired = 0;          -- Count of expired buffs, used for the Expired Warning
local HideUnmonitored = false;  -- Whether to show locked frames that have no buffs

local Player_Info = { };        -- Details of each player, see Buffwatch_GetPlayerInfo()
local Player_Left = { };        -- Retained Player_Info for players that have left group
local Player_Order = { };       -- Sorted order of players
local Current_Order = { };      -- Currently visible order of players
local UNIT_IDs = { };           -- UnitIDs, based on grouptype and whether we want pets
local InCombat_Events = { };    -- Events that occur in combat lockdown, to sort out after combat
local GroupBuffs = { };         -- Relationship list of buffs that can automatically replace each other
local dropdowninfo = { };       -- Info for dropdown menu buttons

-- Save option variables
BuffwatchConfig = { Alpha, ExpiredSound, ExpiredWarning, ShowOnlyMine, 
    ShowCastableBuffs, ShowAllForPlayer, ShowDebuffs, ShowDispellableDebuffs,
    ShowPets, SortOrder, WindowLocked, debug };

BuffwatchPlayerBuffs = { };     -- List of buffs that are shown for each player
BuffwatchSaveBuffs = { };       -- List of locked buffs that we save between sessions for each player

local debugchatframe = DEFAULT_CHAT_FRAME;  -- Frame to output debug messages to

-- ****************************************************************************
-- **                                                                        **
-- **  Events & Related                                                      **
-- **                                                                        **
-- ****************************************************************************

function Buffwatch_OnLoad(self)

    self:RegisterEvent("PLAYER_LOGIN");
    self:RegisterEvent("PARTY_MEMBERS_CHANGED");
    self:RegisterEvent("RAID_ROSTER_UPDATE");
    self:RegisterEvent("UNIT_PET");
    self:RegisterEvent("UNIT_AURA");
    self:RegisterEvent("VARIABLES_LOADED");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");

    SlashCmdList["BUFFWATCH"] = Buffwatch_SlashHandler;
    SLASH_BUFFWATCH1 = "/buffwatch";
    SLASH_BUFFWATCH2 = "/bfw";

    -- Mark of the Wild
    GroupBuffs["Mark of the Wild"] = {
        ["Greater"] = "Gift of the Wild",
        ["Type"] = "SubGroup",
    };
    -- Gift of the Wild
    GroupBuffs["Gift of the Wild"] = {
        ["Lesser"] = "Mark of the Wild",
        ["Type"] = "SubGroup",
    };
    -- Power Word: Fortitude
    GroupBuffs["Power Word: Fortitude"] = {
        ["Greater"] = "Prayer of Fortitude",
        ["Type"] = "SubGroup"
    };
    -- Prayer of Fortitude
    GroupBuffs["Prayer of Fortitude"] = {
        ["Lesser"] = "Power Word: Fortitude",
        ["Type"] = "SubGroup"
    };
    -- Divine Spirit
    GroupBuffs["Divine Spirit"] = {
        ["Greater"] = "Prayer of Spirit",
        ["Type"] = "SubGroup"
    };
    -- Prayer of Spirit
    GroupBuffs["Prayer of Spirit"] = {
        ["Lesser"] = "Divine Spirit",
        ["Type"] = "SubGroup"
    };
    -- Shadow Protection
    GroupBuffs["Shadow Protection"] = {
        ["Greater"] = "Prayer of Shadow Protection",
        ["Type"] = "SubGroup"
    };
    -- Prayer of Shadow Protection
    GroupBuffs["Prayer of Shadow Protection"] = {
        ["Lesser"] = "Shadow Protection",
        ["Type"] = "SubGroup"
    };
    -- Arcane Intellect
    GroupBuffs["Arcane Intellect"] = {
        ["Greater"] = "Arcane Brilliance",
        ["Type"] = "SubGroup"
    };
    -- Arcane Brilliance
    GroupBuffs["Arcane Brilliance"] = {
        ["Lesser"] = "Arcane Intellect",
        ["Type"] = "SubGroup"
    };
    -- Blessing of Might
    GroupBuffs["Blessing of Might"] = {
        ["Greater"] = "Greater Blessing of Might",
        ["Type"] = "Class"
    };
    -- Greater Blessing of Might
    GroupBuffs["Greater Blessing of Might"] = {
        ["Lesser"] = "Blessing of Might",
        ["Type"] = "Class"
    };
    -- Blessing of Wisdom
    GroupBuffs["Blessing of Wisdom"] = {
        ["Greater"] = "Greater Blessing of Wisdom",
        ["Type"] = "Class"
    };
    -- Greater Blessing of Wisdom
    GroupBuffs["Greater Blessing of Wisdom"] = {
        ["Lesser"] = "Blessing of Wisdom",
        ["Type"] = "Class"
    };
    -- Blessing of Kings
    GroupBuffs["Blessing of Kings"] = {
        ["Greater"] = "Greater Blessing of Kings",
        ["Type"] = "Class"
    };
    -- Greater Blessing of Kings
    GroupBuffs["Greater Blessing of Kings"] = {
        ["Lesser"] = "Blessing of Kings",
        ["Type"] = "Class"
    };
    -- Blessing of Sanctuary
    GroupBuffs["Blessing of Sanctuary"] = {
        ["Greater"] = "Greater Blessing of Sanctuary",
        ["Type"] = "Class"
    };
    -- Greater Blessing of Sanctuary
    GroupBuffs["Greater Blessing of Sanctuary"] = {
        ["Lesser"] = "Blessing of Sanctuary",
        ["Type"] = "Class"
    };

end


function Buffwatch_OnEvent(event, ...)
--[[
Buffwatch_Debug("Event vars for "..event..":");
for i = 1, select("#", ...) do
    Buffwatch_Debug("i="..i..", v="..select(i, ...));
end
]]
    -- Set default values, if unset
    if event == "VARIABLES_LOADED" then

        if BuffwatchConfig.Alpha == nil then
            BuffwatchConfig.Alpha = 0.5;
        end

        BuffwatchFrame_Background:SetAlpha(BuffwatchConfig.Alpha);

        if BuffwatchConfig.ExpiredSound == nil then
            BuffwatchConfig.ExpiredSound = false;
        end

        if BuffwatchConfig.ExpiredWarning == nil then
            BuffwatchConfig.ExpiredWarning = true;
        end

        if BuffwatchConfig.ShowOnlyMine == nil then
            BuffwatchConfig.ShowOnlyMine = false;
        end

        if BuffwatchConfig.ShowCastableBuffs == nil then
            BuffwatchConfig.ShowCastableBuffs = false;
        end

        if BuffwatchConfig.ShowAllForPlayer == nil then
            BuffwatchConfig.ShowAllForPlayer = false;
        end

        if BuffwatchConfig.ShowDebuffs == nil then
            BuffwatchConfig.ShowDebuffs = true;
        end

        if BuffwatchConfig.ShowDispellableDebuffs == nil then
            BuffwatchConfig.ShowDispellableDebuffs = false;
        end

        if BuffwatchConfig.ShowPets == nil then
            BuffwatchConfig.ShowPets = true;
        end

        if BuffwatchConfig.SortOrder == nil then
            BuffwatchConfig.SortOrder = BW_SORTORDER_DROPDOWN_LIST[1];
        end

        if BuffwatchConfig.WindowLocked == nil then
            BuffwatchConfig.WindowLocked = false;
        end

        if BuffwatchConfig.debug == nil then
            BuffwatchConfig.debug = false;
        end

        Buffwatch_Options_Init();

    end

    if BuffwatchFrame_PlayerFrame:IsVisible() then

        if event == "PLAYER_LOGIN" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE"
            or (event == "UNIT_PET" and BuffwatchConfig.ShowPets == true) then


            -- Look for a chatframe called 'Debug' on login for sending debug messsages to
            if event == "PLAYER_LOGIN" then
                local windowname;

                for i = 1, 10 do
                    windowname = GetChatWindowInfo(i);
                    if windowname and windowname == "Debug" then
                        debugchatframe = getglobal("ChatFrame"..i);
                        break;
                    end
                end

            end

            Buffwatch_Set_UNIT_IDs();
            Buffwatch_ResizeWindow();

            if event == "PLAYER_LOGIN" then

                Buffwatch_Check_Clicked(_, _, _, getglobal("BuffwatchFrame_PlayerFrame"..Player_Info[next(Player_Info)].ID.."_Lock"));

            end

        elseif event == "UNIT_AURA" and select(1, ...) ~= "target" then

            -- Someone gained or lost a buff
            for k, v in pairs(Player_Info) do

                if select(1, ...) == v.UNIT_ID then
                    Buffwatch_Player_GetBuffs(v);
                    Buffwatch_ResizeWindow();
                    break;
                end

            end

        elseif event == "PLAYER_REGEN_ENABLED" then

            -- We have come out of combat, remove combat restrictions and process any pending events
            BuffwatchFrame_HeaderCombatIcon:Hide();
            BuffwatchFrame_LockAll:Enable();

            for k, v in pairs(Player_Info) do
                local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock")
                curr_lock:Enable();
            end

            Buffwatch_Process_InCombat_Events();

        elseif event == "PLAYER_REGEN_DISABLED" then

            -- We have entered combat, enforce combat restrictions
            BuffwatchFrame_HeaderCombatIcon:Show();
            BuffwatchFrame_LockAll:Disable();

            for k, v in pairs(Player_Info) do
                local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock")
                curr_lock:Disable();
            end

        end

    end

end


function Buffwatch_MouseDown(self, button)
    if button == "LeftButton" and BuffwatchConfig.WindowLocked == false then
        self:StartMoving();
    end
end

function Buffwatch_MouseUp(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing();
    end
end


function Buffwatch_Set_AllChecks(checked)

    -- Toggle all checkboxes on or off
    for k, v in pairs(Player_Info) do

        local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock")

        if curr_lock:GetChecked() ~= checked then
            curr_lock:SetChecked(checked);

            -- Show or Hide any frames affected by the HideUnmonitored flag
            if HideUnmonitored and (#BuffwatchPlayerBuffs[v.Name]["Buffs"] == 0) then
                Buffwatch_PositionPlayerFrame(v.ID);
                Buffwatch_ResizeWindow();
            end

            if not checked then 
                -- Unchecked, so refresh buff list
                Buffwatch_Player_GetBuffs(v);                
            else
                -- Checked, so save buff list
                BuffwatchSaveBuffs[v.Name] = { };
                BuffwatchSaveBuffs[v.Name]["Buffs"] = BuffwatchPlayerBuffs[v.Name]["Buffs"];
            end

        end

    end

    -- If we have unchecked anything, then we will probably have to resize the window
    if not checked then
        Buffwatch_ResizeWindow();
    end

end


function Buffwatch_Header_Clicked(button, down)

    -- Show the dropdown menu
    if button == "RightButton" then
        ToggleDropDownMenu(1, nil, BuffwatchFrame_DropDown, "BuffwatchFrame_Header", 40, 0);
    end

end

function Buffwatch_DropDown_OnLoad(self)
    -- Prepare the dropdown menu
    UIDropDownMenu_Initialize(self, Buffwatch_DropDown_Initialize, "MENU");
    UIDropDownMenu_SetAnchor(self, 0, 0, "TOPLEFT", "BuffwatchFrame_Header", "CENTER");
end


function Buffwatch_DropDown_Initialize()

    -- Add items to the dropdown menu
    dropdowninfo.text = "Lock Window";
    dropdowninfo.checked = BuffwatchConfig.WindowLocked;
    dropdowninfo.func = function()
        BuffwatchConfig.WindowLocked = not BuffwatchConfig.WindowLocked;
    end
    UIDropDownMenu_AddButton(dropdowninfo);

    dropdowninfo.text = "Refresh";
    dropdowninfo.checked = nil;
    dropdowninfo.func = function()
        Buffwatch_GetPlayerInfo();
        Buffwatch_GetAllBuffs();
    end
    UIDropDownMenu_AddButton(dropdowninfo);

    dropdowninfo.text = "Options";
    dropdowninfo.func = Buffwatch_OptionsToggle;
    UIDropDownMenu_AddButton(dropdowninfo);

    if HideUnmonitored == true then
        dropdowninfo.text = "Show Unmonitored"
    else
        dropdowninfo.text = "Hide Unmonitored"
    end
    
    dropdowninfo.func = Buffwatch_HideUnmonitored_Clicked
    UIDropDownMenu_AddButton(dropdowninfo)
    
    dropdowninfo.text = "Help";
    dropdowninfo.func = Buffwatch_ShowHelp;
    UIDropDownMenu_AddButton(dropdowninfo);

    dropdowninfo.text = "Close Buffwatch";
    dropdowninfo.func = Buffwatch_Toggle;
    UIDropDownMenu_AddButton(dropdowninfo);

    dropdowninfo.disabled = 1;
    dropdowninfo.text = nil;
    dropdowninfo.func = nil;
    UIDropDownMenu_AddButton(dropdowninfo);

    dropdowninfo.disabled = nil;
    dropdowninfo.text = "Close Menu";
    dropdowninfo.func = function()
        BuffwatchFrame_DropDown:Hide();
    end
    UIDropDownMenu_AddButton(dropdowninfo);

end


function Buffwatch_Check_Clicked(self, button, down, obj)

    local playerid;
    local checked;

    -- Find out which checkbox was clicked
    if obj then
        checked = obj:GetChecked();
        playerid = obj:GetParent():GetID();
    else
        checked = self:GetChecked();
        playerid = self:GetParent():GetID();
    end

    local playername = getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_NameText"):GetText();

    if checked then

        -- Checked, so save buff list
        BuffwatchSaveBuffs[playername] = { };
        BuffwatchSaveBuffs[playername]["Buffs"] = BuffwatchPlayerBuffs[playername]["Buffs"];

        -- Check to see if they are all now checked
        for k, v in pairs(Player_Info) do

            local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock");

            if not curr_lock:GetChecked() then
                checked = nil;
                break;
            end

        end

        -- If so, check the 'Check All' checkbox
        if checked then
            BuffwatchFrame_LockAll:SetChecked(true);
        end
        
        -- Hide any frames affected by the HideUnmonitored flag
        if HideUnmonitored and (#BuffwatchPlayerBuffs[playername]["Buffs"] == 0) then
            Buffwatch_PositionPlayerFrame(playerid);
            Buffwatch_ResizeWindow();
        end

    else
        -- Unchecked, so refresh buff list
        BuffwatchFrame_LockAll:SetChecked(false);
        Buffwatch_Player_GetBuffs(Player_Info[playername]);
        Buffwatch_ResizeWindow();
    end

end


function Buffwatch_Buff_Clicked(self, button, down)

    local playerid = self:GetParent():GetID();
    local playerframe = "BuffwatchFrame_PlayerFrame"..playerid;

    if getglobal(playerframe.."_Lock"):GetChecked() and IsAltKeyDown() then

        if InCombatLockdown() then

            Buffwatch_Print("Cannot hide buffs while in combat.");

        else

            local buffid = self:GetID();
            local playername = getglobal(playerframe.."_NameText"):GetText();

            if button == "LeftButton" then

                -- Hide all but the clicked buff and adjust positions
                for i = 1, 32 do
                    if getglobal(playerframe.."_Buff"..i) then
                        if i ~= buffid then
                            getglobal(playerframe.."_Buff"..i):Hide();
                            BuffwatchPlayerBuffs[playername]["Buffs"][i] = nil;
                        else
                            self:SetPoint("TOPLEFT", playerframe.."_Name", "TOPLEFT", maxnamewidth + 5, 4);
                        end
                    else
                        break;
                    end
                end

                BuffwatchSaveBuffs[playername]["Buffs"] = BuffwatchPlayerBuffs[playername]["Buffs"];

                Buffwatch_ResizeWindow();

            elseif button == "RightButton" then

                local nextbuffid = next(BuffwatchPlayerBuffs[playername]["Buffs"], buffid);

                -- Hide the clicked buff
                self:Hide();
                BuffwatchPlayerBuffs[playername]["Buffs"][buffid] = nil;
                BuffwatchSaveBuffs[playername]["Buffs"][buffid] = nil;

                -- Re-anchor any following buff
                if nextbuffid then
                    getglobal(playerframe.."_Buff"..nextbuffid):ClearAllPoints();
                    getglobal(playerframe.."_Buff"..nextbuffid):SetPoint(self:GetPoint());
                end

                if HideUnmonitored then
                    if getglobal(playerframe.."_Lock"):GetChecked() and (#BuffwatchPlayerBuffs[playername]["Buffs"] == 0) then
                        Buffwatch_PositionPlayerFrame(playerid);
                    end
                end
                
                Buffwatch_ResizeWindow();

            end

        end

    else
--[[
if BuffwatchConfig.debug == true then
local buffid = self:GetID();
local playername = getglobal(playerframe.."_NameText"):GetText();
local curr_buff = getglobal(playerframe.."_Buff"..buffid);

Buffwatch_Debug("Casting spell :");
Buffwatch_Debug("Array : Player="..playername..", Buff="..BuffwatchPlayerBuffs[playername]["Buffs"][buffid]["Buff"]);
Buffwatch_Debug("Attribute : Player="..UnitName(curr_buff:GetAttribute("unit1"))..", Buff="..curr_buff:GetAttribute("spell1"));
end ]]
    end
end


function Buffwatch_Buff_Tooltip(self)

    local playername = getglobal("BuffwatchFrame_PlayerFrame"..self:GetParent():GetID().."_NameText"):GetText();
    local unit = Player_Info[playername]["UNIT_ID"];
    local buff = BuffwatchPlayerBuffs[playername]["Buffs"][self:GetID()]["Buff"];
    local rank = BuffwatchPlayerBuffs[playername]["Buffs"][self:GetID()]["Rank"];
    local buffbuttonid = nil;
    local debuffbuttonid = nil;

    buffbuttonid = UnitHasBuff(unit, buff, rank);

--    if buffbuttonid == 0 then
--        debuffbuttonid = UnitHasDebuff(unit, buff, rank);
--    end


    if buffbuttonid ~= 0 then

        -- If the buff is present, show the tooltip for it
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
        GameTooltip:SetUnitBuff(unit, buffbuttonid);
--    elseif debuffbuttonid then
--        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
--        GameTooltip:SetUnitDebuff(unit, debuffbuttonid);

    else

        -- If the buff isn't present, create a tooltip
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
        if rank ~= "" then
            GameTooltip:SetText(buff.." ("..rank..")", 1, 1, 0);
        else
            GameTooltip:SetText(buff, 1, 1, 0);
        end

    end

end


-- ****************************************************************************
-- **                                                                        **
-- **  Main Functions                                                        **
-- **                                                                        **
-- ****************************************************************************

function Buffwatch_SlashHandler(msg)

    msg = string.lower(msg);

    if msg == "toggle" then

        Buffwatch_Toggle();

    elseif msg == "options" then

        Buffwatch_OptionsToggle();

    elseif msg == "debug" then

        BuffwatchConfig.debug = not BuffwatchConfig.debug;

        if BuffwatchConfig.debug == true then
            Buffwatch_Print("Buffwatch debugging ON");
        else
            Buffwatch_Print("Buffwatch debugging OFF");
        end
        
    elseif msg == "help" then
    
        Buffwatch_ShowHelp();
        
    elseif msg == "reset" then
    
        BuffwatchFrame:ClearAllPoints();
        BuffwatchFrame:SetPoint("CENTER", 200, 200);

    else

        Buffwatch_Print("Buffwatch commands (/buffwatch or /bfw):");
        Buffwatch_Print("/bfw help - Show the help page");
        Buffwatch_Print("/bfw toggle - Toggle the Buffwatch window on or off");
        Buffwatch_Print("/bfw options - Toggle the options window on or off");
        Buffwatch_Print("/bfw reset - Reset the window position");
        Buffwatch_Print("Right click the Buffwatch header for more options");

    end

end


-- Setup basic list of possible UNIT_IDs
function Buffwatch_Set_UNIT_IDs(forced)

    if GetNumRaidMembers() > 0 then

        if grouptype ~= "raid" or forced == true then

            --UNIT_IDs = { };
            UNIT_IDs = table.wipe(UNIT_IDs);

            for i = 1, 40 do
                UNIT_IDs[i] = "raid"..i;
            end

            if BuffwatchConfig.ShowPets == true then
                for i = 1, 40 do
                    UNIT_IDs[i+40] = "raidpet"..i;
                end
            end

            grouptype = "raid";

        end

    elseif grouptype ~= "party" or forced == true then

        --UNIT_IDs = { };
        UNIT_IDs = table.wipe(UNIT_IDs);

        UNIT_IDs[1] = "player";
        UNIT_IDs[2] = "party1";
        UNIT_IDs[3] = "party2";
        UNIT_IDs[4] = "party3";
        UNIT_IDs[5] = "party4";

        if BuffwatchConfig.ShowPets == true then
            UNIT_IDs[6] = "pet";
            UNIT_IDs[7] = "partypet1";
            UNIT_IDs[8] = "partypet2";
            UNIT_IDs[9] = "partypet3";
            UNIT_IDs[10] = "partypet4";
        end

        grouptype = "party";

    end

    Buffwatch_GetPlayerInfo();

end


--[[ Get details of each player we find in the UNIT_IDs list

    Player_Info[Name] props :

    ID - Unique number for this player, determines which playerframe to use
    UNIT_ID - UNIT_ID of this player
    Name - Players name (same as key, but useful if we are just looping array)
    Class - Players Class (for colouring name and sorting)
    IsPet - true if a pet (pets are sorted last, and can be hidden)
    SubGroup - 1 if in party, or 1-8 if in raid (Used for sorting)
    Checked - Used only in this function to determine players that are no longer present
]]--
function Buffwatch_GetPlayerInfo()

    if InCombatLockdown() then

        Buffwatch_Add_InCombat_Events({"GetPlayerInfo"});

    else

        local getnewalignpos = false;
        local positionframe;

        for i = 1, #UNIT_IDs do

            local unitname = UnitName(UNIT_IDs[i]);

            positionframe = false;

            if unitname ~= nil and unitname ~= "Unknown" then

                -- Check if we know about this person already, if not capture basic details
                if not Player_Info[unitname] then

                    local id = Buffwatch_GetNextID(unitname);

                    -- Check if frame has been created
                    if not getglobal("BuffwatchFrame_PlayerFrame"..id) then

                        local f = CreateFrame("Frame", "BuffwatchFrame_PlayerFrame"..id,
                            BuffwatchFrame_PlayerFrame, "Buffwatch_Player_Template");
                        f:SetID(id);

                    end

                    Player_Info[unitname] = { };
                    Player_Info[unitname]["ID"] = id;
                    Player_Info[unitname]["Name"] = unitname;

                    local _, classname = UnitClass(UNIT_IDs[i]);

                    if classname then
                        Player_Info[unitname]["Class"] = classname;
                    else
                        Player_Info[unitname]["Class"] = "";
                    end

                    if (grouptype == "party" and i > 5) or (grouptype == "raid" and i > 40) then
                        Player_Info[unitname]["IsPet"] = 1;
                        Player_Info[unitname]["Class"] = "";
                    else
                        Player_Info[unitname]["IsPet"] = 0;
                    end

                    local namebutton = getglobal("BuffwatchFrame_PlayerFrame"..id.."_Name");
                    local nametext = getglobal("BuffwatchFrame_PlayerFrame"..id.."_NameText");

                    nametext:SetText(unitname);
                    namebutton:SetWidth(nametext:GetStringWidth());

                    -- If this is now the longest name, reset the buff button alignment
                    if maxnamewidth < nametext:GetStringWidth() then
                        maxnamewidth = nametext:GetStringWidth();
                        maxnameid = id;
                        Buffwatch_SetBuffAlignment();
                    end

                    Player_Info[unitname]["UNIT_ID"] = UNIT_IDs[i];
                    -- Setup left and right click actions on the name button
                    namebutton:SetAttribute("type1", "target");
                    namebutton:SetAttribute("type2", "assist");
                    namebutton:SetAttribute("unit", UNIT_IDs[i]);

                    Buffwatch_Player_ColourName(Player_Info[unitname]);

                    if not BuffwatchPlayerBuffs[unitname] then
                        BuffwatchPlayerBuffs[unitname] = { };
                        BuffwatchPlayerBuffs[unitname]["Buffs"] = { };

                        Buffwatch_Player_LoadBuffs(Player_Info[unitname]);
                        Buffwatch_Player_GetBuffs(Player_Info[unitname]);
                    end

                    positionframe = true;

                end

                -- Update any information that may have changed about this person,
                --    whether we captured before, or are taking for first time

                if Player_Info[unitname]["UNIT_ID"] ~= UNIT_IDs[i] then

                    -- UNIT_ID has changed, so update secure button attributes

                    local namebutton = getglobal("BuffwatchFrame_PlayerFrame"..Player_Info[unitname]["ID"].."_Name");

                    Player_Info[unitname]["UNIT_ID"] = UNIT_IDs[i];
--                    namebutton:SetAttribute("type1", "target");
--                    namebutton:SetAttribute("type2", "assist");
                    namebutton:SetAttribute("unit", UNIT_IDs[i]);

                    for j = 1, 32 do
                        local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..Player_Info[unitname]["ID"].."_Buff"..j);

                        if curr_buff then
                            if curr_buff:IsShown() then
                                curr_buff:SetAttribute("unit1", UNIT_IDs[i]);
                            end
                        else
                            break;
                        end
                    end

                end

                if grouptype == "raid" then
                    local subgroup;
--                    local lastsubgroup = Player_Info[unitname]["SubGroup"];
                    local j = math.fmod(i, 40);
                    if j == 0 then j = 40 end;
                    _, _, subgroup = GetRaidRosterInfo(j);

--                    if not lastsubgroup or subgroup ~= lastsubgroup then -- ***** Check logic or if needed
                    if subgroup ~= Player_Info[unitname]["SubGroup"] then
                        Player_Info[unitname]["SubGroup"] = subgroup;
                        if BuffwatchConfig.SortOrder == "Raid Order" then
                            positionframe = true;
                        end
                    end
                else
                    Player_Info[unitname]["SubGroup"] = 1;
                end

                Player_Info[unitname]["Checked"] = 1;

            end

            if positionframe == true then
--Buffwatch_Debug("Showing player frame "..Player_Info[unitname].ID.." for "..unitname);
                Buffwatch_PositionPlayerFrame(Player_Info[unitname].ID);
            end

        end

        -- Remove players that are no longer in the group
        for k, v in pairs(Player_Info) do

            if v.Checked == 1 then
                v.Checked = 0;
            else

                if v.ID == maxnameid then
                    getnewalignpos = true;
                end

                -- Add ID to temp array in case they come back
                -- (useful for dismissed or dead pets, or if a player leaves group briefly)
                Player_Left[v.Name] = v.ID;

                Player_Info[k] = nil;
                BuffwatchPlayerBuffs[k] = nil;

--Buffwatch_Debug("Hiding player frame "..v.ID.." for "..v.Name);
                Buffwatch_PositionPlayerFrame(v.ID);

            end

        end

        if getnewalignpos == true then

            maxnamewidth = 0;

            for k, v in pairs(Player_Info) do

                local nametext = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_NameText");

                if maxnamewidth < nametext:GetStringWidth() then
                    maxnamewidth = nametext:GetStringWidth();
                    maxnameid = v.ID;
                end

            end

            Buffwatch_SetBuffAlignment();

        end

    end

end


function Buffwatch_PositionAllPlayerFrames()

    Buffwatch_GetPlayerSortOrder();

    for k, v in pairs(Player_Order) do
        Buffwatch_PositionPlayerFrame(v.ID);
    end

end


function Buffwatch_PositionPlayerFrame(playerid)

    local playerframe = getglobal("BuffwatchFrame_PlayerFrame"..playerid);
    local arraypos;
    local playerdata;

    -- Find playerframe in current order
    for k, v in ipairs(Current_Order) do

        if playerid == v.ID then
            arraypos = k;
            break;
        end

    end

    -- See if there is a frame attached to this one
    if arraypos and Current_Order[arraypos+1] then

        local nextplayer = getglobal("BuffwatchFrame_PlayerFrame"..Current_Order[arraypos+1].ID);

        -- Remove next frame from order and reattach it to where our player frame was attached
        if nextplayer then
            nextplayer:ClearAllPoints();
            nextplayer:SetPoint(playerframe:GetPoint());
        end

    end

    -- Unattach our player frame, and remove from our current order list
    playerframe:ClearAllPoints();

    if arraypos then
        table.remove(Current_Order, arraypos);
    end

    -- Find out where our player frame should now sit in the order
    k, playerdata = Buffwatch_GetPlayerFramePosition(playerid);    

    -- Insert frame into new order if it should be visible (ie. hide it if it is locked with no buffs and HideUnmonitored is set)
    if k and (not HideUnmonitored or (#BuffwatchPlayerBuffs[playerdata.Name]["Buffs"] > 0) or not getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_Lock"):GetChecked()) then

        -- Insert back into current order in new position
        table.insert(Current_Order, k,  playerdata);

        -- Reattach into player frames in new position
        if k == 1 then

            -- Player frame is first so attach to parent frame
            playerframe:SetPoint("TOPLEFT", BuffwatchFrame_PlayerFrame);

        else
            
            -- Attach to previous frame in order
            playerframe:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..Current_Order[k-1].ID, "BOTTOMLEFT");

        end

        -- Reattach next frame in order to our player frame, if there is one
        if Current_Order[k+1] then

            local nextplayer = getglobal("BuffwatchFrame_PlayerFrame"..Current_Order[k+1].ID);

            if nextplayer then
                nextplayer:ClearAllPoints();
                nextplayer:SetPoint("TOPLEFT", playerframe, "BOTTOMLEFT");
            end

        end

        playerframe:Show();
Buffwatch_Debug("Showing player frame "..playerid.." for "..getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_NameText"):GetText());
    else
        playerframe:Hide();
Buffwatch_Debug("Hiding player frame "..playerid.." for "..getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_NameText"):GetText());
--        getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_NameText"):SetText(nil);
    end

end


function Buffwatch_GetPlayerFramePosition(playerid)

    local count = 0;

    Buffwatch_GetPlayerSortOrder();

    for k, v in ipairs(Player_Order) do
    
        if HideUnmonitored then

            -- Adjust final player count, if any frames are hidden
            if getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"):GetChecked() and (#BuffwatchPlayerBuffs[v.Name]["Buffs"] == 0) then
                count = count + 1;
            end
            
        end

        if playerid == v.ID then
            
            -- Return adjusted player frame position with player data
            return (k - count), v;

        end

    end

end


function Buffwatch_GetPlayerSortOrder()

    --Player_Order = { };
    Player_Order = table.wipe(Player_Order);
    
    for k, v in pairs(Player_Info) do
        table.insert(Player_Order, v);
    end

    -- Sort the player list in temp array
    if BuffwatchConfig.SortOrder == "Class" then

        table.sort(Player_Order,
        function(a,b)

            if a.IsPet == b.IsPet then

                if a.Class == b.Class then
                    return a.Name < b.Name;
                else
                    return a.Class < b.Class;
                end

            else
                return a.IsPet < b.IsPet;
            end

        end);

    elseif BuffwatchConfig.SortOrder == "Name" then

        table.sort(Player_Order,
        function(a,b)

            if a.IsPet == b.IsPet then
                return a.Name < b.Name;
            else
                return a.IsPet < b.IsPet;
            end

        end);

    else -- Default

        table.sort(Player_Order,
        function(a,b)

            if a.IsPet == b.IsPet then

                if a.SubGroup == b.SubGroup then
                    return a.UNIT_ID < b.UNIT_ID;
                else
                    return a.SubGroup < b.SubGroup;
                end

            else
                return a.IsPet < b.IsPet;
            end

        end);       
        
    end

end


function Buffwatch_GetAllBuffs()

    for k, v in pairs(Player_Info) do
        Buffwatch_Player_GetBuffs(v);
    end

    Buffwatch_ResizeWindow();

end


function Buffwatch_Player_GetBuffs(v)

    local curr_lock = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Lock");
    
    if not curr_lock:GetChecked() then

        if InCombatLockdown() then

            Buffwatch_Add_InCombat_Events({"GetBuffs", v});

        else

            -- Reset list of buffs for the player
            BuffwatchPlayerBuffs[v.Name]["Buffs"] = { };
            BuffwatchSaveBuffs[v.Name] = nil;

            local showbuffs, showallplayer;
            
            -- Setup buff filter
            if BuffwatchConfig.ShowCastableBuffs == true then
              showbuffs = "RAID";
            else
              showbuffs = "";
            end

            if UnitIsUnit(v.UNIT_ID, "player") and BuffwatchConfig.ShowAllForPlayer == true then
              showbuffs = "";
              showallplayer = true;
            end

            for i = 1, 32 do

                local buff, rank, icon, _, _, _, _, mine = UnitBuff(v.UNIT_ID, i, showbuffs);
                local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i);

--[[if buff then
    Buffwatch_Debug(i.." : buff="..buff);
end]]

                if buff and (not BuffwatchConfig.ShowOnlyMine or mine or showallplayer) then

                    -- Check if buff button has been created
                    if curr_buff == nil then

                        curr_buff = CreateFrame("Button", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i,
                            getglobal("BuffwatchFrame_PlayerFrame"..v.ID), "Buffwatch_BuffButton_Template");
                        curr_buff:SetID(i);

                    end

                    if i == 1 then
                        curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Name", "TOPLEFT", maxnamewidth + 5, 4);
                    else
                        curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..(i-1),
                            "TOPRIGHT");
                    end
                    

                    local curr_buff_icon = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon");

                    curr_buff_icon:SetVertexColor(1,1,1);
                    curr_buff:Show();
                    curr_buff_icon:SetTexture(icon);
                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i] = { };
                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Buff"] = buff;
                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Rank"] = rank;
                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Icon"] = icon;

                    -- Setup action for this buff button
                    curr_buff:SetAttribute("type", "spell");
                    curr_buff:SetAttribute("unit1", v.UNIT_ID);
                    curr_buff:SetAttribute("spell1", buff.."("..rank..")");

                else

                    if curr_buff then

                        local curr_buff_icon = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon");

                        curr_buff:Hide();
                        curr_buff_icon:SetTexture(nil);

                    end

                end

            end

        end

    else
    
        -- Refresh currently locked buffs
        for i = 1, 32 do

            local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i);
            local curr_buff_icon = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon");

            if curr_buff and curr_buff:IsShown() then

                -- Set buff icon to grey if player is dead or offline
                if UnitIsDeadOrGhost(v.UNIT_ID) or UnitIsConnected(v.UNIT_ID) == nil then

                    curr_buff_icon:SetVertexColor(0.4,0.4,0.4);

                else

                    local buff = BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Buff"];
                    local rank = BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Rank"];
                    local buffbuttonid;

                    buffbuttonid = UnitHasBuff(v.UNIT_ID, buff, rank);

                    if buffbuttonid ~= 0 then
                        -- Set buff icon to its normal colour if it exists
                        curr_buff_icon:SetVertexColor(1,1,1);
                    else

                        -- Buff has expired, start by checking if there is an automatic replacement
                        if GroupBuffs[buff] then

                            buff = GroupBuffs[buff].Lesser or GroupBuffs[buff].Greater;
                            buffbuttonid = UnitHasBuff(v.UNIT_ID, buff);

                            if buffbuttonid ~= 0 then

                                 -- Set buff icon to its normal colour as it has an automatic replacement
                                curr_buff_icon:SetVertexColor(1,1,1);

                                if InCombatLockdown() then

                                    Buffwatch_Add_InCombat_Events({"GetBuffs", v});

                                else

                                    -- Replace buff button with auto replacement
                                    local icon;
                                    _, rank, icon = UnitBuff(v.UNIT_ID, buffbuttonid);

                                    curr_buff_icon:SetTexture(icon);
                                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i] = { };
                                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Buff"] = buff;
                                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Rank"] = rank;
                                    BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Icon"] = icon;

                                    -- Setup action for this buff button
                                    curr_buff:SetAttribute("type", "spell");
                                    curr_buff:SetAttribute("unit1", v.UNIT_ID);
                                    curr_buff:SetAttribute("spell1", buff.."("..rank..")");

                                end

                            else
                                
                                -- Possible replacement buff isn't on player, so set icon to red
                                curr_buff_icon:SetVertexColor(1,0,0);

                            end

                        else

                            -- Buff expired and no possible replacement buff, so set icon to red
                            curr_buff_icon:SetVertexColor(1,0,0);

                        end


--[[                        buffexpired = buffexpired + 1;

                        if BuffwatchConfig.ExpiredWarning and buffexpired == 1 then
                            UIErrorsFrame:AddMessage("A buffwatch monitored buff has expired!", 0.2, 0.9, 0.9, 1.0, 2.0);

                            if BuffwatchConfig.ExpiredSound then
                                PlaySound("igQuestFailed");
                            end

--                            if minimized then
--                                Buffwatch_HeaderText:SetTextColor(1, 0, 0);
--                            end

                        end
]]
                    end

                end

            end

        end

    end

--[[
    for i = 1, 8 do

        local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Debuff"..i);

        if BuffwatchConfig.ShowDebuffs == false then

            if curr_buff then curr_buff:Hide(); end

        else

            local _, _, icon = UnitDebuff(v.UNIT_ID, i, BuffwatchConfig.ShowDispellableDebuffs);

            if icon then

                -- Check if buff button has been created
                if not curr_buff then

                    curr_buff = CreateFrame("Button", "BuffwatchFrame_PlayerFrame"..v.ID.."_Debuff"..i,
                        getglobal("BuffwatchFrame_PlayerFrame"..v.ID), "Buffwatch_BuffButton_Template");

                end

                local curr_buff_icon = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Debuff"..i.."Icon");

                curr_buff:Show();
                curr_buff_icon:SetTexture(icon);

            else

                if curr_buff then curr_buff:Hide(); end

            end

        end

    end
]]
end


-- Set buff button alignment based on longest player name
function Buffwatch_SetBuffAlignment()

    for k, v in pairs(Player_Info) do

        if BuffwatchPlayerBuffs[v.Name] then

            local i = next(BuffwatchPlayerBuffs[v.Name]["Buffs"]);

            if i then

                local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i);

                curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Name", "TOPLEFT", maxnamewidth + 5, 4);

            end

        end

    end

end


-- Setup buff list for the player based on our BuffwatchSaveBuffs list
function Buffwatch_Player_LoadBuffs(v)

    if BuffwatchSaveBuffs[v.Name] then

        local tmp = BuffwatchSaveBuffs[v.Name]["Buffs"];

        BuffwatchSaveBuffs[v.Name]["Buffs"] = { };

        -- remove nil values
        for k, val in pairs(tmp) do

            if val then
                table.insert(BuffwatchSaveBuffs[v.Name]["Buffs"], val);
            end

        end

        BuffwatchPlayerBuffs[v.Name]["Buffs"] = BuffwatchSaveBuffs[v.Name]["Buffs"];

        for i = 1, 32 do

            local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i);

            if BuffwatchSaveBuffs[v.Name]["Buffs"][i] then

                -- Check if buff button has been created
                if curr_buff == nil then

                    curr_buff = CreateFrame("Button", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i,
                        getglobal("BuffwatchFrame_PlayerFrame"..v.ID), "Buffwatch_BuffButton_Template");
                    curr_buff:SetID(i);

                end

                if i == 1 then
                    curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Name", "TOPLEFT", maxnamewidth + 5, 4);
                else
                    curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..(i-1),
                        "TOPRIGHT");
                end

                local curr_buff_icon = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon");

                curr_buff_icon:SetVertexColor(1,1,1);
                curr_buff:Show();
                curr_buff_icon:SetTexture(BuffwatchSaveBuffs[v.Name]["Buffs"][i]["Icon"]);

                curr_buff:SetAttribute("type", "spell");
                curr_buff:SetAttribute("unit1", v.UNIT_ID);
                curr_buff:SetAttribute("spell1", BuffwatchSaveBuffs[v.Name]["Buffs"][i]["Buff"].."("..BuffwatchSaveBuffs[v.Name]["Buffs"][i]["Rank"]..")");

            else

                if curr_buff then

                    local curr_buff_icon = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon");

                    curr_buff:Hide();
                    curr_buff_icon:SetTexture(nil);

                end

            end

        end

        getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"):SetChecked(true);

     else

        Buffwatch_Check_Clicked(_, _, _, getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"));

     end

end


function Buffwatch_ResizeWindow()

    if not InCombatLockdown() then

        local len;
        
        if HideUnmonitored == false then
          BuffwatchFrame:SetHeight(24 + (#Player_Order * 18));
        else

          local players = 0;
          
          -- Only count player frames that are not hidden
          for k, v in pairs(Player_Info) do
            if not getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"):GetChecked() or (#BuffwatchPlayerBuffs[v.Name]["Buffs"] > 0) then          
              players = players + 1;
            end
          end

          BuffwatchFrame:SetHeight(24 + (players * 18));          
        
        end

        local maxbuffs = 0;
-- ***** may need to move this to only check when buffs actually get hidden or shown
        for k, v in pairs(BuffwatchPlayerBuffs) do

            len = GetLen(v.Buffs);

            if maxbuffs < len then
                maxbuffs = len;
--                maxbuffid = v.ID;
            end

        end

        BuffwatchFrame:SetWidth(math.max(32 + maxnamewidth + (maxbuffs * 18), 100));

    end

end

-- Add a function call to the queue to run after combat
function Buffwatch_Add_InCombat_Events(value)

    local found;

    -- Check to see if this event has already been queued
    for k, v in pairs(InCombat_Events) do

        if value[1] == v[1] then

            if value[1] == "GetBuffs" then

                if value[2].ID == v[2].ID then
                    found = true;
--Buffwatch_Debug("InCombat_Event GetBuffs for ID "..value[2].ID.." found");
                    break;
                end

            elseif value[1] == "GetPlayerInfo" then
                found = true;
--Buffwatch_Debug("InCombat_Event GetPlayerInfo found");
                break;

            end

        end

    end

    -- Add it to the queue, if its not already on it
    if not found then
Buffwatch_Debug("Adding InCombat_Event "..value[1]);
        table.insert(InCombat_Events, value);
    end

end


-- Combat lockdown is over, process any queued events
function Buffwatch_Process_InCombat_Events()

    local t = table.remove(InCombat_Events, 1);

    local eventfired;

    while t do

        if t[1] == "GetPlayerInfo" then

            Buffwatch_GetPlayerInfo();

        elseif t[1] == "GetBuffs" then

            Buffwatch_Player_GetBuffs(t[2]);

        end

        t = table.remove(InCombat_Events, 1);

        eventfired = true;

    end

    if eventfired then
        Buffwatch_ResizeWindow();
    end

end


function Buffwatch_ShowHelp()

    Buffwatch_HelpFrame:Show()
    Buffwatch_HelpFrame:ClearAllPoints()
    Buffwatch_HelpFrame:SetPoint("CENTER","UIParent","CENTER",0,-32)

    Buffwatch_HelpFrameText:SetText(
"        - BuffWatch Usage - v " .. BW_VERSION .. " - " .. [[



        1) Make sure the buffs you want to monitor are on the relevant players 
        
        2) Tick the checkbox next to each player which locks those buffs to the player 
             (alternatively tick the checkbox at the top to lock them all) 
        
        3) Remove monitoring of the buffs you are not interested in using the following methods : 
        
           * Alt-Right Click to remove the selected buff 
           
           * Alt-Left Click to remove all buffs but the selected one 

        4) Buffs that have expired will turn red, and clicking on them will recast the buff on the player 
             (if you have the spell)
        
        
        Other features :
        
        - Left click a player name to target that player 
        
        - Right click a player name to assist that player (target their target)
        
        
        Buffwatch commands (/buffwatch or /bfw):
        
        /bfw toggle - Toggle the Buffwatch window on or off
        
        /bfw options - Toggle the options window on or off
        
        /bfw reset - Reset the window position
        
        /bfw help - Show this help page
        
        
        Right click the Buffwatch header for more options       
        
        ]] )

end


function Buffwatch_Toggle()

    if InCombatLockdown() then

        Buffwatch_Print("Cannot hide Buffwatch while in combat.");

    else

        if BuffwatchFrame:IsVisible() then
            BuffwatchFrame:Hide();
        else
            Buffwatch_Set_UNIT_IDs();
            BuffwatchFrame:Show();
        end

    end

end


function Buffwatch_OptionsToggle()

    if not Buffwatch_Options:IsVisible() then
        ShowUIPanel(Buffwatch_Options);
    else
        HideUIPanel(Buffwatch_Options);
    end

end


function Buffwatch_HideUnmonitored_Clicked(self)

    HideUnmonitored = not HideUnmonitored;
        
    Buffwatch_PositionAllPlayerFrames();
    Buffwatch_ResizeWindow();
    
end


-- ****************************************************************************
-- **                                                                        **
-- **  Misc Functions                                                        **
-- **                                                                        **
-- ****************************************************************************

-- Get's a Unique ID for a new player, also to be used as the player's frame ID
--   If player was recently in the group, and their ID has not yet been replaced
--   then we resupply it.
function Buffwatch_GetNextID(unitname)

    local i = 1;

    if GetLen(Player_Info) == 0 then

        return i;

    else

        local oldID = Player_Left[unitname];

        -- Player was here before, check if id is still free
        if oldID then

            local found = false;

            for k, v in pairs(Player_Info) do
                if v.ID == oldID then
                    -- Someone else has this id now :(
                    found = true;
                    break;
                end
            end

            Player_Left[unitname] = nil;

            if found == false then
--                getglobal("BuffwatchFrame_PlayerFrame"..oldID):Show();
                return oldID;
            end

        end

        local Player_Copy = { };

        for k, v in pairs(Player_Info) do
            table.insert(Player_Copy, v);
        end

        table.sort(Player_Copy, function(a,b)
            return a.ID < b.ID;
            end)

        for k, v in pairs(Player_Copy) do

            if i ~= v.ID then
                break;
            end

            i = i + 1;

        end

        Player_Copy = nil;

    end

    if getglobal("BuffwatchFrame_PlayerFrame"..i.."_Lock") then
        getglobal("BuffwatchFrame_PlayerFrame"..i.."_Lock"):SetChecked(false);
    end

    BuffwatchFrame_LockAll:SetChecked(false);

    return i;

end


function UnitHasBuff(unit, buff, rank)

  local thisbuff, thisrank;

  for i = 1, 32 do

    thisbuff, thisrank = UnitBuff(unit, i);

    if not thisbuff then break; end

    if thisbuff == buff then

      if rank then
        if thisrank == rank then
          return i;
        else
          return 0;
        end
      else
        return i;
      end

      break;
    end

  end

  return 0;

end


function UnitHasDebuff(unit, buff, rank)

  local thisbuff, thisrank;

  for i = 1, 16 do

    thisbuff, thisrank = UnitDebuff(unit, i);

    if not thisbuff then break; end

    if thisbuff == buff then

      if rank then
        if thisrank == rank then
          return i;
        else
          return 0;
        end
      else
        return i;
      end

      break;
    end

  end

  return 0;

end


function Buffwatch_ColourAllNames()

    for k, v in pairs(Player_Info) do
        Buffwatch_Player_ColourName(v);
    end

end


function Buffwatch_Player_ColourName(v)

    local nametext = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_NameText");

--    if BuffwatchConfig.HighlightPvP and UnitIsPVP(v.UNIT_ID) then

--        nametext:SetTextColor(0.0, 1.0, 0.0);

--    else

        if v.Class ~= "" then

            local color = RAID_CLASS_COLORS[v.Class];

            if color then
                nametext:SetTextColor(color.r, color.g, color.b);
            else
                nametext:SetTextColor(1.0, 0.9, 0.8);
            end

        else
            nametext:SetTextColor(1.0, 0.9, 0.8);
        end

--    end

end


function GetLen(arr)

    local len = 0;

    if arr ~= nil then

        for k, v in pairs(arr) do
            len = len + 1;
        end

    end

    return len;
end

function Buffwatch_Print(msg, R, G, B)

    if R == nil then
        R, G, B = 0.2, 0.9, 0.9;
    end

    DEFAULT_CHAT_FRAME:AddMessage(msg, R, G, B);

end


function Buffwatch_Debug(msg, R, G, B)

    if BuffwatchConfig.debug == true then
        debugchatframe:AddMessage(msg, R, G, B);
    end

end

-- for debugging
--[[
function GetUNIT_IDs()

    return UNIT_IDs;

end

function GetPlayer_Info()

    return Player_Info;

end

function GetPlayer_Left()

    return Player_Left;

end

function GetPlayer_Order()

    return Player_Order;

end

function GetBuffwatchConfig()

    return BuffwatchConfig;

end

function GetBuffwatchPlayerBuffs()

    return BuffwatchPlayerBuffs;

end

function GetBuffwatchSaveBuffs()

    return BuffwatchPlayerBuffs;

end

function GetInCombat_Events()

    return InCombat_Events;

end
]]
