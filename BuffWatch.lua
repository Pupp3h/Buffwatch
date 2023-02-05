
-- ** Buffwatch++
-- **

-- Changes
--
-- ToC update for 7.3.5
--

-- ****************************************************************************
-- **                                                                        **
-- **  Variables                                                             **
-- **                                                                        **
-- ****************************************************************************

BW_ADDONNAME = "Buffwatch++";
BW_VERSION = "7.01";
BW_RELEASE_DATE = "4 May 2018";
BW_HELPFRAMENAME = "Buffwatch Help";
BW_MODE_DROPDOWN_LIST = {
    "Solo",
    "Party",
    "Raid"
};
BW_SORTORDER_DROPDOWN_LIST = {
    "Raid Order",
    "Class",
    "Name"
};
BW_ANCHORPOINT_DROPDOWN_LIST = {
    "Auto",
    "Top Left",
    "Top Right",
    "Bottom Left",
    "Bottom Right",
    "Center"
};
BW_ANCHORPOINT_DROPDOWN_MAP = {
    ["Auto"] = "",
    ["Top Left"] = "TOPLEFT",
    ["Top Right"] = "TOPRIGHT",
    ["Bottom Left"] = "BOTTOMLEFT",
    ["Bottom Right"] = "BOTTOMRIGHT",
    ["Center"] = "CENTER"
};

BW_DEFAULTS = {
    Alpha          = 0.5,
    ExpiredSound   = false,
    ExpiredWarning = true,
    HideOmniCC     = true,
    Spirals        = true,
    debug          = false
}

BW_PLAYER_DEFAULTS = {
    AnchorPoint             = "Auto",
    AnchorX                 = 200,
    AnchorY                 = 200,
    Mode                    = BW_MODE_DROPDOWN_LIST[3],
    Scale                   = 1.0,
    ShowOnlyMine            = false,
    ShowCastableBuffs       = false,
    ShowAllForPlayer        = false,
    ShowPets                = true,
    SortOrder               = BW_SORTORDER_DROPDOWN_LIST[1],
    WindowLocked            = false
}

local grouptype;                -- solo, raid or party
local maxnamewidth = 0;         -- Width of the longest player name, to set buff button alignment
local maxnameid = 1;            -- The frame ID with the longest player name
--local buffexpired = 0;          -- Count of expired buffs, used for the Expired Warning
local HideUnmonitored = false;  -- Whether to show locked frames that have no buffs
local minimized = false;        -- Is window minimized
local framePositioned = false;  -- Flag whether frame has been positioned correctly on login

local Player_Info = { };        -- Details of each player, see Buffwatch_GetPlayerInfo()
local Player_Left = { };        -- Retained Player_Info for players that have left group
local Player_Order = { };       -- Sorted order of players
local Current_Order = { };      -- Currently visible order of players
local UNIT_IDs = { };           -- UnitIDs, based on grouptype and whether we want pets
local InCombat_Events = { };    -- Events that occur in combat lockdown, to sort out after combat
local GroupBuffs = { };         -- Relationship list of buffs that can automatically replace each other
local dropdowninfo = { };       -- Info for dropdown menu buttons

-- Save global options
BuffwatchConfig = CopyTable(BW_DEFAULTS);

-- Save player options
BuffwatchPlayerConfig = CopyTable(BW_PLAYER_DEFAULTS);

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
    self:RegisterEvent("GROUP_ROSTER_UPDATE");
    self:RegisterEvent("UNIT_PET");
    self:RegisterEvent("UNIT_AURA");
    self:RegisterEvent("ADDON_LOADED");
    self:RegisterEvent("PLAYER_REGEN_ENABLED");
    self:RegisterEvent("PLAYER_REGEN_DISABLED");

    SlashCmdList["BUFFWATCH"] = Buffwatch_SlashHandler;
    SLASH_BUFFWATCH1 = "/buffwatch";
    SLASH_BUFFWATCH2 = "/bfw";

    GroupBuffs.Buff = { };
    GroupBuffs.GroupName = { };

    -- Class Group Buffs
    GroupBuffs.GroupName[1] = "Burst Haste"
    GroupBuffs.Buff["Bloodlust"] = 1;
    GroupBuffs.Buff["Heroism"] = 1;
    GroupBuffs.Buff["Time Warp"] = 1;
    GroupBuffs.Buff["Ancient Hysteria"] = 1;

    GroupBuffs.GroupName[2] = "Mage Armor"
    GroupBuffs.Buff["Mage Armor"] = 2;
    GroupBuffs.Buff["Frost Armor"] = 2;
    GroupBuffs.Buff["Molten Armor"] = 2;

    GroupBuffs.GroupName[3] = "Flasks"
    GroupBuffs.Buff["Flask of Endless Rage"] = 3;
    GroupBuffs.Buff["Flask of Pure Mojo"] = 3;
    GroupBuffs.Buff["Flask of Stoneblood"] = 3;
    GroupBuffs.Buff["Flask of the Frost Wyrm"] = 3;
    GroupBuffs.Buff["Flask of Enhancement"] = 3;
    GroupBuffs.Buff["Flask of Flowing Water"] = 3;
    GroupBuffs.Buff["Flask of Steelskin"] = 3;
    GroupBuffs.Buff["Flask of Titanic Strength"] = 3;
    GroupBuffs.Buff["Flask of the Draconic Mind"] = 3;
    GroupBuffs.Buff["Flask of the Winds"] = 3;
    GroupBuffs.Buff["Flask of Spring Blossoms"] = 3;
    GroupBuffs.Buff["Flask of the Warm Sun"] = 3;
    GroupBuffs.Buff["Flask of Falling Leaves"] = 3;
    GroupBuffs.Buff["Flask of the Earth"] = 3;
    GroupBuffs.Buff["Flask of Winter's Bite"] = 3;
    GroupBuffs.Buff["Draenic Intellect Flask"] = 3;
    GroupBuffs.Buff["Draenic stamina Flask"] = 3;
    GroupBuffs.Buff["Draenic Strength Flask"] = 3;
    GroupBuffs.Buff["Draenic Agility Flask"] = 3;
    GroupBuffs.Buff["Greater Draenic Intellect Flask"] = 3;
    GroupBuffs.Buff["Greater Draenic stamina Flask"] = 3;
    GroupBuffs.Buff["Greater Draenic Strength Flask"] = 3;
    GroupBuffs.Buff["Greater Draenic Agility Flask"] = 3;
    GroupBuffs.Buff["Flask of Countless Armies"] = 3;
    GroupBuffs.Buff["Flask of Ten Thousand Stars"] = 3;
    GroupBuffs.Buff["Flask of the Seventh Demon"] = 3;
    GroupBuffs.Buff["Flask of the Whispered Pact"] = 3;

    -- Lvl80 Battle Elixirs
    GroupBuffs.GroupName[4] = "Battle Elixirs"
    GroupBuffs.Buff["Accuracy"] = 4;
    GroupBuffs.Buff["Armor Piercing"] = 4;
    GroupBuffs.Buff["Deadly Strikes"] = 4;
    GroupBuffs.Buff["Expertise"] = 4;
    GroupBuffs.Buff["Lightning Speed"] = 4;
    GroupBuffs.Buff["Mighty Agility"] = 4;
    GroupBuffs.Buff["Mighty Mana Regeneration"] = 4;
    GroupBuffs.Buff["Mighty Strength"] = 4;
    GroupBuffs.Buff["Elixir of Spirit"] = 4;
    GroupBuffs.Buff["Guru's Elixir"] = 4;
    GroupBuffs.Buff["Spellpower Elixir"] = 4;
    GroupBuffs.Buff["Wrath Elixir"] = 4;

    -- Lvl85 Battle Elixirs
    GroupBuffs.Buff["Impossible Accuracy"] = 4;
    GroupBuffs.Buff["Mighty Speed"] = 4;
    GroupBuffs.Buff["Elixir of the Cobra"] = 4;
    GroupBuffs.Buff["Elixir of the Master"] = 4;
    GroupBuffs.Buff["Elixir of the Naga"] = 4;
    GroupBuffs.Buff["Ghost Elixir"] = 4;

    -- Lvl90 Battle Elixirs
    GroupBuffs.Buff["Mad Hozen Elixir"] = 4;
    GroupBuffs.Buff["Elixir of the Rapids"] = 4;
    GroupBuffs.Buff["Elixir of Peace"] = 4;
    GroupBuffs.Buff["Elixir of Perfection"] = 4;
    GroupBuffs.Buff["Monk's Elixir"] = 4;
    GroupBuffs.Buff["Elixir of Weaponry"] = 4;
    
    -- Lvl80 Guardian Elixirs
    GroupBuffs.GroupName[5] = "Guardian Elixirs"
    GroupBuffs.Buff["Mighty Defense"] = 5;
    GroupBuffs.Buff["Elixir of Mighty Fortitude"] = 5;
    GroupBuffs.Buff["Mighty Thoughts"] = 5;
    GroupBuffs.Buff["Protection"] = 5;

    -- Lvl85 Guardian Elixirs
    GroupBuffs.Buff["Elixir of Deep Earth"] = 5;
    GroupBuffs.Buff["Prismatic Elixir"] = 5;

    -- Lvl90 Battle Elixirs
    GroupBuffs.Buff["Mantid Elixir"] = 5;
    GroupBuffs.Buff["Elixir of Mirrors"] = 5;

    GroupBuffs.Group = { };

    for k, v in pairs(GroupBuffs.Buff) do

      if GroupBuffs.Group[v] == nil then
        GroupBuffs.Group[v] = { };
      end

      table.insert(GroupBuffs.Group[v], k);

    end

end


function Buffwatch_OnEvent(self, event, ...)
--[[
if event ~= "ADDON_LOADED" or select(1, ...) == "Buffwatch" then
    Buffwatch_Debug("Event vars for "..event..":");
    for i = 1, select("#", ...) do
        Buffwatch_Debug("i="..i..", v="..select(i, ...));
    end
end
]]

    -- Set default values, if unset
    if event == "ADDON_LOADED" and select(1, ...) == "Buffwatch" then
        Buffwatch_Options_Init();
    end

    if event == "PLAYER_LOGIN" then
        -- Ensure correct repositioning and anchoring of the frame
        Buffwatch_SetPoint(BuffwatchFrame, BW_ANCHORPOINT_DROPDOWN_MAP[BuffwatchPlayerConfig.AnchorPoint], BuffwatchPlayerConfig.AnchorX, BuffwatchPlayerConfig.AnchorY);
        framePositioned = true;

        -- Look for a chatframe called 'BWDebug' on login for sending debug messsages to
        local windowname;

        for i = 1, 10 do
            windowname = GetChatWindowInfo(i);
            if windowname and windowname == "BWDebug" then
            debugchatframe = _G["ChatFrame"..i];
            break;
            end
        end
    end

    if BuffwatchFrame_PlayerFrame:IsVisible() then

        if event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" 
            or (event == "UNIT_PET" and BuffwatchPlayerConfig.ShowPets == true) then

            Buffwatch_Set_UNIT_IDs();
            Buffwatch_ResizeWindow();

            if event == "PLAYER_LOGIN" then
                -- Check the 'Check All' checkbox, if all players are now locked
                if Buffwatch_InspectPlayerLocks() then
                    BuffwatchFrame_LockAll:SetChecked(true);
                end
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
            BuffwatchFrame_MinimizeButton:Enable();

            for k, v in pairs(Player_Info) do
                local curr_lock = _G["BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock"]
                curr_lock:Enable();
            end

            Buffwatch_Process_InCombat_Events();

        elseif event == "PLAYER_REGEN_DISABLED" then

            -- We have entered combat, enforce combat restrictions
            BuffwatchFrame_HeaderCombatIcon:Show();
            BuffwatchFrame_LockAll:Disable();
            BuffwatchFrame_MinimizeButton:Disable();

            for k, v in pairs(Player_Info) do
                local curr_lock = _G["BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock"]
                curr_lock:Disable();
            end

        end

    end

end


function Buffwatch_MouseDown(self, button)
    if button == "LeftButton" and BuffwatchPlayerConfig.WindowLocked == false then
        self:StartMoving();
    end
end

function Buffwatch_MouseUp(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing();
        -- Save new X and Y position
        Buffwatch_GetPoint(BuffwatchFrame, BW_ANCHORPOINT_DROPDOWN_MAP[BuffwatchPlayerConfig.AnchorPoint]);
    end
end


function Buffwatch_Set_AllChecks(checked)

    -- Toggle all checkboxes on or off
    for k, v in pairs(Player_Info) do

        local curr_lock = _G["BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock"]

        if curr_lock:GetChecked() ~= checked then
            curr_lock:SetChecked(checked);

            -- Show or Hide any frames affected by the HideUnmonitored flag
            if HideUnmonitored and (next(BuffwatchPlayerBuffs[v.Name]["Buffs"], nil) == nil) then
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
        ToggleDropDownMenu(1, nil, BuffwatchFrame_HeaderDropDown, "BuffwatchFrame_Header", 40, 0);
    end

end

function Buffwatch_HeaderDropDown_OnLoad(self)
    -- Prepare the dropdown menu
    UIDropDownMenu_Initialize(self, Buffwatch_HeaderDropDown_Initialize, "MENU");
    UIDropDownMenu_SetAnchor(self, 0, 0, "TOPLEFT", "BuffwatchFrame_Header", "CENTER");
end


function Buffwatch_HeaderDropDown_Initialize()

    -- Add items to the dropdown menu
    dropdowninfo.text = "Lock Window";
    dropdowninfo.notCheckable = false;
    dropdowninfo.checked = BuffwatchPlayerConfig.WindowLocked;
    dropdowninfo.func = function()
        BuffwatchPlayerConfig.WindowLocked = not BuffwatchPlayerConfig.WindowLocked;
    end
    UIDropDownMenu_AddButton(dropdowninfo);

    dropdowninfo.text = "Refresh";
    dropdowninfo.checked = nil;
    dropdowninfo.notCheckable = true;
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
        BuffwatchFrame_HeaderDropDown:Hide();
    end
    UIDropDownMenu_AddButton(dropdowninfo);

end


function Buffwatch_MinimizeButton_Clicked()

    minimized = not minimized;

    if minimized == true then
        BuffwatchFrame_PlayerFrame:Hide();
        BuffwatchFrame_LockAll:Disable();
        BuffwatchFrame_MinimizeButton:SetNormalTexture("Interface\\AddOns\\Buffwatch\\MinimizeButton-Max");
    else
        BuffwatchFrame_PlayerFrame:Show();
        BuffwatchFrame_LockAll:Enable();
        BuffwatchFrame_MinimizeButton:SetNormalTexture("Interface\\AddOns\\Buffwatch\\MinimizeButton-Min");
        -- Do a refresh
        Buffwatch_GetPlayerInfo();
        Buffwatch_GetAllBuffs();
    end

    Buffwatch_ResizeWindow();

end


function Buffwatch_Check_Clicked(self, button, down)

    local playerid = self:GetParent():GetID();
    local checked = self:GetChecked();
    local playername = _G["BuffwatchFrame_PlayerFrame"..playerid.."_NameText"]:GetText();

    if checked then

        -- Checked, so save buff list
        BuffwatchSaveBuffs[playername] = { };
        BuffwatchSaveBuffs[playername]["Buffs"] = BuffwatchPlayerBuffs[playername]["Buffs"];

        -- Check the 'Check All' checkbox, if all players are now locked
        if Buffwatch_InspectPlayerLocks() then
            BuffwatchFrame_LockAll:SetChecked(true);
        end

        -- Hide any frames affected by the HideUnmonitored flag
        if HideUnmonitored and (next(BuffwatchPlayerBuffs[playername]["Buffs"], nil) == nil) then
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

    if _G[playerframe.."_Lock"]:GetChecked() and IsAltKeyDown() then

        if InCombatLockdown() then

            Buffwatch_Print("Cannot hide buffs while in combat.");

        else

            local buffid = self:GetID();
            local playername = _G[playerframe.."_NameText"]:GetText();

            if button == "LeftButton" then

                -- Hide all but the clicked buff and adjust positions
                for i = 1, 32 do
                    if _G[playerframe.."_Buff"..i] then
                        if i ~= buffid then
                            _G[playerframe.."_Buff"..i]:Hide();
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
                    _G[playerframe.."_Buff"..nextbuffid]:ClearAllPoints();
                    _G[playerframe.."_Buff"..nextbuffid]:SetPoint(self:GetPoint());
                end

                if HideUnmonitored then
                    if _G[playerframe.."_Lock"]:GetChecked() and next(BuffwatchPlayerBuffs[playername]["Buffs"], nil) == nil then
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
local playername = _G[playerframe.."_NameText"]:GetText();
local curr_buff = _G[playerframe.."_Buff"..buffid];

Buffwatch_Debug("Casting spell :");
Buffwatch_Debug("Array : Player="..playername..", Buff="..BuffwatchPlayerBuffs[playername]["Buffs"][buffid]["Buff"]);
Buffwatch_Debug("Attribute : Player="..UnitName(curr_buff:GetAttribute("unit1"))..", Buff="..curr_buff:GetAttribute("spell1"));
end ]]
    end
end


function Buffwatch_Buff_Tooltip(self)

    local playername = _G["BuffwatchFrame_PlayerFrame"..self:GetParent():GetID().."_NameText"]:GetText();
    local unit = Player_Info[playername]["UNIT_ID"];
    local buff = BuffwatchPlayerBuffs[playername]["Buffs"][self:GetID()]["Buff"];
    local rank = BuffwatchPlayerBuffs[playername]["Buffs"][self:GetID()]["Rank"];
    local buffbuttonid = nil;

    buffbuttonid = UnitHasBuff(unit, buff, rank);

    if buffbuttonid ~= 0 then

        -- If the buff is present, show the tooltip for it
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
        GameTooltip:SetUnitBuff(unit, buffbuttonid);

    else

        -- If the buff isn't present, create a tooltip
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
        if rank ~= "" then
            GameTooltip:SetText(buff.." ("..rank..")", 1, 1, 0);
        else
            GameTooltip:SetText(buff, 1, 1, 0);
        end

    end
    
    if GroupBuffs.Buff[buff] ~= nil then
    	GameTooltip:AddLine("Group: "..GroupBuffs.GroupName[GroupBuffs.Buff[buff]], 0.2, 1, 0.2);
    	GameTooltip:Show();
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

    if BuffwatchPlayerConfig.Mode == BW_MODE_DROPDOWN_LIST[1] then  -- "Solo"

        UNIT_IDs = table.wipe(UNIT_IDs);
        UNIT_IDs[1] = "player";
        if BuffwatchPlayerConfig.ShowPets == true then
            UNIT_IDs[2] = "pet";
        end
        grouptype = "solo";

    else

        if GetNumGroupMembers() > 5 and BuffwatchPlayerConfig.Mode == BW_MODE_DROPDOWN_LIST[3] then  -- "Raid"

            if grouptype ~= "raid" or forced == true then

                UNIT_IDs = table.wipe(UNIT_IDs);

                for i = 1, 40 do
                    UNIT_IDs[i] = "raid"..i;
                end

                if BuffwatchPlayerConfig.ShowPets == true then
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

            if BuffwatchPlayerConfig.ShowPets == true then
                UNIT_IDs[6] = "pet";
                UNIT_IDs[7] = "partypet1";
                UNIT_IDs[8] = "partypet2";
                UNIT_IDs[9] = "partypet3";
                UNIT_IDs[10] = "partypet4";
            end

            grouptype = "party";

        end

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
                    if not _G["BuffwatchFrame_PlayerFrame"..id] then

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

                    if (grouptype == "party" and i > 5) or (grouptype == "raid" and i > 40) or (grouptype == "solo" and i == 2) then
                        Player_Info[unitname]["IsPet"] = 1;
                        Player_Info[unitname]["Class"] = "";
                    else
                        Player_Info[unitname]["IsPet"] = 0;
                    end

                    local namebutton = _G["BuffwatchFrame_PlayerFrame"..id.."_Name"];
                    local nametext = _G["BuffwatchFrame_PlayerFrame"..id.."_NameText"];

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

                    local namebutton = _G["BuffwatchFrame_PlayerFrame"..Player_Info[unitname]["ID"].."_Name"];

                    Player_Info[unitname]["UNIT_ID"] = UNIT_IDs[i];
                    namebutton:SetAttribute("unit", UNIT_IDs[i]);

                    for j = 1, 32 do
                        local curr_buff = _G["BuffwatchFrame_PlayerFrame"..Player_Info[unitname]["ID"].."_Buff"..j];

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
                    local j = math.fmod(i, 40);
                    if j == 0 then j = 40 end;
                    _, _, subgroup = GetRaidRosterInfo(j);

                    if subgroup ~= Player_Info[unitname]["SubGroup"] then
                        Player_Info[unitname]["SubGroup"] = subgroup;
                        if BuffwatchPlayerConfig.SortOrder == BW_SORTORDER_DROPDOWN_LIST[1] then  -- "Raid Order"
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

                local nametext = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_NameText"];

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

    local playerframe = _G["BuffwatchFrame_PlayerFrame"..playerid];
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

        local nextplayer = _G["BuffwatchFrame_PlayerFrame"..Current_Order[arraypos+1].ID];

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
    if k and (not HideUnmonitored or (next(BuffwatchPlayerBuffs[playerdata.Name]["Buffs"], nil) ~= nil) or not _G["BuffwatchFrame_PlayerFrame"..playerid.."_Lock"]:GetChecked()) then

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

            local nextplayer = _G["BuffwatchFrame_PlayerFrame"..Current_Order[k+1].ID];

            if nextplayer then
                nextplayer:ClearAllPoints();
                nextplayer:SetPoint("TOPLEFT", playerframe, "BOTTOMLEFT");
            end

        end

        playerframe:Show();

    else

        playerframe:Hide();

        -- If the LockAll checkbox is unchecked and the player we are hiding was unchecked, check whether all players are now checked
        if not BuffwatchFrame_LockAll:GetChecked() and not _G["BuffwatchFrame_PlayerFrame"..playerid.."_Lock"]:GetChecked() then

            -- Check the 'Check All' checkbox, if all players are now locked
            if Buffwatch_InspectPlayerLocks() then
                BuffwatchFrame_LockAll:SetChecked(true);
            end

        end

    end

end


function Buffwatch_GetPlayerFramePosition(playerid)

    local count = 0;

    Buffwatch_GetPlayerSortOrder();

    for k, v in ipairs(Player_Order) do

        if HideUnmonitored then

            -- Adjust final player count, if any frames are hidden
            if _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"]:GetChecked() and (next(BuffwatchPlayerBuffs[v.Name]["Buffs"], nil) == nil) then
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

    -- Only bother to sort player frames if we can see them
    if not minimized then

        --Player_Order = { };
        Player_Order = table.wipe(Player_Order);

        for k, v in pairs(Player_Info) do
            table.insert(Player_Order, v);
        end

        -- Sort the player list in temp array
        if BuffwatchPlayerConfig.SortOrder == BW_SORTORDER_DROPDOWN_LIST[2] then -- "Class"

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

        elseif BuffwatchPlayerConfig.SortOrder == BW_SORTORDER_DROPDOWN_LIST[3] then -- "Name"

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

end


function Buffwatch_GetAllBuffs()

    for k, v in pairs(Player_Info) do
        Buffwatch_Player_GetBuffs(v);
    end

    Buffwatch_ResizeWindow();

end


function Buffwatch_Player_GetBuffs(v)

    local curr_lock = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"];

    if not curr_lock:GetChecked() then

        if InCombatLockdown() then

            Buffwatch_Add_InCombat_Events({"GetBuffs", v});

        else

            -- Reset list of buffs for the player
            BuffwatchPlayerBuffs[v.Name]["Buffs"] = { };
            BuffwatchSaveBuffs[v.Name] = nil;

            local showbuffs, showallplayer;

            -- Setup buff filter
            if BuffwatchPlayerConfig.ShowCastableBuffs == true then
                showbuffs = "RAID";
            else
                showbuffs = "";
            end

            if UnitIsUnit(v.UNIT_ID, "player") and BuffwatchPlayerConfig.ShowAllForPlayer == true then
                showbuffs = "";
                showallplayer = true;
            end

            local lastshownid = 0;

            for i = 1, 32 do

                -- temporary code to get around broken RAID filter for UnitAura()
                --local buff, rank, icon, _, _, duration, expTime, caster = UnitBuff(v.UNIT_ID, i, showbuffs);
                local buff, rank, icon, _, _, duration, expTime, caster = UnitBuff(v.UNIT_ID, i);
                if buff and showbuffs == "RAID" then
                	local isCastable = GetSpellInfo(buff);
                	-- If we cant cast this buff, dont show it
                	if isCastable == nil then
                		buff = nil;
                	end
                end
                
                local curr_buff = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i];

                if buff and (not BuffwatchPlayerConfig.ShowOnlyMine or (caster == "player") or showallplayer) then

                    -- Check if buff button has been created
                    if curr_buff == nil then

                        curr_buff = CreateFrame("Button", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i,
                            _G["BuffwatchFrame_PlayerFrame"..v.ID], "Buffwatch_BuffButton_Template");
                        curr_buff:SetID(i);

                        local cooldown = CreateFrame("Cooldown", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."_Cooldown",
                            curr_buff, "CooldownFrameTemplate");
                        curr_buff.cooldown = cooldown;
                        cooldown:SetAllPoints(curr_buff);
                        cooldown:SetReverse(true);

                    end

                    if lastshownid == 0 then
                        curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Name", "TOPLEFT", maxnamewidth + 5, 4);
                    else
                        curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..lastshownid, "TOPRIGHT");
                    end

                    lastshownid = i;

                    local curr_buff_icon = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"];

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
--Buffwatch_Debug("GetBuffs1: Player="..v.Name)
                    if BuffwatchConfig.Spirals == true and duration and duration > 0 then
--Buffwatch_Debug("GetBuffs1: BuffID="..i..", expTime="..expTime..",duration="..duration)
                        curr_buff.cooldown:Show();
                        curr_buff.cooldown.noCooldownCount = BuffwatchConfig.HideOmniCC;
                        curr_buff.cooldown:SetCooldown(expTime - duration, duration);
                    else
--Buffwatch_Debug("GetBuffs1: BuffID="..i..", Hiding")
                        curr_buff.cooldown:Hide();
                    end

                else

                    if curr_buff then

                        local curr_buff_icon = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"];

                        curr_buff:Hide();
                        curr_buff_icon:SetTexture(nil);

                    end

                end

            end

        end

    else

        -- Refresh currently locked buffs
        for i = 1, 32 do

            local curr_buff = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i];
            local curr_buff_icon = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"];

            if curr_buff and curr_buff:IsShown() then

                -- Set buff icon to grey if player is dead or offline
                if UnitIsDeadOrGhost(v.UNIT_ID) or UnitIsConnected(v.UNIT_ID) == nil then

                    curr_buff_icon:SetVertexColor(0.4,0.4,0.4);

                else

                    local buff = BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Buff"];
                    local rank = BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Rank"];
                    local buffbuttonid, duration, expTime;

                    buffbuttonid, duration, expTime = UnitHasBuff(v.UNIT_ID, buff, rank);

                    if buffbuttonid ~= 0 then
                        -- Set buff icon to its normal colour if it exists
                        curr_buff_icon:SetVertexColor(1,1,1);

                    else

                        -- Buff has expired, start by checking if there is an automatic replacement
                        local buffGroup = GroupBuffs.Buff[buff];

                        if buffGroup then

                            -- Iterate Group for this buff
                            for index, val in ipairs(GroupBuffs.Group[buffGroup]) do

                              if val ~= buff then

                                buffbuttonid = UnitHasBuff(v.UNIT_ID, val);

                                if buffbuttonid ~= 0 then

                                  buff = val;
                                  break;

                                end

                              end

                            end

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
--Buffwatch_Debug("GetBuffs2: Player="..v.Name)
                    if BuffwatchConfig.Spirals == true and duration and duration > 0 then
--Buffwatch_Debug("GetBuffs2: BuffID="..i..", expTime="..expTime..",duration="..duration)
                        curr_buff.cooldown:Show();
                        curr_buff.cooldown.noCooldownCount = BuffwatchConfig.HideOmniCC;
                        curr_buff.cooldown:SetCooldown(expTime - duration, duration);
                    else
--Buffwatch_Debug("GetBuffs2: BuffID="..i..", Hiding")
                        curr_buff.cooldown:Hide();
                    end

                end

            end

        end

    end

end


-- Set buff button alignment based on longest player name
function Buffwatch_SetBuffAlignment()

    for k, v in pairs(Player_Info) do

        if BuffwatchPlayerBuffs[v.Name] then

            local i = next(BuffwatchPlayerBuffs[v.Name]["Buffs"]);

            if i then

                local curr_buff = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i];

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

            local curr_buff = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i];

            if BuffwatchSaveBuffs[v.Name]["Buffs"][i] then

                -- Check if buff button has been created
                if curr_buff == nil then

                    curr_buff = CreateFrame("Button", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i,
                        _G["BuffwatchFrame_PlayerFrame"..v.ID], "Buffwatch_BuffButton_Template");
                    curr_buff:SetID(i);

                    local cooldown = CreateFrame("Cooldown", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."_Cooldown",
                        curr_buff, "CooldownFrameTemplate");
                    curr_buff.cooldown = cooldown;
                    cooldown:SetAllPoints(curr_buff);
                    cooldown:SetReverse(true);

                end

                if i == 1 then
                    curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Name", "TOPLEFT", maxnamewidth + 5, 4);
                else
                    curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..(i-1), "TOPRIGHT");
                end

                local curr_buff_icon = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"];

                curr_buff_icon:SetVertexColor(1,1,1);
                curr_buff:Show();
                curr_buff_icon:SetTexture(BuffwatchSaveBuffs[v.Name]["Buffs"][i]["Icon"]);

                curr_buff:SetAttribute("type", "spell");
                curr_buff:SetAttribute("unit1", v.UNIT_ID);
                curr_buff:SetAttribute("spell1", BuffwatchSaveBuffs[v.Name]["Buffs"][i]["Buff"].."("..BuffwatchSaveBuffs[v.Name]["Buffs"][i]["Rank"]..")");
--Buffwatch_Debug("LoadBuffs: Player="..v.Name)
                if BuffwatchConfig.Spirals == true and duration and duration > 0 then
--Buffwatch_Debug("LoadBuffs: BuffID="..i..", expTime="..expTime..",duration="..duration)
                    curr_buff.cooldown:Show();
                    curr_buff.cooldown.noCooldownCount = BuffwatchConfig.HideOmniCC;
                    curr_buff.cooldown:SetCooldown(expTime - duration, duration);
                else
--Buffwatch_Debug("LoadBuffs: BuffID="..i..", Hiding")
                    curr_buff.cooldown:Hide();
                end

            else

                if curr_buff then

                    local curr_buff_icon = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"];

                    curr_buff:Hide();
                    curr_buff_icon:SetTexture(nil);

                end

            end

        end

        _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"]:SetChecked(true);

     else

        _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"]:SetChecked(false);
        BuffwatchFrame_LockAll:SetChecked(false);

     end

end


function Buffwatch_ResizeWindow()

    if not InCombatLockdown() and framePositioned == true then

        local x, y = Buffwatch_GetPoint(BuffwatchFrame, BW_ANCHORPOINT_DROPDOWN_MAP[BuffwatchPlayerConfig.AnchorPoint]);

        if not minimized then

            local len, width;

            if HideUnmonitored == false then
                BuffwatchFrame:SetHeight(24 + (#Player_Order * 18));
            else

                local players = 0;

                -- Only count player frames that are not hidden
                for k, v in pairs(Player_Info) do
                    if not _G["BuffwatchFrame_PlayerFrame"..v.ID.."_Lock"]:GetChecked() or (next(BuffwatchPlayerBuffs[v.Name]["Buffs"], nil) ~= nil) then
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

            width = math.max(32 + maxnamewidth + (maxbuffs * 18), 115);

            BuffwatchFrame:SetWidth(width);

        else

            BuffwatchFrame:SetHeight(20);
            BuffwatchFrame:SetWidth(115);

        end

        Buffwatch_SetPoint(BuffwatchFrame, BW_ANCHORPOINT_DROPDOWN_MAP[BuffwatchPlayerConfig.AnchorPoint], x, y);

    end

end

-- Inspect all visible player locks, return true if they are all checked
function Buffwatch_InspectPlayerLocks()

        local allchecked = true;

        -- Iterate through each player
        for k, v in pairs(Player_Info) do

            local curr_lock = _G["BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock"];

            if not curr_lock:GetChecked() then
                allchecked = false;
                break;
            end

        end

        return allchecked;

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
                    break;
                end

            elseif value[1] == "GetPlayerInfo" then
                found = true;
                break;

            end

        end

    end

    -- Add it to the queue, if its not already on it
    if not found then
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

            if Player_Info[t[2]] ~= nil then
            	Buffwatch_Player_GetBuffs(t[2]);
            end

        end

        t = table.remove(InCombat_Events, 1);

        eventfired = true;

    end

    if eventfired then
        Buffwatch_ResizeWindow();
    end

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

    InterfaceOptionsFrame_OpenToCategory(BW_ADDONNAME);

end


function Buffwatch_ShowHelp()

    InterfaceOptionsFrame_OpenToCategory(BW_HELPFRAMENAME);

end


function Buffwatch_HideUnmonitored_Clicked(self)

    if InCombatLockdown() then

        Buffwatch_Print("Cannot hide or show buffs while in combat.");

    else

        HideUnmonitored = not HideUnmonitored;

        Buffwatch_PositionAllPlayerFrames();
        Buffwatch_ResizeWindow();

    end

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

    return i;

end


function UnitHasBuff(unit, buff, rank)

  local thisbuff, thisrank, duration, expTime;

  for i = 1, 32 do

    thisbuff, thisrank, _, _, _, duration, expTime = UnitBuff(unit, i);

    if not thisbuff then break; end

    if thisbuff == buff then

      if rank then
        if thisrank == rank then
          return i, duration, expTime;
        else
          return 0;
        end
      else
        return i, duration, expTime;
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

    local nametext = _G["BuffwatchFrame_PlayerFrame"..v.ID.."_NameText"];

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


function Buffwatch_GetPoint(frame, point)

    local x, y;

    if point == "TOPRIGHT" then
        x = frame:GetRight();
        y = frame:GetTop();
    elseif point == "TOPLEFT" then
        x = frame:GetLeft();
        y = frame:GetTop();
    elseif point == "BOTTOMLEFT" then
        x = frame:GetLeft();
        y = frame:GetBottom();
    elseif point == "BOTTOMRIGHT" then
        x = frame:GetRight();
        y = frame:GetBottom();
    elseif point == "CENTER" then
        x = (frame:GetLeft() + frame:GetRight())/2;
        y = (frame:GetTop() + frame:GetBottom())/2;
    end

    BuffwatchPlayerConfig.AnchorX = x;
    BuffwatchPlayerConfig.AnchorY = y;

    return x, y;
end

function Buffwatch_SetPoint(frame, point, x, y)

    if point ~= "" then

        frame:ClearAllPoints();
        frame:SetPoint(point, UIParent, "BOTTOMLEFT", x, y);

    end

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

function Buffwatch_DebugPosition()

    if BuffwatchPlayerConfig.debugleft ~= nil then
        Buffwatch_Debug("Buffwatch Old Position Top : "..BuffwatchPlayerConfig.debugtop..", Left : "..BuffwatchPlayerConfig.debugleft, 1, 0.2, 0.2);
    end
    BuffwatchPlayerConfig.debugtop = BuffwatchFrame:GetTop();
    BuffwatchPlayerConfig.debugleft = BuffwatchFrame:GetLeft();
    Buffwatch_Debug("Buffwatch New Position Top : "..BuffwatchPlayerConfig.debugtop..", Left : "..BuffwatchPlayerConfig.debugleft, 0.2, 1, 0.2);

end

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
