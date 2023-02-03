
-- ** Buffwatch
-- **
-- ** TODO:
-- **
-- **   Add an InCombat icon next to Buffwatch header
-- **

-- ** Check playerframe positioning if SortOrder == "Raid Order" and player gets moved groups.
-- ** Check / Fix / Improve Window Resizing code
-- ** Add seperate frame for debuffs, so it can be shown/hidden/ressized in combat?

-- ** Warning message for buff expiring
-- ** Debuffs
-- ** Player targetting

-- ****************************************************************************
-- **                                                                        **
-- **  Variables                                                             **
-- **                                                                        **
-- ****************************************************************************

BW_VERSION = "2.0b2";
BW_RELEASE_DATE = "5 January 2007";
BW_SORTORDER_DROPDOWN_LIST = {
    "Raid Order",
    "Class",
    "Name"
};

local grouptype;
local maxnamewidth = 0;
local maxnameid = 1;
--local maxbuffs = 0;
--local maxbuffid = 1;
local buffexpired = 0;

local Player_Info = { };
local Player_Left = { };
local Player_Order = { };
local UNIT_IDs = { };
local InCombat_Events = { };

BuffwatchConfig = { AlignBuffs, Alpha, ExpiredSound, ExpiredWarning,
    ShowCastableBuffs, ShowDebuffs, ShowDispellableDebuffs, ShowPets,
    SortOrder, debug };

BuffwatchPlayerBuffs = { };

local debugchatframe = DEFAULT_CHAT_FRAME;

-- BuffwatchConfig = { rightMouseSpell, show_on_startup, DebuffsAlwaysVisible
--    HighlightPvP, UpdPerSec, ShowUpdPerSec };

-- ****************************************************************************
-- **                                                                        **
-- **  Events & Related                                                      **
-- **                                                                        **
-- ****************************************************************************

function Buffwatch_OnLoad()

    this:RegisterEvent("PLAYER_LOGIN");
    this:RegisterEvent("PARTY_MEMBERS_CHANGED");
    this:RegisterEvent("RAID_ROSTER_UPDATE");
    this:RegisterEvent("UNIT_PET");
--    this:RegisterEvent("UNIT_SPELLCAST_SENT");
    this:RegisterEvent("UNIT_AURA");
--    this:RegisterEvent("UNIT_FACTION");
    this:RegisterEvent("VARIABLES_LOADED");
    this:RegisterEvent("PLAYER_REGEN_ENABLED");
    this:RegisterEvent("PLAYER_REGEN_DISABLED");

    SlashCmdList["BUFFWATCH"] = Buffwatch_SlashHandler;
    SLASH_BUFFWATCH1 = "/buffwatch";
    SLASH_BUFFWATCH2 = "/bfw";

end


function Buffwatch_OnEvent(event, ...)
--[[
Buffwatch_Debug("Event vars for "..event..":");
for i = 1, select("#", ...) do
    Buffwatch_Debug("i="..i..", v="..select(i, ...));
end
]]
    if event == "VARIABLES_LOADED" then

        if BuffwatchConfig.AlignBuffs == nil then
            BuffwatchConfig.AlignBuffs = true;
        end

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

        if BuffwatchConfig.ShowCastableBuffs == nil then
            BuffwatchConfig.ShowCastableBuffs = false;
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

        if BuffwatchConfig.debug == nil then
            BuffwatchConfig.debug = false;
        end

        Buffwatch_Options_Init();

    end

    if BuffwatchFrame_PlayerFrame:IsVisible() then

        if event == "PLAYER_LOGIN" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE"
            or (event == "UNIT_PET" and BuffwatchConfig.ShowPets == true) then


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

        elseif event == "UNIT_AURA" and select(1, ...) ~= "target" then

            for k, v in pairs(Player_Info) do

                if select(1, ...) == v.UNIT_ID then
                    Buffwatch_Player_GetBuffs(v);
                    Buffwatch_ResizeWindow();
                    break;
                end

            end

        elseif event == "PLAYER_REGEN_ENABLED" then

            BuffwatchFrame_LockAll:Enable();

            for k, v in pairs(Player_Info) do
                local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock")
                curr_lock:Enable();
            end

            Buffwatch_Process_InCombat_Events();

        elseif event == "PLAYER_REGEN_DISABLED" then

            BuffwatchFrame_LockAll:Disable();

            for k, v in pairs(Player_Info) do
                local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock")
                curr_lock:Disable();
            end

        end

    end

end

function Buffwatch_Set_AllChecks(checked)

    for k, v in pairs(Player_Info) do

        local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock")

        if curr_lock:GetChecked() ~= checked then
            curr_lock:SetChecked(checked);

            if not checked then
                Buffwatch_Player_GetBuffs(v);
            end
--            Buffwatch_Player_SaveBuffs(v.ID);
        end

    end

    if not checked then
        Buffwatch_ResizeWindow();
    end

end


function Buffwatch_Header_Clicked(button, down)

    if button == "RightButton" then
        ToggleDropDownMenu(1, nil, getglobal("BuffwatchFrame_DropDown"), "BuffwatchFrame_Header", 40, 0);
    end

end


function Buffwatch_DropDown_OnLoad()
    UIDropDownMenu_Initialize(this, Buffwatch_DropDown_Initialize, "MENU");
    UIDropDownMenu_SetAnchor(0, 0, this, "TOPLEFT", "BuffwatchFrame_Header", "CENTER");
end


function Buffwatch_DropDown_Initialize()

    info = {};
    info.text = "Refresh";
    info.func = function()
        Buffwatch_GetPlayerInfo();
        Buffwatch_GetAllBuffs();
    end
    UIDropDownMenu_AddButton(info);

    info = {};
    info.text = "Options";
    info.func = Buffwatch_OptionsToggle;
    UIDropDownMenu_AddButton(info);

    info = {};
    info.text = "Help";
    info.func = Buffwatch_ShowHelp;
    UIDropDownMenu_AddButton(info);

    info = {};
    info.text = "Close Buffwatch";
    info.func = Buffwatch_Toggle;
    UIDropDownMenu_AddButton(info);

    info = {};
    info.disabled = 1;
    UIDropDownMenu_AddButton(info);

    info = {};
    info.text = "Hide";
    info.func = function()
        BuffwatchFrame_DropDown:Hide();
    end
    UIDropDownMenu_AddButton(info);

end


function Buffwatch_Check_Clicked(button, down)

    local playerid = this:GetParent():GetID();
    local playername = getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_NameText"):GetText();
    local checked = this:GetChecked();

    if checked then

        for k, v in pairs(Player_Info) do

            local curr_lock = getglobal("BuffwatchFrame_PlayerFrame" .. v.ID .. "_Lock");

            if not curr_lock:GetChecked() then
                checked = nil;
                break;
            end

        end

        if checked then
            BuffwatchFrame_LockAll:SetChecked(true);
        end

    else
        BuffwatchFrame_LockAll:SetChecked(false);
        Buffwatch_Player_GetBuffs(Player_Info[playername]);
        Buffwatch_ResizeWindow();
    end

--    BW_Player_SaveBuffs(this:GetParent():GetID());

end


function Buffwatch_Name_Clicked(button, down)

end


function Buffwatch_Buff_Clicked(button, down)

    local playerid = this:GetParent():GetID();
    local playerframe = "BuffwatchFrame_PlayerFrame"..playerid;

    if getglobal(playerframe.."_Lock"):GetChecked() and IsAltKeyDown() then

        if InCombatLockdown() then

            Buffwatch_Print("Cannot hide buffs while in combat.");

        else

            local buffid = this:GetID();
            local playername = getglobal(playerframe.."_NameText"):GetText();

            if button == "LeftButton" then

                for i = 1, 32 do
                    if getglobal(playerframe.."_Buff"..i) then
                        if i ~= buffid then
                            getglobal(playerframe.."_Buff"..i):Hide();
                            BuffwatchPlayerBuffs[playername]["Buffs"][i] = nil;
                        else
                            this:SetPoint("TOPLEFT", playerframe.."_Name", "TOPRIGHT", 5, 4);
                        end
                    else
                        break;
                    end
                end

                Buffwatch_ResizeWindow();
--                Buffwatch_Player_SaveBuffs(playerid)

            elseif button == "RightButton" then

                local nextbuffid = next(BuffwatchPlayerBuffs[playername]["Buffs"], buffid);

                this:Hide();
                BuffwatchPlayerBuffs[playername]["Buffs"][buffid] = nil;

                if nextbuffid then
                    getglobal(playerframe.."_Buff"..nextbuffid):ClearAllPoints();
                    getglobal(playerframe.."_Buff"..nextbuffid):SetPoint(this:GetPoint());
                end

                Buffwatch_ResizeWindow();
--                Buffwatch_Player_SaveBuffs(playerid)

            end

        end

    end

end


function Buffwatch_Buff_Tooltip()

    local playername = getglobal("BuffwatchFrame_PlayerFrame"..this:GetParent():GetID().."_NameText"):GetText();
    local unit = Player_Info[playername]["UNIT_ID"];
    local buff = BuffwatchPlayerBuffs[playername]["Buffs"][this:GetID()]["Buff"];
    local rank = BuffwatchPlayerBuffs[playername]["Buffs"][this:GetID()]["Rank"];
    local buffbuttonid = nil;
    local debuffbuttonid = nil;

    buffbuttonid = UnitHasBuff(unit, buff, rank);

    if buffbuttonid == 0 then
        debuffbuttonid = UnitHasDebuff(unit, buff, rank);
    end


    if buffbuttonid then
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT");
        GameTooltip:SetUnitBuff(unit, buffbuttonid);
    elseif debuffbuttonid then
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT");
        GameTooltip:SetUnitDebuff(unit, debuffbuttonid);
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

    else

        Buffwatch_Print("Buffwatch commands (/buffwatch or /bfw):");
        Buffwatch_Print("/bfw toggle - Toggle the Buffwatch window on or off");
        Buffwatch_Print("/bfw options - Toggle the options window on or off");

    end

end


-- Setup basic list of possible UNIT_IDs
function Buffwatch_Set_UNIT_IDs(forced)

    if GetNumRaidMembers() > 0 then

        if grouptype ~= "raid" or forced == true then

            UNIT_IDs = { };

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

        UNIT_IDs = { };

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

--            if unitname ~= nil and unitname ~= "Unknown Entity" then
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

                    local namebutton = getglobal("BuffwatchFrame_PlayerFrame"..id.."_Name");
                    local nametext = getglobal("BuffwatchFrame_PlayerFrame"..id.."_NameText");

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

                    nametext:SetText(unitname);
                    namebutton:SetWidth(nametext:GetStringWidth());

                    if maxnamewidth < nametext:GetStringWidth() then
                        maxnamewidth = nametext:GetStringWidth();
                        maxnameid = id;
                    end

                    Player_Info[unitname]["UNIT_ID"] = UNIT_IDs[i];
                    Buffwatch_Player_ColourName(Player_Info[unitname]);

                    if not BuffwatchPlayerBuffs[unitname] then
                        BuffwatchPlayerBuffs[unitname] = { };
                        BuffwatchPlayerBuffs[unitname]["Buffs"] = { };
                    end
Buffwatch_Player_GetBuffs(Player_Info[unitname]); -- Temp until Buffwatch_Player_LoadBuffs() below is done

--                    Buffwatch_Player_LoadBuffs(id);

                    positionframe = true;

                end

                -- Update any information that may have changed about this person,
                --    whether we captured before, or are taking for first time
                Player_Info[unitname]["UNIT_ID"] = UNIT_IDs[i];

                if grouptype == "raid" then
                    local subgroup;
--                    local lastsubgroup = Player_Info[unitname]["SubGroup"];
                    local j = math.fmod(i, 40);
                    if j == 0 then j = 40 end;
                    _, _, subgroup = GetRaidRosterInfo(j);

--                    if not lastsubgroup or subgroup ~= lastsubgroup then -- ***** Check logic or if needed
                    if subgroup ~= Player_Info[unitname]["SubGroup"] then
                        Player_Info[unitname]["SubGroup"] = subgroup;
                        if sort == "Raid Order" then
                            positionframe = true;
                        end
                    end
                else
                    Player_Info[unitname]["SubGroup"] = 1;
                end

                Player_Info[unitname]["Checked"] = 1;

            end

            if positionframe == true then
Buffwatch_Debug("Showing player frame "..Player_Info[unitname].ID.." for "..unitname);
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
--                BuffwatchPlayerBuffs[k] = nil;

Buffwatch_Debug("Hiding player frame "..v.ID.." for "..v.Name);
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

        end

    end

end


function Buffwatch_PositionPlayerFrame(playerid)

    local playerframe = getglobal("BuffwatchFrame_PlayerFrame"..playerid);
    local arraypos;

    -- Find playerframe in current order
    for k, v in ipairs(Player_Order) do

        if playerid == v.ID then
            arraypos = k;
            break;
        end

    end

    if arraypos and Player_Order[arraypos+1] then

        -- Remove frame from order
        local nextplayer = getglobal("BuffwatchFrame_PlayerFrame"..Player_Order[arraypos+1].ID);

        if nextplayer then
            nextplayer:ClearAllPoints();
            nextplayer:SetPoint(playerframe:GetPoint());
        end

    end

    playerframe:ClearAllPoints();

    Buffwatch_GetPlayerSortOrder();

    arraypos = nil;

    -- Insert frame into new order
    for k, v in ipairs(Player_Order) do

        if playerid == v.ID then

            arraypos = k;

            if k == 1 then

                playerframe:SetPoint("TOPLEFT", BuffwatchFrame_PlayerFrame);

            else

                playerframe:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..Player_Order[k-1].ID, "BOTTOMLEFT");

            end

            if Player_Order[k+1] then

                local nextplayer = getglobal("BuffwatchFrame_PlayerFrame"..Player_Order[k+1].ID);

                if nextplayer then
                    nextplayer:ClearAllPoints();
                    nextplayer:SetPoint("TOPLEFT", playerframe, "BOTTOMLEFT");
                end

            end

            break;

        end

    end

    if arraypos then
        playerframe:Show();
    else
        playerframe:Hide();
--        getglobal("BuffwatchFrame_PlayerFrame"..playerid.."_NameText"):SetText(nil);
    end

end

function Buffwatch_GetPlayerSortOrder()

    Player_Order = { };

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

            BuffwatchPlayerBuffs[v.Name]["Buffs"] = { };

            for i = 1, 32 do

                local buff, rank, icon = UnitBuff(v.UNIT_ID, i, BuffwatchConfig.ShowCastableBuffs);
                local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i);

--[[if buff then
    Buffwatch_Debug(i.." : buff="..buff);
end]]

                if buff then

                    -- Check if buff button has been created
                    if curr_buff == nil then

                        curr_buff = CreateFrame("Button", "BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i,
                            getglobal("BuffwatchFrame_PlayerFrame"..v.ID), "Buffwatch_BuffButton_Template");
                        curr_buff:SetID(i);

                    end

                    if i == 1 then
                        curr_buff:SetPoint("TOPLEFT", "BuffwatchFrame_PlayerFrame"..v.ID.."_Name", "TOPRIGHT", 5, 4);
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

        for i = 1, 32 do

            local curr_buff = getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i);

            if curr_buff and curr_buff:IsShown() then

                if UnitIsDeadOrGhost(v.UNIT_ID) or UnitIsConnected(v.UNIT_ID) == nil then

                    getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"):SetVertexColor(0.4,0.4,0.4);

                else

                    local buff = BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Buff"];
                    local rank = BuffwatchPlayerBuffs[v.Name]["Buffs"][i]["Rank"];
                    local buffbuttonid;

                    buffbuttonid = UnitHasBuff(v.UNIT_ID, buff, rank);

                    if buffbuttonid ~= 0 then
                        getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"):SetVertexColor(1,1,1);
                    else
                        getglobal("BuffwatchFrame_PlayerFrame"..v.ID.."_Buff"..i.."Icon"):SetVertexColor(1,0,0);
--[[                        buffexpired = buffexpired + 1;

                        if BuffwatchConfig.ExpiredWarning and buffexpired == 1 then
                            UIErrorsFrame:AddMessage("A buffwatch monitored buff has expired!", 0.2, 0.9, 0.9, 1.0, 2.0);

                            if BuffwatchConfig.ExpiredSound then
                                PlaySound("igQuestFailed");
                            end

--                            if minimized then
--                                BW_HeaderText:SetTextColor(1, 0, 0);
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


function Buffwatch_ResizeWindow()

    if not InCombatLockdown() then

        BuffwatchFrame:SetHeight(24 + (#Player_Order * 18));

        local maxbuffs = 0;
-- ***** may need to move this to only check when buffs actually get hidden or shown
        for k, v in pairs(BuffwatchPlayerBuffs) do

            if maxbuffs < #v.Buffs then
                maxbuffs = #v.Buffs;
--                maxbuffid = v.ID;
            end

        end

        BuffwatchFrame:SetWidth(math.max(32 + maxnamewidth + (maxbuffs * 18), 100));

    end

end


function Buffwatch_Add_InCombat_Events(value)

    local found;

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

    if not found then
Buffwatch_Debug("Adding InCombat_Event "..value[1]);
        table.insert(InCombat_Events, value);
    end

end


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
--                getglobal("BW_Player"..oldID):Show();
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

function GetInCombat_Events()

    return InCombat_Events;

end


