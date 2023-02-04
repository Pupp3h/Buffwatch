BW_TTIP_ALPHA = "Sets the transparency of the Buffwatch window";
BW_TTIP_ANCHORPOINT = "Determines which direction the window expands when resizing";
BW_TTIP_HIDEOMNICC = "Hide OmniCC text overlays";
BW_TTIP_MODE = "Selects which players to show";
BW_TTIP_PLAYEXPIREDSOUND = "Plays a sound if buffs have started to expire";
BW_TTIP_SHOWALLFORPLAYER = "Always show all buffs for this player";
BW_TTIP_SHOWCASTABLEBUFFS = "Only show buffs you can cast on other players";
BW_TTIP_SHOWDEBUFFS = "Show debuffs";
BW_TTIP_SHOWDISPELLDEBUFFS = "Only show debuffs you can dispell";
BW_TTIP_SHOWEXPIREDWARNING = "Shows a warning if buffs have started to expire";
BW_TTIP_SHOWONLYMINE = "Only show buffs you have cast";
BW_TTIP_SHOWPETS = "Show pets in the player list";
BW_TTIP_SHOWSPIRALS = "Enable cooldown spirals on buff buttons";
BW_TTIP_SORTORDER = "Specifies the sort order for the player list in the Buffwatch Window";


function Buffwatch_Options_OnLoad()

    -- Add Buffwatch_Options to the UIPanelWindows list
    UIPanelWindows["Buffwatch_Options"] = {area = "center", pushable = 0};
    
end

function Buffwatch_Options_Init()
    Buffwatch_Options_ShowPets:SetChecked(BuffwatchPlayerConfig.ShowPets);
    Buffwatch_Options_ShowOnlyCastableBuffs:SetChecked(BuffwatchPlayerConfig.ShowCastableBuffs);
    Buffwatch_Options_ShowAllForPlayer:SetChecked(BuffwatchPlayerConfig.ShowAllForPlayer);
--    Buffwatch_Options_ShowDebuffs:SetChecked(BuffwatchPlayerConfig.ShowDebuffs);
--    Buffwatch_Options_ShowOnlyDispellDebuffs:SetChecked(BuffwatchPlayerConfig.ShowDispellableDebuffs);
--    Buffwatch_Options_ShowExpiredWarning:SetChecked(BuffwatchConfig.ExpiredWarning);
--    Buffwatch_Options_PlayExpiredSound:SetChecked(BuffwatchConfig.ExpiredSound);
    Buffwatch_Options_ShowSpirals:SetChecked(BuffwatchConfig.Spirals);
    Buffwatch_Options_HideOmniCC:SetChecked(BuffwatchConfig.HideOmniCC);
    if (not OmniCC) then
        Buffwatch_Options_HideOmniCC:Hide();
    end 
    Buffwatch_Options_Alpha:SetValue(BuffwatchConfig.Alpha);
end

function Buffwatch_Options_Mode_OnClick(self)
    i = self:GetID();
    UIDropDownMenu_SetSelectedID(Buffwatch_Options_Mode, i);
    BuffwatchPlayerConfig.Mode = BW_MODE_DROPDOWN_LIST[i];
    Buffwatch_Set_UNIT_IDs();
    Buffwatch_ResizeWindow();
end

function Buffwatch_Options_Mode_Initialize()
    local info;
    for i = 1, #BW_MODE_DROPDOWN_LIST do
        info = {
            text = BW_MODE_DROPDOWN_LIST[i],
            func = Buffwatch_Options_Mode_OnClick
        };
        UIDropDownMenu_AddButton(info);
    end
end

function Buffwatch_Options_Mode_OnLoad(self)
    UIDropDownMenu_Initialize(self, Buffwatch_Options_Mode_Initialize);
    UIDropDownMenu_SetText(self, BuffwatchPlayerConfig.Mode);
    UIDropDownMenu_SetWidth(self, 90);
end

function Buffwatch_Options_SortOrder_OnClick(self)
    i = self:GetID();
    UIDropDownMenu_SetSelectedID(Buffwatch_Options_SortOrder, i);
    BuffwatchPlayerConfig.SortOrder = BW_SORTORDER_DROPDOWN_LIST[i];
    Buffwatch_PositionAllPlayerFrames();
end

function Buffwatch_Options_SortOrder_Initialize()
    local info;
    for i = 1, #BW_SORTORDER_DROPDOWN_LIST do
        info = {
            text = BW_SORTORDER_DROPDOWN_LIST[i],
            func = Buffwatch_Options_SortOrder_OnClick
        };
        UIDropDownMenu_AddButton(info);
    end
end

function Buffwatch_Options_SortOrder_OnLoad(self)
    UIDropDownMenu_Initialize(self, Buffwatch_Options_SortOrder_Initialize);
    UIDropDownMenu_SetText(self, BuffwatchPlayerConfig.SortOrder);
    UIDropDownMenu_SetWidth(self, 90);
end

function Buffwatch_Options_AnchorPoint_OnClick(self)
    i = self:GetID();
    UIDropDownMenu_SetSelectedID(Buffwatch_Options_AnchorPoint, i);
    BuffwatchPlayerConfig.AnchorPoint = BW_ANCHORPOINT_DROPDOWN_LIST[i];
    Buffwatch_GetPoint(BuffwatchFrame, BW_ANCHORPOINT_DROPDOWN_MAP[BuffwatchPlayerConfig.AnchorPoint]);
end

function Buffwatch_Options_AnchorPoint_Initialize()
    local info;
    for i = 1, #BW_ANCHORPOINT_DROPDOWN_LIST do
        info = {
            text = BW_ANCHORPOINT_DROPDOWN_LIST[i],
            func = Buffwatch_Options_AnchorPoint_OnClick
        };
        UIDropDownMenu_AddButton(info);
    end
end

function Buffwatch_Options_AnchorPoint_OnLoad(self)
    UIDropDownMenu_Initialize(self, Buffwatch_Options_AnchorPoint_Initialize);
    UIDropDownMenu_SetText(self, BuffwatchPlayerConfig.AnchorPoint);
    UIDropDownMenu_SetWidth(self, 100);
end

function Buffwatch_EnableCheckbox(checkbox)
    checkbox:Enable();
    getglobal(checkbox:GetName().."Text"):SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
end

function Buffwatch_DisableCheckbox(checkbox)
    checkbox:Disable();
    getglobal(checkbox:GetName().."Text"):SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
end