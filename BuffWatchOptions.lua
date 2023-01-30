function BuffWatchOptionsFrame_OnLoad()

    -- Add BuffWatchOptionsFrame to the UIPanelWindows list
    UIPanelWindows["BuffWatchOptionsFrame"] = {area = "center", pushable = 0}

end

function BuffWatchOptions_Init()
    BuffWatchShowOnStartup:SetChecked(BuffWatchConfig.show_on_startup)
    BuffWatchShowPets:SetChecked(BuffWatchConfig.ShowPets)
    BuffWatchAlpha:SetValue(BuffWatchConfig.alpha)
end