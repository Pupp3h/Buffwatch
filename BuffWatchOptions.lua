BW_TTIP_ALPHA = "Sets the transparency of the Buffwatch window";
BW_TTIP_ANCHORPOINT = "Determines which direction the window expands when resizing";
BW_TTIP_HIDEOMNICC = "Hide OmniCC text overlays";
BW_TTIP_MODE = "Selects which players to show";
BW_TTIP_PLAYEXPIREDSOUND = "Plays a sound if buffs have started to expire";
BW_TTIP_SCALE = "Sets the scale of the Buffwatch window";
BW_TTIP_SHOWALLFORPLAYER = "Always show all buffs for this player";
BW_TTIP_SHOWCASTABLEBUFFS = "Only show buffs you can cast on other players";
BW_TTIP_SHOWDEBUFFS = "Show debuffs";
BW_TTIP_SHOWDISPELLDEBUFFS = "Only show debuffs you can dispell";
BW_TTIP_SHOWEXPIREDWARNING = "Shows a warning if buffs have started to expire";
BW_TTIP_SHOWONLYMINE = "Only show buffs you have cast";
BW_TTIP_SHOWPETS = "Show pets in the player list";
BW_TTIP_SHOWSPIRALS = "Enable cooldown spirals on buff buttons";
BW_TTIP_SORTORDER = "Specifies the sort order for the player list in the Buffwatch Window";

-- Temp global & player options
BuffwatchTempConfig = {};
BuffwatchTempPlayerConfig = {};

function Buffwatch_Options_OnLoad(self)

    Buffwatch_Options_Title:SetText(BW_ADDONNAME);

    self.name = BW_ADDONNAME;
    self.default = Buffwatch_Options_SetDefaults;
    self.refresh = Buffwatch_Options_Init;
--    self.okay = Buffwatch_Options_OkayButton;
    self.cancel = Buffwatch_Options_CancelButton;
    InterfaceOptions_AddCategory(self);

end

function Buffwatch_Options_Init()

    BuffwatchTempConfig = CopyTable(BuffwatchConfig);
    BuffwatchTempPlayerConfig = CopyTable(BuffwatchPlayerConfig);

    UIDropDownMenu_SetSelectedValue(Buffwatch_Options_Mode, BuffwatchPlayerConfig.Mode);
    UIDropDownMenu_SetText(Buffwatch_Options_Mode, BuffwatchPlayerConfig.Mode);

    UIDropDownMenu_SetSelectedValue(Buffwatch_Options_SortOrder, BuffwatchPlayerConfig.SortOrder);
    UIDropDownMenu_SetText(Buffwatch_Options_SortOrder, BuffwatchPlayerConfig.SortOrder);

    UIDropDownMenu_SetSelectedValue(Buffwatch_Options_AnchorPoint, BuffwatchPlayerConfig.AnchorPoint);
    UIDropDownMenu_SetText(Buffwatch_Options_AnchorPoint, BuffwatchPlayerConfig.AnchorPoint);

    Buffwatch_Options_ShowPets:SetChecked(BuffwatchPlayerConfig.ShowPets);
    Buffwatch_Options_ShowPets_OnClick(Buffwatch_Options_ShowPets);

    Buffwatch_Options_ShowOnlyMine:SetChecked(BuffwatchPlayerConfig.ShowOnlyMine);
    Buffwatch_Options_ShowOnlyMine_OnClick(Buffwatch_Options_ShowOnlyMine, true);

    Buffwatch_Options_ShowOnlyCastableBuffs:SetChecked(BuffwatchPlayerConfig.ShowCastableBuffs);
    Buffwatch_Options_ShowOnlyCastableBuffs_OnClick(Buffwatch_Options_ShowOnlyCastableBuffs, true);

    Buffwatch_Options_ShowAllForPlayer:SetChecked(BuffwatchPlayerConfig.ShowAllForPlayer);
    Buffwatch_Options_ShowAllForPlayer_OnClick(Buffwatch_Options_ShowAllForPlayer, true);

--    Buffwatch_Options_ShowDebuffs:SetChecked(BuffwatchPlayerConfig.ShowDebuffs);
--    Buffwatch_Options_ShowOnlyDispellDebuffs:SetChecked(BuffwatchPlayerConfig.ShowDispellableDebuffs);
--    Buffwatch_Options_ShowExpiredWarning:SetChecked(BuffwatchConfig.ExpiredWarning);
--    Buffwatch_Options_PlayExpiredSound:SetChecked(BuffwatchConfig.ExpiredSound);

    Buffwatch_Options_ShowSpirals:SetChecked(BuffwatchConfig.Spirals);
    Buffwatch_Options_ShowSpirals_OnClick(Buffwatch_Options_ShowSpirals, true);

    Buffwatch_Options_HideOmniCC:SetChecked(BuffwatchConfig.HideOmniCC);
    if (not OmniCC) then
        Buffwatch_Options_HideOmniCC:Hide();
    else
    	Buffwatch_Options_HideOmniCC:Show();
    end
    Buffwatch_Options_HideOmniCC_OnClick(Buffwatch_Options_HideOmniCC, true);

    Buffwatch_Options_Alpha:SetValue(BuffwatchConfig.Alpha);
    Buffwatch_Options_Scale:SetValue(BuffwatchPlayerConfig.Scale);

    if (framePositioned == true) then
        Buffwatch_GetAllBuffs();
    end
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
--    UIDropDownMenu_SetText(self, BuffwatchPlayerConfig.SortOrder);
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
--    UIDropDownMenu_SetText(self, BuffwatchPlayerConfig.AnchorPoint);
    UIDropDownMenu_SetWidth(self, 100);
end

function Buffwatch_Options_ShowPets_OnClick(self)
    if (self:GetChecked()) then
        BuffwatchPlayerConfig.ShowPets = true;
    else
        BuffwatchPlayerConfig.ShowPets = false;
    end
    Buffwatch_Set_UNIT_IDs(true);
    Buffwatch_ResizeWindow();
end

function Buffwatch_Options_ShowOnlyMine_OnClick(self, suppressRefresh)
    if (self:GetChecked()) then
        BuffwatchPlayerConfig.ShowOnlyMine = true;
        Buffwatch_EnableCheckbox(Buffwatch_Options_ShowAllForPlayer);
    else
        BuffwatchPlayerConfig.ShowOnlyMine = false;
        if BuffwatchPlayerConfig.ShowCastableBuffs == false then
          Buffwatch_DisableCheckbox(Buffwatch_Options_ShowAllForPlayer);
        end
    end

    if (suppressRefresh ~= true) then
        Buffwatch_GetAllBuffs();
    end
end

function Buffwatch_Options_ShowOnlyCastableBuffs_OnClick(self, suppressRefresh)
    if (self:GetChecked()) then
        BuffwatchPlayerConfig.ShowCastableBuffs = true;
        Buffwatch_EnableCheckbox(Buffwatch_Options_ShowAllForPlayer);
    else
        BuffwatchPlayerConfig.ShowCastableBuffs = false;
        if BuffwatchPlayerConfig.ShowOnlyMine == false then
          Buffwatch_DisableCheckbox(Buffwatch_Options_ShowAllForPlayer);
        end
    end

    if (suppressRefresh ~= true) then
        Buffwatch_GetAllBuffs();
    end

end

function Buffwatch_Options_ShowAllForPlayer_OnClick(self, suppressRefresh)
    if (self:GetChecked()) then
        BuffwatchPlayerConfig.ShowAllForPlayer = true;
    else
        BuffwatchPlayerConfig.ShowAllForPlayer = false;
    end

    if (suppressRefresh ~= true) then
        Buffwatch_GetAllBuffs();
    end

end

function Buffwatch_Options_ShowSpirals_OnClick(self, suppressRefresh)
    if (self:GetChecked()) then
        BuffwatchConfig.Spirals = true;
        if (OmniCC) then
            Buffwatch_EnableCheckbox(Buffwatch_Options_HideOmniCC);
        end
    else
        BuffwatchConfig.Spirals = false;
        if (OmniCC) then
            Buffwatch_DisableCheckbox(Buffwatch_Options_HideOmniCC);
        end
    end

    if (suppressRefresh ~= true) then
        Buffwatch_GetAllBuffs();
    end

end

function Buffwatch_Options_HideOmniCC_OnClick(self, suppressRefresh)
    if (self:GetChecked()) then
        BuffwatchConfig.HideOmniCC = true;
    else
        BuffwatchConfig.HideOmniCC = false;
    end

    if (suppressRefresh ~= true) then
        Buffwatch_GetAllBuffs();
    end
    
    if (OmniCC) then
        OmniCC.Timer:ForAllShown('UpdateShown');
    end    

end

function Buffwatch_Options_SetDefaults()
    BuffwatchConfig = CopyTable(BW_DEFAULTS);
    BuffwatchPlayerConfig = CopyTable(BW_PLAYER_DEFAULTS);
end

--[[
function Buffwatch_Options_OkayButton()

end
]]

function Buffwatch_Options_CancelButton()
    BuffwatchConfig = CopyTable(BuffwatchTempConfig);
    BuffwatchPlayerConfig = CopyTable(BuffwatchTempPlayerConfig);
    Buffwatch_Options_Init();
end

function Buffwatch_EnableCheckbox(checkbox)
    checkbox:Enable();
    _G[checkbox:GetName().."Text"]:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
end

function Buffwatch_DisableCheckbox(checkbox)
    checkbox:Disable();
    _G[checkbox:GetName().."Text"]:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
end