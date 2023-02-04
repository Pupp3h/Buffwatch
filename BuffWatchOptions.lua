BW_TTIP_SORTORDER = "Specifies the sort order for the player list in the Buffwatch Window";
BW_TTIP_SHOWPETS = "Show pets in the player list";
BW_TTIP_SHOWCASTABLEBUFFS = "Only show buffs you can cast on other players";
BW_TTIP_SHOWONLYMINE = "Only show buffs you have cast";
BW_TTIP_SHOWALLFORPLAYER = "Always show all buffs for this player";
BW_TTIP_SHOWDEBUFFS = "Show debuffs";
BW_TTIP_SHOWDISPELLDEBUFFS = "Only show debuffs you can dispell";
BW_TTIP_SHOWEXPIREDWARNING = "Shows a warning if buffs have started to expire";
BW_TTIP_PLAYEXPIREDSOUND = "Plays a sound if buffs have started to expire";
BW_TTIP_ALPHA = "Sets the transparency of the Buffwatch window";

function Buffwatch_Options_OnLoad()

    -- Add Buffwatch_Options to the UIPanelWindows list
    UIPanelWindows["Buffwatch_Options"] = {area = "center", pushable = 0};

end

function Buffwatch_Options_Init()
    Buffwatch_Options_ShowPets:SetChecked(BuffwatchConfig.ShowPets);
    Buffwatch_Options_ShowOnlyCastableBuffs:SetChecked(BuffwatchConfig.ShowCastableBuffs);
    Buffwatch_Options_ShowAllForPlayer:SetChecked(BuffwatchConfig.ShowAllForPlayer);
--    Buffwatch_Options_ShowDebuffs:SetChecked(BuffwatchConfig.ShowDebuffs);
--    Buffwatch_Options_ShowOnlyDispellDebuffs:SetChecked(BuffwatchConfig.ShowDispellableDebuffs);
--    Buffwatch_Options_ShowExpiredWarning:SetChecked(BuffwatchConfig.ExpiredWarning);
--    Buffwatch_Options_PlayExpiredSound:SetChecked(BuffwatchConfig.ExpiredSound);
    Buffwatch_Options_Alpha:SetValue(BuffwatchConfig.Alpha);
end

function Buffwatch_Options_SortOrder_OnClick(self)
    i = self:GetID();
    UIDropDownMenu_SetSelectedID(Buffwatch_Options_SortOrder, i);
    BuffwatchConfig.SortOrder = BW_SORTORDER_DROPDOWN_LIST[i];
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
    UIDropDownMenu_SetText(self, BuffwatchConfig.SortOrder);
    UIDropDownMenu_SetWidth(self, 90);
end

function Buffwatch_EnableCheckbox(checkbox)
    checkbox:Enable();
    getglobal(checkbox:GetName().."Text"):SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
end

function Buffwatch_DisableCheckbox(checkbox)
    checkbox:Disable();
    getglobal(checkbox:GetName().."Text"):SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
end