--[[ 
  @file       comergy.lua
  @brief      wow add-on for a customizable, movable power bar

  @author     @project-author@
  @date       @file-date-iso@
]]--
ComergyBarTextures = {
    { "Patt",  "Interface\\AddOns\\Comergy_Redux\\textures\\Patt"  },
    { "Flat",  "Interface\\AddOns\\Comergy_Redux\\textures\\Flat"  },
    { "Smth",  "Interface\\AddOns\\Comergy_Redux\\textures\\Smth"  },
    { "Alum",  "Interface\\AddOns\\Comergy_Redux\\textures\\Alum"  },
    { "3D",    "Interface\\AddOns\\Comergy_Redux\\textures\\3d"    },
    { "Pat2",  "Interface\\AddOns\\Comergy_Redux\\textures\\Pat2"  },
    { "Amry",  "Interface\\AddOns\\Comergy_Redux\\textures\\Amry"  },
    { "Flat2", "Interface\\AddOns\\Comergy_Redux\\textures\\Flat2" },
    { "Mini",  "Interface\\AddOns\\Comergy_Redux\\textures\\Mini"  },
    { "Otra",  "Interface\\AddOns\\Comergy_Redux\\textures\\Otra"  },
    { "Blank", nil },
}

ComergyTextFonts = {
    { "Chat",   "ChatFontNormal"   },
    { "Combat", "NumberFontNormal" },
    { "System", "GameFontNormal"   },
}

Comergy_Settings = { }

local _

local PERIODIC_UPDATE_INTERVAL = 0.1

local FLASH_HIGH        = 0.8
local FLASH_VALUES      = { FLASH_HIGH }
local FLASH_DURATION    = 0.3
local FLASH_TIMES       = 2
local ONE_VALUES        = { 1 }
local ZERO_VALUES       = { 0 }

local BAR_SMALL_INC_DURATION = 0.1
local INSTANT_DURATION       = 0.01

local DURATIONS = {
    CHI_SHOW        = { 0.1, 0.1 },
    CHI_HIDE        = { 0.2, 0.2 },
    MAINFRAME_SHOW  = { 0.1, 0.1 },
    MAINFRAME_HIDE  = { 0.2, 0.2 },
    BAR_CHANGE      = { 0.1, 0.1 },
}

-- class constants
local DEATHKNIGHT   = 1
local DRUID         = 2
local HUNTER        = 3
local MAGE          = 4
local MONK          = 5
local PALADIN       = 6
local PRIEST        = 7
local ROGUE         = 8
local SHAMAN        = 9
local WARLOCK       = 10
local WARRIOR       = 11

local ENERGY_SUBBAR_NUM = 5

-- local SPELL_POWER_COMBO = 4

-- spell ids
local SPELL_ID_PROWL = 5215
local SPELL_NAME_PROWL
local SPELL_ID_SHADOW_DANCE = 51713
local SPELL_NAME_SHADOW_DANCE
local SPELL_ID_VENDETTA = 79140
local SPELL_NAME_VENDETTA
local SPELL_ID_ADRENALINE_RUSH = 13750
local SPELL_NAME_ADRENALINE_RUSH

local status = {
    initialized,
    enabled,
    curUnit,

    energyEnabled,
    manaEnabled,
    comboEnabled,
    chiEnabled,
    furyEnabled,

    curPowerType,
    curChiType,
    curEnergyHeight,
    curChiHeight,
    chiSymbol = "C",

    playerGUID,

    playerClass,
    playerInCombat,
    playerInStealth,
    shapeshiftForm,

    maxEnergy,
    curEnergy,
    energyFlashing,
    energyBGFlashing,

    maxMana,
    curMana,
    manaFlashing,
    manaBGFlashing,

    maxFury,
    curFury,
    furyFlashing   = 0,
    furyBGFlashing = 0,

    curChi,
    chiFlashing,
    runeFlashing = { 0, 0, 0, 0, 0, 0 },

    maxPlayerHealth,
    curPlayerHealth,

    maxTargetHealth,
    curTargetHealth,

    talent,
}

-- Local loop varient
local i, j, v, w

--bar groups
local energyBars = {}
local numEnergyBars
local chiBars = {}
local numChiBars
local furyBars = {}
local numFuryBars
local playerBar, targetBar

local orderedEnergyThresholds = {}
local orderedManaThresholds = {}
local orderedFuryThresholds = {}
local lastPeriodicUpdate

-- private methods
local MainFrameShow, MainFrameToggle, ResizeEnergyBars, ResizeChiBars, ResizeFuryBars
local EnergyChanged, ManaChanged, FrameResize, ChiChanged, RuneChanged, Initialize, ReadStatus, PopulateDefaultSettings, PopulateSettingsFrom
local EventHandlers, TextChanged, TextStyleChanged, BGResize, OnPeriodicUpdate, OnFrameUpdate, OrderThresholds, ChiStatus, FuryChanged
local ToggleOptions, PlayerHealthChanged, TargetHealthChanged, PowerTypeChanged, SetMaxChi, ColorRune, ConvertRune

function MainFrameShow(show)
    if (show) then
        cmg_GradientObject(ComergyMainFrame, 1, DURATIONS["MAINFRAME_SHOW"][1], 1)
        ComergyMainFrame:Show()

        -- Hack to make sure that the energy is drawn to full
        ManaChanged()
        EnergyChanged()
        PlayerHealthChanged()
        TargetHealthChanged()

    else
        cmg_GradientObject(ComergyMainFrame, 1, DURATIONS["MAINFRAME_HIDE"][1], 0)
    end
end

function MainFrameToggle()
    local show = false
    if (Comergy_Settings.Enabled) then
        if ((status.curChi ~= 0) and (status.chiEnabled)) or (status.playerInCombat) then
            show = true
        else
            if (not Comergy_Settings.ShowOnlyInCombat) then
                show = true
            else
                if (Comergy_Settings.ShowWhenEnergyNotFull) then
                    if ((status.curPlayerHealth < status.maxPlayerHealth) and (Comergy_Settings.ShowPlayerHealthBar)) then
                        show = true
                    elseif ((status.curEnergy < status.maxEnergy) and ((status.curPowerType == "ENERGY") or (status.curPowerType == "FOCUS"))) then
                        show = true
                    elseif ((status.curEnergy > 0) and ((status.curPowerType == "RAGE") or (status.curPowerType == "RUNIC_POWER"))) then
                        show = true
                    else
                        show = false
                    end
                end
                if ((Comergy_Settings.ShowInStealth) and (status.playerInStealth)) then
                    show = true
                end
            end
        end
    end
    MainFrameShow(show)
end

--[[    Energy Bars. handle: energy, focus, rage, runic power, mana   ]]--
function ResizeEnergyBars()
    local n = 1
    energyBars[1].min = 0
    energyBars[1].minColor = Comergy_Settings.EnergyColor0

    if (status.energyEnabled) then
        for i = 1, #(orderedEnergyThresholds) do
            if ((orderedEnergyThresholds[i][1] > 0) and (Comergy_Settings["SplitEnergy"..orderedEnergyThresholds[i][2]])) then
                n = n + 1
                energyBars[n - 1].max = orderedEnergyThresholds[i][1] <= status.maxEnergy and orderedEnergyThresholds[i][1] or status.maxEnergy
                energyBars[n].min = orderedEnergyThresholds[i][1]
                energyBars[n - 1].maxColor = Comergy_Settings["EnergyColor"..orderedEnergyThresholds[i][2]]
                energyBars[n].minColor = Comergy_Settings["EnergyColor"..orderedEnergyThresholds[i][2]]
            end
        end
    elseif (status.manaEnabled) then
        for i = 1, #(orderedManaThresholds) do
            if ((orderedManaThresholds[i][1] > 0) and (Comergy_Settings["SplitMana"..orderedManaThresholds[i][2]])) then
                n = n + 1
                energyBars[n - 1].max = orderedManaThresholds[i][1]
                energyBars[n].min = orderedManaThresholds[i][1]
                energyBars[n - 1].maxColor = Comergy_Settings["ManaColor"..orderedManaThresholds[i][2]]
                energyBars[n].minColor = Comergy_Settings["ManaColor"..orderedManaThresholds[i][2]]
            end
        end
    end

    energyBars[n].max = status.maxEnergy
    if (status.energyEnabled) then
        energyBars[n].maxColor = Comergy_Settings["EnergyColor"..ENERGY_SUBBAR_NUM]
    elseif (status.manaEnabled) then
        energyBars[n].maxColor = Comergy_Settings["ManaColor"..ENERGY_SUBBAR_NUM]
    end

    numEnergyBars = n

    local lenPerEnergy = (Comergy_Settings.Width - Comergy_Settings.Spacing * (n - 1)) / status.maxEnergy
    local anchorPointV = "TOP"
    local relAnchorPointV = "BOTTOM"
    local anchorPointH = "RIGHT"
    local relAnchorPointH = "LEFT"
    local direction

    if (Comergy_Settings.FlipBars) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        else
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        end
    end
    if (Comergy_Settings.FlipOrientation) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV               
        else
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        end
        direction = 2
    else
        direction = 1
    end

    if (Comergy_Settings.VerticalBars) then
        direction = direction + 2
    end

    local left, right, top, bottom
    for i = 1, n do
        left = energyBars[i].min * lenPerEnergy + (i - 1) * Comergy_Settings.Spacing
        right = energyBars[i].max * lenPerEnergy + (i - 1) * Comergy_Settings.Spacing
        top = status.curEnergyHeight
        bottom = 0
        if (Comergy_Settings.ShowPlayerHealthBar) then
            bottom = Comergy_Settings.PlayerHeight + Comergy_Settings.Spacing
            top = top + bottom
        end
        energyBars[i].len = right - left

        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        energyBars[i].direction = direction
        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
            energyBars[i]:SetStatusBarTexture(ComergyBarTextures[Comergy_Settings.BarTexture][2])
        else
            energyBars[i]:SetStatusBarTexture(energyBars[i]:CreateTexture(nil, "ARTWORK"))
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            energyBars[i]:GetStatusBarTexture():ClearAllPoints()
            energyBars[i]:GetStatusBarTexture():SetPoint(relAnchorPointV, 0, 0)
            if (status.manaEnabled) then
                energyBars[i]:GetStatusBarTexture():SetWidth(Comergy_Settings.ManaHeight)
            else
                energyBars[i]:GetStatusBarTexture():SetWidth(Comergy_Settings.EnergyHeight)
            end
        else
            energyBars[i]:GetStatusBarTexture():ClearAllPoints()
            energyBars[i]:GetStatusBarTexture():SetPoint(relAnchorPointH, 0, 0)
            if (status.manaEnabled) then
                energyBars[i]:GetStatusBarTexture():SetHeight(Comergy_Settings.ManaHeight)
            else
                energyBars[i]:GetStatusBarTexture():SetHeight(Comergy_Settings.EnergyHeight)
            end
        end

        energyBars[i]:ClearAllPoints()
        energyBars[i]:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        energyBars[i]:SetPoint(anchorPointV .. anchorPointH, energyBars[i]:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)

        if ((top - bottom == 0) or (right - left == 0)) then
            energyBars[i]:Hide()
        else
            energyBars[i]:Show()
        end
    end

    for i = n + 1, ENERGY_SUBBAR_NUM do
        energyBars[i]:Hide()
    end

    if (Comergy_Settings.ShowPlayerHealthBar) then
        left = 0
        right = Comergy_Settings.Width
        top = Comergy_Settings.PlayerHeight
        bottom = 0
        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            playerBar:SetOrientation("VERTICAL")
        else
            playerBar:SetOrientation("HORIZONTAL")
        end

        playerBar:ClearAllPoints()
        playerBar:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        playerBar:SetPoint(anchorPointV .. anchorPointH, ComergyPlayerHealthBar:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
    end
end

function EnergyChanged(isSmallInc)
    if (not status.energyEnabled) then
        return
    end
    isSmallInc = isSmallInc or false

    local changeDuration = DURATIONS["BAR_CHANGE"][1]
    if (isSmallInc) then
        changeDuration = BAR_SMALL_INC_DURATION
    end

    for i = 1, numEnergyBars do
        if (energyBars[i].min > status.curEnergy) then
            cmg_GradientObject(energyBars[i], 1, INSTANT_DURATION, 0)
            if (not Comergy_Settings.UnifiedEnergyColor) then
                for j = 1, 3 do
                    cmg_GradientObject(energyBars[i], j + 1, INSTANT_DURATION, energyBars[i].minColor[j])
                end
            end
        elseif (energyBars[i].max < status.curEnergy) then
            cmg_GradientObject(energyBars[i], 1, INSTANT_DURATION, energyBars[i].max - energyBars[i].min)
            if (not Comergy_Settings.UnifiedEnergyColor) then
                for j = 1, 3 do
                    cmg_GradientObject(energyBars[i], j + 1, INSTANT_DURATION, energyBars[i].maxColor[j])
                end
            end
        else
            cmg_GradientObject(energyBars[i], 1, changeDuration, status.curEnergy - energyBars[i].min)
            for j = 1, 3 do
                local color
                if (Comergy_Settings.GradientEnergyColor) then
                    color = energyBars[i].minColor[j] + (energyBars[i].maxColor[j] - energyBars[i].minColor[j]) / (energyBars[i].max - energyBars[i].min) * (status.curEnergy - energyBars[i].min)
                else
                    color = energyBars[i].maxColor[j]
                end
                if (Comergy_Settings.UnifiedEnergyColor) then
                    local k
                    for k = 1, numEnergyBars do
                        cmg_GradientObject(energyBars[k], j + 1, changeDuration, color)
                    end
                else
                    cmg_GradientObject(energyBars[i], j + 1, changeDuration, color)
                end
            end
        end
    end

    TextChanged()
end

-- needs to be merged with EnergyChanged()
function ManaChanged(isSmallInc)
    if (not status.manaEnabled) then
        return
    end
    isSmallInc = isSmallInc or false

    local changeDuration = DURATIONS["BAR_CHANGE"][1]
    if (isSmallInc) then
        changeDuration = BAR_SMALL_INC_DURATION
    end

    for i = 1, numEnergyBars do
        if (energyBars[i].min > status.curMana) then
            cmg_GradientObject(energyBars[i], 1, INSTANT_DURATION, 0)
            if (not Comergy_Settings.UnifiedManaColor) then
                for j = 1, 3 do
                    cmg_GradientObject(energyBars[i], j + 1, INSTANT_DURATION, energyBars[i].minColor[j])
                end
            end
        elseif (energyBars[i].max < status.curMana) then
            cmg_GradientObject(energyBars[i], 1, INSTANT_DURATION, energyBars[i].max - energyBars[i].min)
            if (not Comergy_Settings.UnifiedManaColor) then
                for j = 1, 3 do
                    cmg_GradientObject(energyBars[i], j + 1, INSTANT_DURATION, energyBars[i].maxColor[j])
                end
            end
        else
            cmg_GradientObject(energyBars[i], 1, changeDuration, status.curMana - energyBars[i].min)
            for j = 1, 3 do
                local color
                if (Comergy_Settings.GradientManaColor) then
                    color = energyBars[i].minColor[j] + (energyBars[i].maxColor[j] - energyBars[i].minColor[j]) / (energyBars[i].max - energyBars[i].min) * (status.curMana - energyBars[i].min)
                else
                    color = energyBars[i].maxColor[j]
                end
                if (Comergy_Settings.UnifiedManaColor) then
                    local k
                    for k = 1, numEnergyBars do
                        cmg_GradientObject(energyBars[k], j + 1, changeDuration, color)
                    end
                else
                    cmg_GradientObject(energyBars[i], j + 1, changeDuration, color)
                end
            end
        end
    end

    TextChanged()
end

--[[    ChiBars. handles chi, combo, holypower, shadow orbs, burning embers, soul shards    ]]--
function ResizeChiBars()
    if (not (status.chiEnabled or status.comboEnabled or status.runeEnabled)) then
        for i = 1, 8 do
            chiBars[i]:Hide()
        end
    end
    for i = 1, 8 do
        chiBars[i]:Show()
    end

    SetMaxChi()
    -- print("Max Chi:", numChiBars)
    local chiLength = (Comergy_Settings.Width - (numChiBars - 1) * Comergy_Settings.Spacing) / numChiBars

    local anchorPointV = "BOTTOM"
    local relAnchorPointV = "TOP"
    local anchorPointH = "RIGHT"
    local relAnchorPointH = "LEFT"

    if (Comergy_Settings.FlipBars) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        else
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        end
    end
    if (Comergy_Settings.FlipOrientation) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        else
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        end
    end
    if (Comergy_Settings.VerticalBars) then
        anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
    end

    local left, right, top, bottom
    local lastLeft = 0
    for i = 1, 8 do
        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
            chiBars[i]:SetStatusBarTexture(ComergyBarTextures[Comergy_Settings.BarTexture][2])
        else
            chiBars[i]:SetStatusBarTexture(chiBars[i].blankTexture)
        end

        left = lastLeft

        -- Fix for fancy bars to work with different chi amounts
        right = left + chiLength + (i - (numChiBars / 2 + .5)) * chiLength * Comergy_Settings.ChiDiff
        lastLeft = right + Comergy_Settings.Spacing
        
        -- Fix for changing chi amounts in the same session
        if (i > numChiBars) then
            top = 0
        else
            top = -status.curChiHeight
        end


        bottom = 0
        if (Comergy_Settings.ShowTargetHealthBar) then
            bottom = bottom - Comergy_Settings.TargetHeight - Comergy_Settings.Spacing
            top = top + bottom
        end

        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            chiBars[i]:GetStatusBarTexture():SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        else
            chiBars[i]:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
        end

        chiBars[i]:ClearAllPoints()
        chiBars[i]:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        chiBars[i]:SetPoint(anchorPointV .. anchorPointH, chiBars[i]:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
    end

    left = 0
    right = Comergy_Settings.Width
    top = -Comergy_Settings.TargetHeight
    bottom = 0
    if (Comergy_Settings.FlipBars) then
        top, bottom = -top, -bottom
    end
    if (Comergy_Settings.FlipOrientation) then
        left, right = -left, -right
    end

    -- split into separate function
    if (Comergy_Settings.VerticalBars) then
        left, bottom = bottom, left
        right, top = top, right
        targetBar:SetOrientation("VERTICAL")
    else
        targetBar:SetOrientation("HORIZONTAL")
    end

    targetBar:ClearAllPoints()
    targetBar:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
    targetBar:SetPoint(anchorPointV .. anchorPointH, ComergyTargetHealthBar:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
end

function ChiChanged()
    -- print('Chi!')
    local chi
    if (status.chiEnabled) then
        chi = UnitPower(status.curUnit, status.curChiType)
    elseif (status.comboEnabled) then
        chi = UnitPower(status.curUnit, SPELL_POWER_COMBO_POINTS)
    else
        return
    end

    if ((Comergy_Settings.ChiFlash) and (chi == numChiBars)) then
        if (status.chiFlashing == 0) then
            status.chiFlashing = FLASH_TIMES
            for i = 1, #(chiBars) do
                cmg_ResetObject(chiBars[i], FLASH_VALUES)
                chiBars[i]:SetAlpha(FLASH_HIGH)
                cmg_GradientObject(chiBars[i], 1, FLASH_DURATION, Comergy_Settings.ChiBGAlpha)
                if ((Comergy_Settings.UnifiedChiColor) or (i == 5)) then
                    local color = Comergy_Settings["ChiColor5"]
                    for j = 1, 3 do
                        cmg_GradientObject(chiBars[i], j + 1, DURATIONS["CHI_SHOW"][1], color[j])
                    end
                end
            end
        end
    else
        status.chiFlashing = 0

        for i = 1, chi do
            cmg_GradientObject(chiBars[i], 1, DURATIONS["CHI_SHOW"][1], 1)
            if (Comergy_Settings.UnifiedChiColor) then
                local color = Comergy_Settings["ChiColor"..chi]
                for j = 1, 3 do
                    cmg_GradientObject(chiBars[i], j + 1, DURATIONS["CHI_SHOW"][1], color[j])
                end
            end
        end

        for i = chi + 1, 8 do
            cmg_GradientObject(chiBars[i], 1, DURATIONS["CHI_HIDE"][1], Comergy_Settings.ChiBGAlpha)
            if (Comergy_Settings.UnifiedChiColor) then
                for j = 1, 3 do
                    cmg_GradientObject(chiBars[i], j + 1, DURATIONS["CHI_HIDE"][1], Comergy_Settings.ChiColor0[j])
                end
            end
        end
    end
    
    if ((chi ~= status.curChi) and (chi ~= 0)) then
        if (Comergy_Settings["SoundChi"..chi]) then
            PlaySoundFile("Interface\\AddOns\\Comergy_Redux\\sound\\combo"..chi..".ogg")
        end
    end

    status.curChi = chi
    TextChanged()
    MainFrameToggle()
end

-- runes are special
function RuneChanged()
    if(not status.runeEnabled) then
        return
    end

    for i = 1, 6 do
        j = ConvertRune(i)
        local runeStart, runeDuration, isReady = GetRuneCooldown(j)
        if (isReady) then
            cmg_GradientObject(chiBars[i], 1, DURATIONS["CHI_SHOW"][1], 1)
            chiBars[i]:SetValue(0)
            if (Comergy_Settings.RuneFlash) then
                if (status.runeFlashing[i] == -1) then
                    status.runeFlashing[i] = FLASH_TIMES
                    cmg_ResetObject(chiBars[i], FLASH_VALUES)
                    chiBars[i]:SetAlpha(FLASH_HIGH)
                    cmg_GradientObject(chiBars[i], 1, FLASH_DURATION, Comergy_Settings.RuneBGAlpha)
                end
            end
        else
            cmg_GradientObject(chiBars[i], 1, DURATIONS["CHI_HIDE"][1], Comergy_Settings.RuneBGAlpha)
            local value = (runeDuration - (GetTime() - runeStart)) * -1
            if (value >= -10 and value <= 0) then
                chiBars[i]:SetValue(value)
            elseif (value < -10) then
                chiBars[i]:SetValue(-10)
            end
            status.runeFlashing[i] = -1
        end
    end

    TextChanged()
    MainFrameToggle()
end

function ResizeFuryBars()
    local n = 1
    furyBars[1].min = 0
    furyBars[1].minColor = Comergy_Settings.FuryColor0

    for i = 1, #(orderedFuryThresholds) do
        if ((orderedFuryThresholds[i][1] > 0) and (Comergy_Settings["SplitFury"..orderedFuryThresholds[i][2]])) then
            n = n + 1
            furyBars[n - 1].max = orderedFuryThresholds[i][1]
            furyBars[n].min = orderedFuryThresholds[i][1]
            furyBars[n - 1].maxColor = Comergy_Settings["FuryColor"..orderedFuryThresholds[i][2]]
            furyBars[n].minColor = Comergy_Settings["FuryColor"..orderedFuryThresholds[i][2]]
        end
    end

    furyBars[n].max = status.maxFury
    furyBars[n].maxColor = Comergy_Settings["FuryColor"..ENERGY_SUBBAR_NUM]

    numFuryBars = n

    local lenPerFury = (Comergy_Settings.Width - Comergy_Settings.Spacing * (n - 1)) / status.maxFury
    local anchorPointV = "BOTTOM"
    local relAnchorPointV = "TOP"
    local anchorPointH = "RIGHT"
    local relAnchorPointH = "LEFT"
    local direction

    if (Comergy_Settings.FlipBars) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        else
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        end
    end
    if (Comergy_Settings.FlipOrientation) then
        if (Comergy_Settings.VerticalBars) then
            anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV               
        else
            anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        end
        direction = 2
    else
        direction = 1
    end

    if (Comergy_Settings.VerticalBars) then
        anchorPointV, relAnchorPointV = relAnchorPointV, anchorPointV
        anchorPointH, relAnchorPointH = relAnchorPointH, anchorPointH
        direction = direction + 2
    end

    local left, right, top, bottom
    for i = 1, n do
        left = furyBars[i].min * lenPerFury + (i - 1) * Comergy_Settings.Spacing
        right = furyBars[i].max * lenPerFury + (i - 1) * Comergy_Settings.Spacing
        top = -status.curFuryHeight
        bottom = 0

        if (Comergy_Settings.ShowTargetHealthBar) then
            bottom = bottom - Comergy_Settings.TargetHeight - Comergy_Settings.Spacing
            top = top + bottom
        end

        furyBars[i].len = right - left

        if (Comergy_Settings.FlipBars) then
            top, bottom = -top, -bottom
        end
        if (Comergy_Settings.FlipOrientation) then
            left, right = -left, -right
        end

        furyBars[i].direction = direction
        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
            furyBars[i]:SetStatusBarTexture(ComergyBarTextures[Comergy_Settings.BarTexture][2])
        else
            furyBars[i]:SetStatusBarTexture(furyBars[i]:CreateTexture(nil, "ARTWORK"))
        end

        if (Comergy_Settings.VerticalBars) then
            left, bottom = bottom, left
            right, top = top, right
            furyBars[i]:GetStatusBarTexture():ClearAllPoints()
            furyBars[i]:GetStatusBarTexture():SetPoint(relAnchorPointV, 0, 0)
            furyBars[i]:GetStatusBarTexture():SetWidth(Comergy_Settings.FuryHeight)
        else
            furyBars[i]:GetStatusBarTexture():ClearAllPoints()
            furyBars[i]:GetStatusBarTexture():SetPoint(relAnchorPointH, 0, 0)
            furyBars[i]:GetStatusBarTexture():SetHeight(Comergy_Settings.FuryHeight)
        end

        furyBars[i]:ClearAllPoints()
        furyBars[i]:SetPoint(relAnchorPointV .. relAnchorPointH, left, bottom)
        furyBars[i]:SetPoint(anchorPointV .. anchorPointH, furyBars[i]:GetParent(), relAnchorPointV .. relAnchorPointH, right, top)
        if ((top - bottom == 0) or (right - left == 0)) then
            furyBars[i]:Hide()
        else
            furyBars[i]:Show()
        end
    end

    for i = n + 1, ENERGY_SUBBAR_NUM do
        furyBars[i]:Hide()
    end
end

function FuryChanged(isSmallInc)
    if (not status.furyEnabled) then
        return
    end
    isSmallInc = isSmallInc or false

    local changeDuration = DURATIONS["BAR_CHANGE"][1]
    if (isSmallInc) then
        changeDuration = BAR_SMALL_INC_DURATION
    end

    for i = 1, numFuryBars do
        if (furyBars[i].min > status.curFury) then
            cmg_GradientObject(furyBars[i], 1, INSTANT_DURATION, 0)
            if (not Comergy_Settings.UnifiedFuryColor) then
                for j = 1, 3 do
                    cmg_GradientObject(furyBars[i], j + 1, INSTANT_DURATION, furyBars[i].minColor[j])
                end
            end
        elseif (furyBars[i].max < status.curFury) then
            cmg_GradientObject(furyBars[i], 1, INSTANT_DURATION, furyBars[i].max - furyBars[i].min)
            if (not Comergy_Settings.UnifiedFuryColor) then
                for j = 1, 3 do
                    cmg_GradientObject(furyBars[i], j + 1, INSTANT_DURATION, furyBars[i].maxColor[j])
                end
            end
        else
            cmg_GradientObject(furyBars[i], 1, changeDuration, status.curFury - furyBars[i].min)
            for j = 1, 3 do
                local color
                if (Comergy_Settings.GradientFuryColor) then
                    color = furyBars[i].minColor[j] + (furyBars[i].maxColor[j] - furyBars[i].minColor[j]) / (furyBars[i].max - furyBars[i].min) * (status.curFury - furyBars[i].min)
                else
                    color = furyBars[i].maxColor[j]
                end
                if (Comergy_Settings.UnifiedFuryColor) then
                    local k
                    for k = 1, numFuryBars do
                        cmg_GradientObject(furyBars[k], j + 1, changeDuration, color)
                    end
                else
                    cmg_GradientObject(furyBars[i], j + 1, changeDuration, color)
                end
            end
        end
    end

    TextChanged()
end

function PlayerHealthChanged()
    local healthPerc = status.curPlayerHealth / status.maxPlayerHealth
    cmg_GradientObject(playerBar, 1, DURATIONS["BAR_CHANGE"][1], healthPerc)
    for i = 1, 3 do
        cmg_GradientObject(playerBar, i + 1, DURATIONS["BAR_CHANGE"][1], playerBar.minColor[i] + healthPerc * (playerBar.maxColor[i] - playerBar.minColor[i]))
    end
end

function TargetHealthChanged()
    local targetName = UnitName("target")
    if (targetName and Comergy_Settings.ShowTargetHealthBar) then
        targetBar:Show()
        cmg_GradientObject(targetBar, 1, DURATIONS["BAR_CHANGE"][1], status.curTargetHealth / status.maxTargetHealth)
    else
        targetBar:Hide()
        cmg_GradientObject(targetBar, 1, DURATIONS["BAR_CHANGE"][1], 0)
    end
end


function FrameResize()
    local w = Comergy_Settings.Width
    local h = status.curChiHeight + status.curEnergyHeight + status.curFuryHeight
    local space = 0

    if (status.curChiHeight ~= 0) then
        space = space + 1
    end
    if (status.curEnergyHeight ~= 0) then
        space = space + 1
    end
    if (status.curFuryHeight ~= 0) then
        space = space + 1
    end
    if (Comergy_Settings.ShowPlayerHealthBar) then
        space = space + 1
        h = h + Comergy_Settings.PlayerHeight
    end
    if (Comergy_Settings.ShowTargetHealthBar) then
        space = space + 1
        h = h + Comergy_Settings.TargetHeight
    end
    if (space == 0) then
        h = Comergy_Settings.TextHeight
    else
        h = h + (space - 1) * Comergy_Settings.Spacing
    end
    if (Comergy_Settings.VerticalBars) then
        w, h = h, w
    end
    ComergyMainFrame:SetWidth(w)
    ComergyMainFrame:SetHeight(h)

    BGResize()

    ResizeEnergyBars()
    ResizeFuryBars()
    ResizeChiBars()

    ComergyEnergyText:ClearAllPoints()
    ComergyChiText:ClearAllPoints()
    if (Comergy_Settings.VerticalBars) then
        ComergyEnergyText:SetPoint("BOTTOM", ComergyMainFrame, "TOP", 0, 3)
        ComergyChiText:SetPoint("TOP", ComergyMainFrame, "BOTTOM", 0, -3)
    else
        ComergyEnergyText:SetPoint("RIGHT", ComergyMainFrame, "LEFT", -3, 0)
        ComergyChiText:SetPoint("LEFT", ComergyMainFrame, "RIGHT", 3, 0)
    end
end

function BGResize()
    ComergyMovingFrame:ClearAllPoints()

    local left, bottom = -Comergy_Settings.Spacing, -Comergy_Settings.Spacing
    local right, top = Comergy_Settings.Spacing, Comergy_Settings.Spacing

    if (not Comergy_Settings.TextCenter) then
        if (Comergy_Settings.VerticalBars) then
            local diff = (ComergyEnergyText:GetWidth() - ComergyMainFrame:GetWidth()) / 2
            diff = (diff > 0) and diff or 0
            if (Comergy_Settings.EnergyText) then
                top = Comergy_Settings.Spacing + ComergyEnergyText:GetHeight()
                left = left - diff
                right = right + diff
                diff = 0
            end
            if ((Comergy_Settings.ChiText) and ((status.comboEnabled) or (status.chiEnabled))) then
                bottom = -(Comergy_Settings.Spacing + ComergyEnergyText:GetHeight())
                left = left - diff
                right = right + diff
            end
        else
            local diff = (ComergyEnergyText:GetHeight() - ComergyMainFrame:GetHeight()) / 2
            diff = (diff > 0) and diff or 0
            if (Comergy_Settings.EnergyText) then
                left = -(Comergy_Settings.Spacing + ComergyEnergyText:GetWidth())
                top = top + diff
                bottom = bottom - diff
                diff = 0
            end
            if (((Comergy_Settings.ChiText) and (status.comboEnabled)) or ((Comergy_Settings.ChiText) and (status.chiEnabled))) then
                right = Comergy_Settings.Spacing + ComergyEnergyText:GetWidth()
                top = top + diff
                bottom = bottom - diff
            end
        end
    end

    ComergyMovingFrame:SetPoint("TOPLEFT", ComergyMainFrame, "TOPLEFT", left, top)
    ComergyMovingFrame:SetPoint("BOTTOMRIGHT", ComergyMainFrame, "BOTTOMRIGHT", right, bottom)

end

-- needs some clean-up
function TextChanged()
    local combinedText = ""
    if (Comergy_Settings.TextCenter) then
        local text
        if ((Comergy_Settings.EnergyText) and (status.energyEnabled)) then
            text = combinedText .. status.curEnergy
            combinedText = text
            if ((Comergy_Settings.ChiText) and ((status.comboEnabled) or (status.chiEnabled))) then
                if (Comergy_Settings.VerticalBars) then
                    text = combinedText .. "\n"
                else
                    text = combinedText .. " / "
                end
                combinedText = text
            end
        elseif ((Comergy_Settings.ManaText) and (status.manaEnabled)) then
            local mana
            if (Comergy_Settings.ManaShortText) then
                mana = math.floor(status.curMana / 1000) .. "k"
            else
                mana = status.curMana
            end
            text = combinedText .. mana
            combinedText = text
            if ((Comergy_Settings.ChiText) and ((status.comboEnabled) or (status.chiEnabled))) or 
                ((status.runeEnabled and Comergy_Settings.RuneText)) or (status.furyEnabled and Comergy_Settings.FuryText) then
                if (Comergy_Settings.VerticalBars) then
                    text = combinedText .. "\n"
                else
                    text = combinedText .. " / "
                end
                combinedText = text
            end
        end
        if ((Comergy_Settings.ChiText) and ((status.chiEnabled) or (status.comboEnabled))) then
            text = combinedText .. status.curChi
            combinedText = text .. " " .. status.chiSymbol
        elseif (Comergy_Settings.FuryText and status.furyEnabled) then
            text = combinedText .. status.curFury
            combinedText = text .. " " .. status.chiSymbol
        elseif ((Comergy_Settings.RuneText) and (status.runeEnabled)) then
            local runeReady = {false, false, false, false}
            for i = 1, 6 do
                local _, _, isReady = GetRuneCooldown(i)
                if (isReady) then
                    local runeType = GetRuneType(i)
                    runeReady[runeType] = true
                end
            end
            for i = 1, 4 do
                text = combinedText
                if (runeReady[i]) then
                    combinedText = text .. " " .. COMERGY_RUNE_NAME[i]
                end
            end
        end
        ComergyText:SetText(combinedText)

    else
        if (Comergy_Settings.EnergyText) then
            ComergyEnergyText:SetText(status.curEnergy)
        elseif (Comergy_Settings.ManaText) then
            ComergyEnergyText:SetText(status.curMana)
        end
        if ((Comergy_Settings.ChiText) and ((status.comboEnabled) or (status.chiEnabled))) then
            combinedText = status.curChi .. " " .. status.chiSymbol
            ComergyChiText:SetText(combinedText)
        end
    end
end

function TextStyleChanged()
    ComergyText:SetFont(getglobal(ComergyTextFonts[Comergy_Settings.TextFont][2]):GetFont(), Comergy_Settings.TextHeight)
    ComergyEnergyText:SetFont(getglobal(ComergyTextFonts[Comergy_Settings.TextFont][2]):GetFont(), Comergy_Settings.TextHeight)
    ComergyChiText:SetFont(getglobal(ComergyTextFonts[Comergy_Settings.TextFont][2]):GetFont(), Comergy_Settings.TextHeight)

    ComergyText:SetTextColor(Comergy_Settings.TextColor[1], Comergy_Settings.TextColor[2], Comergy_Settings.TextColor[3])
    ComergyEnergyText:SetTextColor(Comergy_Settings.TextColor[1], Comergy_Settings.TextColor[2], Comergy_Settings.TextColor[3])
    ComergyChiText:SetTextColor(Comergy_Settings.TextColor[1], Comergy_Settings.TextColor[2], Comergy_Settings.TextColor[3])

    if (Comergy_Settings.TextCenter) then
        ComergyText:Show()
        ComergyEnergyText:Hide()
        ComergyChiText:Hide()
        if (Comergy_Settings.TextCenterUp) then
            ComergyText:ClearAllPoints()
            ComergyText:SetPoint("BOTTOM", ComergyText:GetParent(), "TOP", 0, 0)
        else
            ComergyText:ClearAllPoints()
            ComergyText:SetPoint("CENTER", 0, 0)
        end
    else
        ComergyText:Hide()
        if (Comergy_Settings.EnergyText) then
            ComergyEnergyText:Show()
        else
            ComergyEnergyText:Hide()
        end
        if (Comergy_Settings.ManaText) then
            ComergyEnergyText:Show()
        else
            ComergyEnergyText:Hide()
        end
        if ((Comergy_Settings.ChiText) and (status.comboEnabled)) then
            ComergyChiText:Show()
        else
            ComergyChiText:Hide()
        end
        if ((Comergy_Settings.ChiText) and (status.chiEnabled)) then
            ComergyChiText:Show()
        else
            ComergyChiText:Hide()
        end
    end

    ComergyEnergyText:SetText("100")
    ComergyEnergyText:SetWidth(ComergyEnergyText:GetStringWidth() + 5)
    ComergyChiText:SetText("0 C")
    ComergyChiText:SetWidth(ComergyChiText:GetStringWidth() + 5)
end

function ToggleOptions()
    if(not IsAddOnLoaded("Comergy_Redux_Options")) then
        local loaded, reason = LoadAddOn("Comergy_Redux_Options")
        if (loaded) then
            ComergyOptToggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage(reason)
        end
    else
        ComergyOptToggle()
    end
end

function UpdateOptions()
    if(not IsAddOnLoaded("Comergy_Redux_Options")) then
        local loaded, reason = LoadAddOn("Comergy_Redux_Options")
        if (loaded) then
            ComergyOptReadSettings()
        else
            DEFAULT_CHAT_FRAME:AddMessage(reason)
        end
    else
        ComergyOptReadSettings()
    end
end

--[[    Default settings    ]]--
function PopulateDefaultSettings()
    local defaultSettings = {
        Enabled = true;
        Version = "@project-version@",
        ShowOnlyInCombat = false,
        ShowInStealth = true,
        ShowWhenEnergyNotFull = true,
        Locked = false,
        CritSound = false,
        StealthSound = false,
        Spacing = 4,
        Width = 220,
        ChiHeight = 10,
        RuneHeight = 10,
        EnergyHeight = 10,
        ManaHeight = 10,
        FuryHeight = 10,
        FlipBars = false,
        FlipOrientation = false,
        VerticalBars = false,
        FrameStrata = 2,

        EnergyThreshold1 = 25,
        EnergyThreshold2 = 35,
        EnergyThreshold3 = 40,
        EnergyThreshold4 = 60,

        EnergyColor0 = { 1, 0, 0 },
        EnergyColor1 = { 1, 0, 0 },
        EnergyColor2 = { 1, 0.5, 0 },
        EnergyColor3 = { 1, 1, 0 },
        EnergyColor4 = { 1, 1, 0 },
        EnergyColor5 = { 0, 1, 0 },

        SoundEnergy1 = false,
        SoundEnergy2 = false,
        SoundEnergy3 = false,
        SoundEnergy4 = true,
        SoundEnergy5 = false,

        SplitEnergy1 = false,
        SplitEnergy2 = true,
        SplitEnergy3 = false,
        SplitEnergy4 = true,

        EnergyText = true,
        UnifiedEnergyColor = true,
        GradientEnergyColor = true,

        EnergyBGColorAlpha = { 0.3, 0.3, 1, 0.5 },
        EnergyBGFlash = true,
        EnergyFlash = false,  --rogue cd flash
        EnergyFlashColor = { 1, 0.2, 0.2 },
        Anticipation = true,
        AnticipationCombo = true,
        AnticipationColor = { 0, 1, 1 },

        ManaThreshold1 = 75000,
        ManaThreshold2 = 125000,
        ManaThreshold3 = 175000,
        ManaThreshold4 = 225000,

        ManaColor0 = { 1, 0, 0 },
        ManaColor1 = { 1, 0, 0 },
        ManaColor2 = { 1, 0.5, 0 },
        ManaColor3 = { 1, 1, 0 },
        ManaColor4 = { 1, 1, 0 },
        ManaColor5 = { 0, 1, 0 },

        SoundMana1 = false,
        SoundMana2 = false,
        SoundMana3 = false,
        SoundMana4 = false,
        SoundMana5 = false,
        
        SplitMana1 = false,
        SplitMana2 = false,
        SplitMana3 = false,
        SplitMana4 = false,
        
        ManaText = true,
        ManaShortText = true,
        UnifiedManaColor = true,
        GradientManaColor = true,

        ManaBGColorAlpha = { 0.3, 0.3, 1, 0.5 },
        ManaBGFlash = true,

        FuryThreshold1 = 100,
        FuryThreshold2 = 200,
        FuryThreshold3 = 600,
        FuryThreshold4 = 800,

        FuryColor0 = { 1, 0, 0 },
        FuryColor1 = { 1, 0, 0 },
        FuryColor2 = { 1, 0.5, 0 },
        FuryColor3 = { 1, 1, 0 },
        FuryColor4 = { 1, 1, 0 },
        FuryColor5 = { 0, 1, 0 },

        SoundFury1 = false,
        SoundFury2 = false,
        SoundFury3 = false,
        SoundFury4 = false,
        SoundFury5 = false,
        
        SplitFury1 = false,
        SplitFury2 = true,
        SplitFury3 = true,
        SplitFury4 = false,
        
        FuryText = true,
        FuryShortText = true,
        UnifiedFuryColor = true,
        GradientFuryColor = true,

        FuryBGColorAlpha = { 0.3, 0.3, 1, 0.5 },
        FuryBGFlash = true,

        SoundChi1 = false,
        SoundChi2 = false,
        SoundChi3 = false,
        SoundChi4 = false,
        SoundChi5 = true,
        SoundChi6 = true,
        SoundChi7 = true,
        SoundChi8 = true,

        ChiColor0 = { 0.5, 0.5, 0.5 },
        ChiColor1 = { 1, 0, 0 },
        ChiColor2 = { 1, 0.5, 0 }, 
        ChiColor3 = { 1, 1, 0 },
        ChiColor4 = { 0, 1, 0 },
        ChiColor5 = { 0, 0.5, 1 },
        ChiColor6 = { 0, 1, 1 },
        ChiColor7 = { 0, 1, 1 },
        ChiColor8 = { 0, 1, 1 },

        ChiText = true,
        ChiBGAlpha = 0.1,
        UnifiedChiColor = false,
        ChiFlash = true,
        RuneFlash = true,
        ChiDiff = 0,

        SoundRune1 = false,  --Blood
        SoundRune2 = false,  --Unholy
        SoundRune3 = false,  --Frost
        SoundRune4 = false,  --Death

        RuneColor1 = { 1, 0, 0 },  --Blood
        RuneColor2 = { 0, 1, 0 },  --Unholy
        RuneColor3 = { 0, 0.5, 1 },  --Frost
        RuneColor4 = { 1, 0, 1},  --Death

        RuneText = false,
        RuneBGAlpha = 0.4,
        RuneFlash = true,
        RuneBGColorAlpha = { 0, 0, 0, 1 },

        TextColor = { 1, 1, 1 },
        TextHeight = 14,
        TextFont = 3,
        TextCenter = true,
        TextCenterUp = true,
        BGColorAlpha = { 0, 0, 0, 0.6 },

        BarTexture = 5,
        DurationScale = 0.8,

        X = 0,
        Y = 0,

        ShowPlayerHealthBar = false,
        ShowTargetHealthBar = false,

        PlayerHeight = 1,
        TargetHeight = 1,

    }
    return defaultSettings
end

function PopulateSettingsFrom(curSettings, fromSettings)
    local defaultSettings = PopulateDefaultSettings()

    if (not fromSettings) then
        fromSettings = defaultSettings
    end
    if (not curSettings) then
        curSettings = { }
    end

    for i, v in pairs(fromSettings) do
        if ((curSettings[i] == nil) and (defaultSettings[i] ~= nil)) then
            if (type(v) == "table") then
                curSettings[i] = { }
                for j, w in pairs(v) do
                    curSettings[i][j] = w
                end
            else
                curSettings[i] = v
            end
        end
    end
    -- Complete all the settings from default
    for i, v in pairs(defaultSettings) do
        if (curSettings[i] == nil) then
            if (type(v) == "table") then
                curSettings[i] = { }
                for j, w in pairs(v) do
                    curSettings[i][j] = w
                end
            else
                curSettings[i] = v
            end
        end
    end
    -- Discard deprecated settings
    for i, v in pairs(curSettings) do
        if (defaultSettings[i] == nil) then
            curSettings[i] = nil
        end
    end

    curSettings.Version = defaultSettings.Version
    return curSettings

end

function Initialize()
    lastPeriodicUpdate = 0

    SPELL_NAME_PROWL = GetSpellInfo(SPELL_ID_PROWL)
    SPELL_NAME_SHADOW_DANCE = GetSpellInfo(SPELL_ID_SHADOW_DANCE)
    SPELL_NAME_VENDETTA = GetSpellInfo(SPELL_ID_VENDETTA)
    SPELL_NAME_ADRENALINE_RUSH = GetSpellInfo(SPELL_ID_ADRENALINE_RUSH)

    if (CanExitVehicle() and UnitHasVehicleUI("player")) then
        status.curUnit = "vehicle"
    else
        status.curUnit = "player"
    end

    for i = 1, ENERGY_SUBBAR_NUM do
        energyBars[i] = getglobal("ComergyEnergyBar" .. i)
        local initValues = { 0, 1, 1, 1, 1 }
        cmg_InitObject(energyBars[i], initValues)

        energyBars[i].bg = energyBars[i]:CreateTexture(nil, "BORDER")
        energyBars[i].bg:SetAllPoints(energyBars[i])
        initValues = { 0.3 }
        cmg_InitObject(energyBars[i].bg, initValues)
    end

    for i = 1, ENERGY_SUBBAR_NUM do
        furyBars[i] = getglobal("ComergyFuryBar" .. i)
        local initValues = { 0, 1, 1, 1, 1 }
        cmg_InitObject(furyBars[i], initValues)

        furyBars[i].bg = furyBars[i]:CreateTexture(nil, "BORDER")
        furyBars[i].bg:SetAllPoints(furyBars[i])
        initValues = { 0.3 }
        cmg_InitObject(furyBars[i].bg, initValues)
    end

    for i = 1, 8 do
        chiBars[i] = getglobal("ComergyChiBar"..i)
        chiBars[i]:SetMinMaxValues(0, 1)
        chiBars[i]:SetValue(1)
        chiBars[i]:SetAlpha(0)

        local initValues = { 0, 0, 0, 0 }
        cmg_InitObject(chiBars[i], initValues)

        chiBars[i].blankTexture = chiBars[i]:CreateTexture(nil, "ARTWORK")

        chiBars[i].verticalInit = 0

        if (status.playerClass == DEATHKNIGHT) then
            chiBars[i]:SetMinMaxValues(-10, 0)
            chiBars[i]:SetValue(0)
            chiBars[i]:SetAlpha(1)
            chiBars[i].bg = chiBars[i]:CreateTexture(nil, "BORDER")
            chiBars[i].bg:SetAllPoints(chiBars[i])
            initValues = { 0.3 }
            cmg_InitObject(chiBars[i].bg, initValues)
        end
    end

    playerBar = getglobal("ComergyPlayerHealthBar")
    playerBar:SetMinMaxValues(0, 1)
    playerBar:SetValue(0)
    playerBar:SetStatusBarTexture(playerBar:CreateTexture(nil, "ARTWORK"))
    playerBar.maxColor = { 0, 1, 0 }
    playerBar.minColor = { 1, 0, 0.1 }

    local initValues = { 0, 0, 1, 0 }
    cmg_InitObject(playerBar, initValues)

    targetBar = getglobal("ComergyTargetHealthBar")
    targetBar:SetMinMaxValues(0, 1)
    targetBar:SetValue(1)
    targetBar:SetStatusBarTexture(targetBar:CreateTexture(nil, "ARTWORK"))

    initValues = { 0, 1, 1, 1 }
    cmg_InitObject(targetBar, initValues)

    ComergyMainFrame:SetAlpha(0)
    cmg_InitObject(ComergyMainFrame, ZERO_VALUES)

    SlashCmdList["COMERGY"] = function()
            ToggleOptions()
        end

    --noinspection GlobalCreationOutsideO
    SLASH_COMERGY1 = "/comergy"
    --noinspection GlobalCreationOutsideO
    SLASH_COMERGY2 = "/cmg"

    local f = CreateFrame("Frame")
    f.name = "Comergy Redux"

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Comergy Redux")
    title:SetTextHeight(20)

    local text = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    text:SetPoint("TOPLEFT", 16, -44)
    text:SetPoint("BOTTOMRIGHT", text:GetParent(), "TOPRIGHT", -16, -56)
    text:SetJustifyH("LEFT")
    text:SetTextHeight(12)
    text:SetText(COMERGY_OPTION_FRAME_MESSAGE)

    local button = CreateFrame("Button", nil, f, "OptionsButtonTemplate")
    button:SetPoint("TOPLEFT", 16, -70)
    button:SetText(COMERGY_OPTION_FRAME_BUTTON)
    button:SetHeight(24)
    button:SetWidth(150)
    button:SetScript("OnClick", function()
        InterfaceOptionsFrameCancel_OnClick()
        HideUIPanel(GameMenuFrame)
        ToggleOptions()
    end)

    InterfaceOptions_AddCategory(f)

    ComergyMainFrame:Hide()
end

function PowerTypeChanged()
    local _, powerType = UnitPowerType(status.curUnit)

    if (status.curPowerType ~= powerType) then
        status.energyEnabled = false
        status.manaEnabled = false
        status.comboEnabled = false
        status.chiEnabled = false

        if (powerType == "ENERGY") then
            if (status.playerClass == ROGUE) or (status.playerClass == DRUID) then
                status.comboEnabled = true
                status.chiSymbol = "P"
            end
        end

        if (powerType == "MANA") then
            status.manaEnabled = true
        else
            status.energyEnabled = true
        end

        ChiStatus()

        status.curPowerType = powerType

        if (status.energyEnabled) then
            status.curEnergyHeight = Comergy_Settings.EnergyHeight
        elseif (status.manaEnabled) then
            status.curEnergyHeight = Comergy_Settings.ManaHeight
        else
            status.curEnergyHeight = 0
        end

        if (status.furyEnabled) then
            status.curFuryHeight = Comergy_Settings.FuryHeight
        else
            status.curFuryHeight = 0
        end
    end

    TextStyleChanged()
end

function ChiStatus()
    status.chiEnabled = false
    --status.comboEnabled = false
    status.runeEnabled = false
    status.furyEnabled = false
    if (status.playerClass == MONK or status.playerClass == PRIEST or status.playerClass == PALADIN or status.playerClass == WARLOCK) then
        status.chiEnabled = true
        if (status.playerClass == MONK) then
            status.curChiType = SPELL_POWER_CHI
            status.chiSymbol = "C"
        elseif (status.playerClass == PALADIN) then
            status.curChiType = SPELL_POWER_HOLY_POWER
            status.chiSymbol = "P"
        elseif (status.playerClass == PRIEST) then
            status.curChiType = SPELL_POWER_SHADOW_ORBS
            status.chiSymbol = "O"
            if (not (GetSpecialization() == 3)) then  --not shadow
                status.chiEnabled = false
            end
        elseif (status.playerClass == WARLOCK) then
            if (GetSpecialization() == 1) then  --aff
                status.curChiType = SPELL_POWER_SOUL_SHARDS
                status.chiSymbol = "S"
            elseif (GetSpecialization() == 2) then  --demo
                status.chiEnabled = false
                status.furyEnabled = true
                status.curChiType = SPELL_POWER_DEMONIC_FURY -- up to 1000
                status.chiSymbol = "F"
            elseif (GetSpecialization() == 3) then  --destro
                status.curChiType = SPELL_POWER_BURNING_EMBERS
                status.chiSymbol = "E"
            end
        end
    elseif (status.playerClass == ROGUE) then
        status.comboEnabled = true
        status.chiSymbol = "P"
    --elseif (status.playerClass == DRUID) then
    --    if (status.curPowerType == "ENERGY") then
    --        status.comboEnabled = true
    --    else
    --        status.chiEnabled = false
    --    end
    elseif (status.playerClass == DEATHKNIGHT) then
        status.runeEnabled = true
    end

    if (GetSpecialization() == nil) then  --no specialization / lvl < 10
        if (status.playerClass == MONK) then  --monks always have chi
        elseif (status.playerClass == ROGUE and UnitLevel("player") >= 3) then  --rogues get combo points at lvl 3
        elseif (status.playerClass == PALADIN and UnitLevel("player") >= 9) then  --paladins get holy power at lvl 9
        else
            status.chiEnabled = false
            status.comboEnabled = false
            status.furyEnabled = false
        end
    end

    if (status.curUnit == "vehicle") then
        status.comboEnabled = true
        status.chiEnabled = false
        status.runeEnabled = false
        status.furyEnabled = false
    end

    if (status.chiEnabled or status.comboEnabled) then
        status.curChiHeight = Comergy_Settings.ChiHeight
    elseif (status.runeEnabled) then
        status.curChiHeight = Comergy_Settings.RuneHeight
    else
        status.curChiHeight = 0
    end

    if (status.furyEnabled) then
        status.curFuryHeight = Comergy_Settings.FuryHeight
    else
        status.curFuryHeight = 0
    end

    status.curChi = 0
end

function ReadStatus()
    status.playerInCombat = false

    status.shapeshiftForm = GetShapeshiftForm()
    if (status.playerClass == ROGUE) then
        status.playerInStealth = ((status.shapeshiftForm > 0) and (status.shapeshiftForm < 4))
    end

    PowerTypeChanged()

    status.curEnergy = UnitPower(status.curUnit)
    status.maxEnergy = UnitPowerMax(status.curUnit)
    status.energyFlashing = 0
    status.energyBGFlashing = 0

    status.curMana = UnitPower(status.curUnit, SPELL_POWER_MANA)
    status.maxMana = UnitPowerMax(status.curUnit, SPELL_POWER_MANA)

    status.curFury = UnitPower(status.curUnit, SPELL_POWER_DEMONIC_FURY)
    status.maxFury = UnitPowerMax(status.curUnit, SPELL_POWER_DEMONIC_FURY)

    if (status.comboEnabled) then
        status.curChi = UnitPower(status.curUnit, SPELL_POWER_COMBO_POINTS)
    elseif (status.chiEnabled) then
        status.curChi = UnitPower(status.curUnit, status.curChiType)
    end
    status.chiFlashing = 0
    
    SetMaxChi()

    status.maxPlayerHealth = UnitHealthMax(status.curUnit)
    status.curPlayerHealth = UnitHealth(status.curUnit)

    status.maxTargetHealth = UnitHealthMax("target")
    status.curTargetHealth = UnitHealth("target")

    if (not Comergy_Settings.Enabled) then
        return
    end

    ComergyOnConfigChange()

    ComergyRestorePosition()
end

function OrderThresholds()
    
    for i = 1, ENERGY_SUBBAR_NUM - 1 do
        local th = Comergy_Settings["EnergyThreshold"..i]
        if ((th) and (th < status.maxEnergy) and (th > 0)) then
            local temp = { th, i }
            orderedEnergyThresholds[i] = temp
        end
    end
    table.sort(orderedEnergyThresholds, function(a, b) return a[1] < b[1] end)

    local lastThreshold = 0
    for i = 1, #(orderedEnergyThresholds) do
        if (orderedEnergyThresholds[i][1] == lastThreshold) then
            orderedEnergyThresholds[i][1] = -1
        else
            lastThreshold = orderedEnergyThresholds[i][1]
        end
    end
    
    
    for i = 1, ENERGY_SUBBAR_NUM - 1 do
        local th = Comergy_Settings["ManaThreshold"..i]
        if ((th) and (th < status.maxMana) and (th > 0)) then
            local temp = { th, i }
            orderedManaThresholds[i] = temp
        end
    end
    table.sort(orderedManaThresholds, function(a, b) return a[1] < b[1] end)

    lastThreshold = 0
    for i = 1, #(orderedManaThresholds) do
        if (orderedManaThresholds[i][1] == lastThreshold) then
            orderedManaThresholds[i][1] = -1
        else
            lastThreshold = orderedManaThresholds[i][1]
        end
    end


    for i = 1, ENERGY_SUBBAR_NUM - 1 do
        local th = Comergy_Settings["FuryThreshold"..i]
        if ((th) and (th < status.maxFury) and (th > 0)) then
            local temp = { th, i }
            orderedFuryThresholds[i] = temp
        end
    end
    table.sort(orderedFuryThresholds, function(a, b) return a[1] < b[1] end)

    lastThreshold = 0
    for i = 1, #(orderedFuryThresholds) do
        if (orderedFuryThresholds[i][1] == lastThreshold) then
            orderedFuryThresholds[i][1] = -1
        else
            lastThreshold = orderedFuryThresholds[i][1]
        end
    end
end

function ComergyOnConfigChange()
    if (Comergy_Settings.DurationScale ~= 0) then
        for i, v in pairs(DURATIONS) do
            DURATIONS[i][1] = DURATIONS[i][2] * Comergy_Settings.DurationScale
        end
    else
        for i, v in pairs(DURATIONS) do
            DURATIONS[i][1] = INSTANT_DURATION
        end
    end

    if (Comergy_Settings.Locked) then
        ComergyMovingFrame:EnableMouse(false)
    else
        ComergyMovingFrame:EnableMouse(true)
    end

    OrderThresholds()

    if (status.energyEnabled) then
        status.curEnergyHeight = Comergy_Settings.EnergyHeight
    elseif (status.manaEnabled) then
        status.curEnergyHeight = Comergy_Settings.ManaHeight
    else
        status.curEnergyHeight = 0
    end

    if (status.furyEnabled) then
        status.curFuryHeight = Comergy_Settings.FuryHeight
    else
        status.curFuryHeight = 0
    end

    FrameResize()

    for i = 1, 8 do
        cmg_ResetObject(chiBars[i], { chiBars[i].curValue[1], chiBars[i].curValue[2], chiBars[i].curValue[3], chiBars[i].curValue[4] + 0.01 })
        if (not Comergy_Settings.UnifiedChiColor) then
            local color = Comergy_Settings["ChiColor"..i]
            for j = 1, 3 do
                cmg_GradientObject(chiBars[i], j + 1, DURATIONS["CHI_SHOW"][1], color[j])
            end
        end
    end

    if (status.chiEnabled or status.comboEnabled) then
        status.curChiHeight = Comergy_Settings.ChiHeight
    elseif (status.runeEnabled) then
        status.curChiHeight = Comergy_Settings.RuneHeight
    else
        status.curChiHeight = 0
    end

    ColorRune()

    for i = 1, numEnergyBars do
        cmg_GradientObject(energyBars[i].bg, 1, INSTANT_DURATION, Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)
        cmg_ResetObject(energyBars[i], { energyBars[i].curValue[1], energyBars[i].curValue[2], energyBars[i].curValue[3], energyBars[i].curValue[4] + 0.01, 1 })
    end

    for i = 1, numFuryBars do
        cmg_GradientObject(furyBars[i].bg, 1, INSTANT_DURATION, Comergy_Settings.FuryBGColorAlpha[4] * 0.3)
        cmg_ResetObject(furyBars[i], { furyBars[i].curValue[1], furyBars[i].curValue[2], furyBars[i].curValue[3], furyBars[i].curValue[4] + 0.01, 1 })
    end

    ComergyBG:SetTexture(Comergy_Settings.BGColorAlpha[1], Comergy_Settings.BGColorAlpha[2], Comergy_Settings.BGColorAlpha[3], Comergy_Settings.BGColorAlpha[4])

    if (Comergy_Settings.ShowPlayerHealthBar) then
        playerBar:Show()
    else
        playerBar:Hide()
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        targetBar:Show()
    else
        targetBar:Hide()
    end

    EnergyChanged()
    ManaChanged()
    ChiChanged()
    RuneChanged()
    FuryChanged()
    TextStyleChanged()
    PlayerHealthChanged()

    ComergyRestorePosition()

    if (Comergy_Settings.FrameStrata == 0) then
        ComergyMainFrame:SetFrameStrata("BACKGROUND")
    elseif (Comergy_Settings.FrameStrata == 1) then
        ComergyMainFrame:SetFrameStrata("LOW")
    elseif (Comergy_Settings.FrameStrata == 2) then
        ComergyMainFrame:SetFrameStrata("MEDIUM")
    elseif (Comergy_Settings.FrameStrata == 3) then
        ComergyMainFrame:SetFrameStrata("HIGH")
    elseif (Comergy_Settings.FrameStrata == 4) then
        ComergyMainFrame:SetFrameStrata("DIALOG")
    elseif (Comergy_Settings.FrameStrata == 5) then
        ComergyMainFrame:SetFrameStrata("FULLSCREEN")
    elseif (Comergy_Settings.FrameStrata == 6) then
        ComergyMainFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    elseif (Comergy_Settings.FrameStrata == 7) then
        ComergyMainFrame:SetFrameStrata("TOOLTIP")
    end

    MainFrameToggle()
end

function ComergyOnLoad(self)
    status.initialized = false

    local class = select(2, UnitClass("player"))

    if (class == "DEATHKNIGHT") then
        status.playerClass = DEATHKNIGHT
    elseif (class == "DRUID") then
        status.playerClass = DRUID
    elseif (class == "HUNTER") then
        status.playerClass = HUNTER
    elseif (class == "MAGE") then
        status.playerClass = MAGE
    elseif (class == "MONK") then
        status.playerClass = MONK
    elseif (class == "PALADIN") then
        status.playerClass = PALADIN
    elseif (class == "PRIEST") then
        status.playerClass = PRIEST
    elseif (class == "ROGUE") then
        status.playerClass = ROGUE
    elseif (class == "SHAMAN") then
        status.playerClass = SHAMAN
    elseif (class == "WARLOCK") then
        status.playerClass = WARLOCK
    elseif (class == "WARRIOR") then
        status.playerClass = WARRIOR
    end

    self:SetScript("OnEvent", function(self, event, ...)
        if ((event == "ADDON_LOADED") or (event == "PLAYER_ENTERING_WORLD") or (event == "PLAYER_LOGIN")) then
            -- Execute any time
            EventHandlers[event](...)
        else
            if (not status.initialized) then
                return
            end
            -- Events that need to be associated with player
            if ((event == "UNIT_COMBO_POINTS") or (event == "UNIT_MAXPOWER") or (event == "UNIT_POWER")
                or (event == "UNIT_MAXHEALTH") or (event == "UNIT_HEALTH")) then
                if (select(1, ...) ~= "player" and select(1, ...) ~= "vehicle") then
                    return
                end
            end
            EventHandlers[event](...)
        end
    end)

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_UNGHOST")
    self:RegisterEvent("PLAYER_ALIVE")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

    self:RegisterEvent("UNIT_COMBO_POINTS")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("UNIT_POWER")
    self:RegisterEvent("UNIT_MAXHEALTH")
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE")
    self:RegisterEvent("UNIT_ENTERING_VEHICLE")
    self:RegisterEvent("UNIT_EXITED_VEHICLE")
    self:RegisterEvent("UNIT_EXITING_VEHICLE")

    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("RUNE_TYPE_UPDATE")
    self:RegisterEvent("RUNE_POWER_UPDATE")
end

function ComergyGetTalent()
    local primaryName, _
    local specIndex = GetSpecialization()
    if (specIndex ~= nil) then
        _, primaryName = GetSpecializationInfo(specIndex)
    else
        primaryName = "N/A"
    end
    return status.talent, primaryName
end

function SetMaxChi()
    if (status.chiEnabled) then
        numChiBars = UnitPowerMax(status.curUnit, status.curChiType)
    elseif (status.comboEnabled) then
        numChiBars = UnitPowerMax(status.curUnit, SPELL_POWER_COMBO_POINTS)
    elseif (status.runeEnabled) then
        numChiBars = 6
    else
        numChiBars = 1
    end
end

function ColorRune()
    if (not status.runeEnabled) then
        return
    end
    for i = 1, 6 do
        cmg_ResetObject(chiBars[i], { chiBars[i].curValue[1], chiBars[i].curValue[2], chiBars[i].curValue[3], chiBars[i].curValue[4] + 0.01 })
        local runeType = GetRuneType(ConvertRune(i)) or math.ceil(ConvertRune(i)/2)
        -- print("Rune:"..i.." Type:"..math.ceil(ConvertRune(i)/2))
        local color = Comergy_Settings["RuneColor"..runeType]
        for j = 1, 3 do
            cmg_GradientObject(chiBars[i], j + 1, INSTANT_DURATION, color[j])
        end
    end
    RuneChanged()
end

-- Blizz codes rune as Blood, Unholy, Frost, but displays them in game as Blood, Frost, Unholy
function ConvertRune(a)
    local b
    if (a == 3 or a == 4) then
        b = a + 2
    elseif (a == 5 or a == 6) then
        b = a - 2
    else
        b = a
    end
    return b
end

-- Event Handlers --

EventHandlers = {}

function EventHandlers.ADDON_LOADED(addonName)
    if (addonName == "Comergy_Redux") then
        Initialize()
    end
end

function EventHandlers.PLAYER_LOGIN()
    status.talent = GetActiveSpecGroup()

--    if (not Comergy_Config) then
--        --noinspection GlobalCreationOutsideO
--        Comergy_Config = { }
--    end

    --noinspection GlobalCreationOutsideO
    Comergy_Config = Comergy_Config or {}

    if (not Comergy_Config[status.talent]) then
        Comergy_Config[status.talent] = PopulateSettingsFrom(Comergy_Config[status.talent], Comergy_Config)
    end

    for i, v in pairs(Comergy_Config) do
        if ((i ~= 1) and (i ~= 2)) then
            Comergy_Config[i] = nil
        end
    end

    Comergy_Config[status.talent] = PopulateSettingsFrom(Comergy_Config[status.talent], Comergy_Config[3 - status.talent])

    --noinspection GlobalCreationOutsideO
    Comergy_Settings = Comergy_Config[status.talent]
end

function EventHandlers.PLAYER_ENTERING_WORLD()
    status.playerGUID = UnitGUID("player")
    
    if (CanExitVehicle() and UnitHasVehicleUI("player")) then
        status.curUnit = "vehicle"
    else
        status.curUnit = "player"
    end

    ReadStatus()
    OrderThresholds()

    ComergyRestorePosition()

    ComergyOnConfigChange()

    status.curEnergy = 0  --makes sure bars get drawn initially
    status.curMana = 0
    status.curFury = 200
    EnergyChanged()
    ManaChanged()
    FuryChanged()
    ChiChanged()
    RuneChanged()
    PlayerHealthChanged()
    TargetHealthChanged()

    status.initialized = true
end

-- For Druid cat form change, rogue stealth, and monk stance change
function EventHandlers.UPDATE_SHAPESHIFT_FORM()

    -- print('Event: shapeshift')

    PowerTypeChanged()

    if (status.playerClass == DRUID) then
        if (Comergy_Settings.Enabled) then
            status.maxEnergy = UnitPowerMax(status.curUnit)
            ResizeEnergyBars()
            FrameResize()
            ReadStatus()
        end
        MainFrameToggle()
    end

    if (status.playerClass == MONK) then
        if (Comergy_Settings.Enabled) then
            status.maxEnergy = UnitPowerMax(status.curUnit)
            ResizeEnergyBars()
            FrameResize()
            status.curEnergy = UnitPower(status.curUnit, SPELL_POWER_ENERGY)
            EnergyChanged()
            status.curMana = UnitPower(status.curUnit, SPELL_POWER_MANA)
            ManaChanged()
        end
        MainFrameToggle()
    end

    -- Rogue's Shadow Dance and Stealth
    if (status.playerClass == ROGUE) then
        local form = GetShapeshiftForm()
        status.playerInStealth = ((form > 0) and (form < 4))
        MainFrameToggle()

        if ((form > 0) and (form < 4) and (Comergy_Settings.StealthSound) and (status.shapeshiftForm == 0)) then        
            PlaySoundFile("Sound\\interface\\iQuestUpdate.wav")
        end
        status.shapeshiftForm = form
    end
end

function EventHandlers.COMBAT_LOG_EVENT_UNFILTERED(...)
    if (select(4, ...) == status.playerGUID) then
        local type = select(2, ...)
        if ((type == "SPELL_DAMAGE") and (Comergy_Settings.CritSound)) then
            if (select(21, ...)) then
                PlaySoundFile("Interface\\AddOns\\Comergy_Redux\\Sound\\critical.ogg")
            end
        elseif ((type == "SPELL_CAST_FAILED") and ((select(15, ...) == ERR_OUT_OF_ENERGY) or (select(15, ...) == ERR_OUT_OF_FOCUS) or (select(15, ...) == ERR_OUT_OF_RUNIC_POWER) or (select(15, ...) == ERR_OUT_OF_RAGE))
                and (Comergy_Settings.EnergyBGFlash)) then
            if (status.energyBGFlashing == 0) then
                status.energyBGFlashing = FLASH_TIMES
                for i = 1, numEnergyBars do
                    cmg_ResetObject(energyBars[i].bg, FLASH_VALUES)
                    cmg_GradientObject(energyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)
                end
            end
        elseif ((type == "SPELL_CAST_FAILED") and (select(15, ...) == ERR_OUT_OF_MANA) and (Comergy_Settings.ManaBGFlash)) then
            if (status.manaBGFlashing == 0) then
                status.manaBGFlashing = FLASH_TIMES
                for i = 1, numEnergyBars do
                    cmg_ResetObject(energyBars[i].bg, FLASH_VALUES)
                    cmg_GradientObject(energyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.ManaBGColorAlpha[4] * 0.3)
                end
            end
        elseif ((type == "SPELL_CAST_FAILED") and (select(15, ...) == ERR_OUT_OF_DEMONIC_FURY) and (Comergy_Settings.FuryBGFlash)) then
            if (status.furyBGFlashing == 0) then
                status.furyBGFlashing = FLASH_TIMES
                for i = 1, numFuryBars do
                    cmg_ResetObject(furyBars[i].bg, FLASH_VALUES)
                    cmg_GradientObject(furyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.FuryBGColorAlpha[4] * 0.3)
                end
            end
        elseif ((type == "SPELL_AURA_APPLIED") or (type == "SPELL_AURA_REFRESH")) then
            local name = select(13, ...)
            if (name == SPELL_NAME_PROWL) then
                status.playerInStealth = true
                MainFrameToggle()
            elseif ((name == SPELL_NAME_SHADOW_DANCE) or (name == SPELL_NAME_VENDETTA) or (name == SPELL_NAME_ADRENALINE_RUSH)) then
                if (Comergy_Settings.EnergyFlash) then
                    status.energyFlashing = 1
                    local newValues = { -1, -1, -1, -1, 1 }
                    for i = 1, numEnergyBars do
                        cmg_ResetObject(energyBars[i], newValues)
                        energyBars[i]:SetAlpha(1)
                        cmg_GradientObject(energyBars[i], 5, FLASH_DURATION, 0)
                    end
                end
            end
        elseif (type == "SPELL_AURA_REMOVED") then
            local name = select(13, ...)
            if (name == SPELL_NAME_PROWL) then
                status.playerInStealth = false
                MainFrameToggle()
            elseif ((name == SPELL_NAME_SHADOW_DANCE) or (name == SPELL_NAME_VENDETTA) or (name == SPELL_NAME_ADRENALINE_RUSH)) then
                if (status.energyFlashing == 1) then
                    status.energyFlashing = 0
                    local newValues = { -1, -1, -1, -1, 1 }
                    for i = 1, numEnergyBars do
                        cmg_ResetObject(energyBars[i], newValues)
                        energyBars[i]:SetAlpha(1)
                        if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                            energyBars[i]:SetStatusBarColor(energyBars[i].curValue[2], energyBars[i].curValue[3], energyBars[i].curValue[4])
                        else
                            energyBars[i]:GetStatusBarTexture():SetTexture(energyBars[i].curValue[2], energyBars[i].curValue[3], energyBars[i].curValue[4])
                        end
                    end
                end
            end
        end
    end
end

function EventHandlers.PLAYER_REGEN_DISABLED()
    status.playerInCombat = true
    MainFrameToggle()
end

function EventHandlers.PLAYER_REGEN_ENABLED()
    status.playerInCombat = false
    MainFrameToggle()
end

function EventHandlers.PLAYER_ALIVE()
    ReadStatus()

    ResizeEnergyBars()
    EnergyChanged()
    ManaChanged()
    ResizeFuryBars()
    PlayerHealthChanged()
    TargetHealthChanged()
end

function EventHandlers.PLAYER_UNGHOST()
    ReadStatus()

    ResizeEnergyBars()
    EnergyChanged()
    ManaChanged()
    ResizeFuryBars()
    PlayerHealthChanged()
    TargetHealthChanged()
end

function EventHandlers.UNIT_COMBO_POINTS()
    -- print('Combo')
    if (not status.comboEnabled) then
        return
    end
    ChiChanged()
end

function EventHandlers.PLAYER_TARGET_CHANGED()
    if (not Comergy_Settings.Enabled) then
        return
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        status.maxTargetHealth = UnitHealthMax("target")
        TargetHealthChanged()

        local _, className = UnitClass("target")
        if (className) then
            local color = RAID_CLASS_COLORS[className]
            cmg_GradientObject(targetBar, 2, DURATIONS["BAR_CHANGE"][1], color.r)
            cmg_GradientObject(targetBar, 3, DURATIONS["BAR_CHANGE"][1], color.g)
            cmg_GradientObject(targetBar, 4, DURATIONS["BAR_CHANGE"][1], color.b)
        end
    end
end

function EventHandlers.UNIT_ENTERED_VEHICLE()
    -- print("UNIT_ENTERED_VEHICLE")
    if (CanExitVehicle() and UnitHasVehicleUI("player")) then  --fix for combo points in EoE for non rogues?
        status.curUnit = "vehicle"
        ReadStatus()
        OrderThresholds()
        ResizeEnergyBars()
        EnergyChanged()  --fix for mis sized energy bars on vehicles with 50 energy?
        ResizeChiBars() --fix for combo points in EoE for non rogues?
        ChiChanged()
    end
end

function EventHandlers.UNIT_ENTERING_VEHICLE()
    -- print("UNIT_ENTERING_VEHICLE")
--    if (CanExitVehicle() and UnitHasVehicleUI("player")) then  --fix for combo points in EoE for non rogues?
--        status.curUnit = "vehicle"
--        ReadStatus()
--        OrderThresholds()
--        ResizeEnergyBars()
--        EnergyChanged()  --fix for mis sized energy bars on vehicles with 50 energy?
--        ResizeChiBars() --fix for combo points in EoE for non rogues?
--        ChiChanged()
--    end
end

function EventHandlers.UNIT_EXITED_VEHICLE()
    -- print("UNIT_EXITED_VEHICLE")
    if (status.curUnit == "vehicle" and not UnitHasVehicleUI("player")) then
        status.curUnit = "player"
        ReadStatus()
        OrderThresholds()
        ResizeEnergyBars()
    end
end

function EventHandlers.UNIT_EXITING_VEHICLE()
    -- print("UNIT_EXITING_VEHICLE")
--    if (status.curUnit == "vehicle" and not UnitHasVehicleUI("player")) then
--        status.curUnit = "player"
--        ReadStatus()
--        OrderThresholds()
--        ResizeEnergyBars()
--    end
end

function EventHandlers.UNIT_MAXPOWER()
    status.maxEnergy = UnitPowerMax(status.curUnit)
    status.maxMana = UnitPowerMax(status.curUnit, SPELL_POWER_MANA)
    status.maxFury = UnitPowerMax(status.curUnit, SPELL_POWER_DEMONIC_FURY)
    SetMaxChi()
    ResizeChiBars()
    ResizeEnergyBars()
    ResizeFuryBars()
end

function EventHandlers.PLAYER_TALENT_UPDATE()
    ComergyOnConfigChange()
    ComergyRestorePosition()
end

-- handles switching specs at a trainer
function EventHandlers.PLAYER_SPECIALIZATION_CHANGED()
    ComergyOnConfigChange()
    ComergyRestorePosition()
    ChiStatus()
    ReadStatus()
end

function EventHandlers.UNIT_POWER()
    status.curEnergy = UnitPower(status.curUnit)
    status.curMana = UnitPower(status.curUnit, SPELL_POWER_MANA)
    status.curFury = UnitPower(status.curUnit, SPELL_POWER_DEMONIC_FURY)
    MainFrameToggle()
    if (status.chiEnabled or status.comboEnabled) then
        if (status.curChi ~= UnitPower(status.curUnit, status.curChiType)) then
            ChiChanged()
        end
    end 
    if (status.furyEnabled) then
        FuryChanged()
    end 
end

function EventHandlers.UNIT_MAXHEALTH()
    if (Comergy_Settings.showPlayerHealthBar) then
        status.maxPlayerHealth = UnitHealthMax(status.curUnit)
        PlayerHealthChanged()
        MainFrameToggle()
    end
end

function EventHandlers.UNIT_HEALTH()
    if (Comergy_Settings.showPlayerHealthBar) then
        status.curPlayerHealth = UnitHealth(status.curUnit)
        PlayerHealthChanged()
        MainFrameToggle()
    end
end

function EventHandlers.RUNE_TYPE_UPDATE(i)
    ColorRune()
end

function EventHandlers.RUNE_POWER_UPDATE(i)
    RuneChanged()
end

-- handles switching specs via dual spec
function EventHandlers.ACTIVE_TALENT_GROUP_CHANGED()
    status.talent = GetActiveSpecGroup()

    ChiStatus()

    if (not Comergy_Config[status.talent]) then
        Comergy_Config[status.talent] = { }
    end

    Comergy_Config[status.talent] = PopulateSettingsFrom(Comergy_Config[status.talent], Comergy_Config[3 - status.talent])
    Comergy_Settings = Comergy_Config[status.talent]
    ComergyOnConfigChange()

    ComergyRestorePosition()

    if (IsAddOnLoaded("Comergy_Redux_Options")) then
        ComergyOptReadSettings()
    end
end

function ComergySavePosition()
    local frameX, frameY
    frameX, frameY = ComergyMainFrame:GetCenter()
    Comergy_Settings.X = frameX - (floor(UIParent:GetWidth() / 2))
    Comergy_Settings.Y = frameY - (floor(UIParent:GetHeight() / 2))
end

function ComergyRestorePosition()
    ComergyMainFrame:ClearAllPoints()
    ComergyMainFrame:SetPoint("Center", UIParent, "Center", Comergy_Settings.X, Comergy_Settings.Y)
end

function ComergyOnUpdate(self, elapsed)
    if (not status.initialized) then
        return
    end

    OnFrameUpdate(elapsed)

    if (not Comergy_Settings.Enabled) then
        return
    end

    local count = 0
    lastPeriodicUpdate = lastPeriodicUpdate + elapsed
    while (lastPeriodicUpdate >= PERIODIC_UPDATE_INTERVAL) do
        count = count + 1
        lastPeriodicUpdate = lastPeriodicUpdate - PERIODIC_UPDATE_INTERVAL
    end
    if (count > 0) then
        OnPeriodicUpdate()
    end
end

function OnFrameUpdate(elapsed)

    if (cmg_UpdateObject(ComergyMainFrame, elapsed)) then
        ComergyMainFrame:SetAlpha(ComergyMainFrame.curValue[1])
        if (ComergyMainFrame.curValue[1] == 0) then
            ComergyMainFrame:Hide()
        end
    end

    if (not Comergy_Settings.Enabled) then
        return
    end

    if (status.comboEnabled or status.chiEnabled or status.runeEnabled) then
        for i = 1, 8 do
            if (cmg_UpdateObject(chiBars[i], elapsed)) then
                -- Very nasty hack for rotating textures...
                if ((chiBars[i].verticalInit < 2) and (Comergy_Settings.VerticalBars)) then
                    chiBars[i]:GetStatusBarTexture():SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
                    chiBars[i].verticalInit = chiBars[i].verticalInit + 1
                end
                chiBars[i]:SetAlpha(chiBars[i].curValue[1])
                if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                    chiBars[i]:SetStatusBarColor(chiBars[i].curValue[2], chiBars[i].curValue[3], chiBars[i].curValue[4])
                else
                    chiBars[i]:GetStatusBarTexture():SetTexture(chiBars[i].curValue[2], chiBars[i].curValue[3], chiBars[i].curValue[4])
                end
            end
        end

        if (status.chiEnabled or status.comboEnabled) then
            if ((status.chiFlashing > 0) and (chiBars[1].curValue[1] == Comergy_Settings.ChiBGAlpha)) then
                status.chiFlashing = status.chiFlashing - 1
                if (status.chiFlashing > 0) then
                    for i = 1, #(chiBars) do
                        cmg_ResetObject(chiBars[i], FLASH_VALUES)
                        chiBars[i]:SetAlpha(chiBars[i].curValue[1])
                        cmg_GradientObject(chiBars[i], 1, FLASH_DURATION, Comergy_Settings.ChiBGAlpha)
                    end
                else
                    for i = 1, #(chiBars) do
                        cmg_ResetObject(chiBars[i], ONE_VALUES)
                        chiBars[i]:SetAlpha(chiBars[i].curValue[1])
                    end
                end
            end
        end

        if (status.runeEnabled) then
            for i = 1, 6 do
                if ((status.runeFlashing[i] > 0) and (chiBars[i].curValue[1] == Comergy_Settings.RuneBGAlpha
                        or chiBars[i].curValue[1] == 0.3)) then
                    status.runeFlashing[i] = status.runeFlashing[i] - 1
                    if (status.runeFlashing[i] > 0) then
                        cmg_ResetObject(chiBars[i], FLASH_VALUES)
                        chiBars[i]:SetAlpha(chiBars[i].curValue[1])
                        cmg_GradientObject(chiBars[i], 1, FLASH_DURATION, 0.3)
                    else
                        cmg_ResetObject(chiBars[i], ONE_VALUES)
                        chiBars[i]:SetAlpha(chiBars[i].curValue[1])
                    end
                end
            end
        end
    end

    for i = 1, numEnergyBars do
        if (cmg_UpdateObject(energyBars[i], elapsed)) then
            cmg_SetStatusBarValue(energyBars[i], energyBars[i].curValue[1])
            local r, g, b
            if (status.energyFlashing > 0) then
                energyBars[i]:SetAlpha(energyBars[i].curValue[5])
                r = Comergy_Settings.EnergyFlashColor[1]
                g = Comergy_Settings.EnergyFlashColor[2]
                b = Comergy_Settings.EnergyFlashColor[3]
            else
                r = energyBars[i].curValue[2]
                g = energyBars[i].curValue[3]
                b = energyBars[i].curValue[4]
            end

            if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                energyBars[i]:SetStatusBarColor(r, g, b)
            else
                energyBars[i]:GetStatusBarTexture():SetTexture(r, g, b)
            end
        end

        if (cmg_UpdateObject(energyBars[i].bg, elapsed)) then
            energyBars[i].bg:SetTexture(Comergy_Settings.EnergyBGColorAlpha[1], Comergy_Settings.EnergyBGColorAlpha[2], 
                Comergy_Settings.EnergyBGColorAlpha[3], energyBars[i].bg.curValue[1])
        end
    end

    if (status.playerClass == DEATHKNIGHT) then
        for i = 1, 6 do
            chiBars[i].bg:SetTexture(Comergy_Settings.RuneBGColorAlpha[1], Comergy_Settings.RuneBGColorAlpha[2], 
                    Comergy_Settings.RuneBGColorAlpha[3], (Comergy_Settings.RuneBGColorAlpha[4]))
        end
    end

    if ((status.energyFlashing > 0) and (energyBars[1].curValue[5] == 0)) then
        local newValues = { -1, -1, -1, -1, 1 }
        for i = 1, numEnergyBars do
            cmg_ResetObject(energyBars[i], newValues)
            energyBars[i]:SetAlpha(1)
            cmg_GradientObject(energyBars[i], 5, FLASH_DURATION, 0)
        end
    end

    if ((status.energyBGFlashing > 0) and (energyBars[1].bg.curValue[1] == Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)) then
        status.energyBGFlashing = status.energyBGFlashing - 1
        if (status.energyBGFlashing > 0) then
            for i = 1, numEnergyBars do
                cmg_ResetObject(energyBars[i].bg, FLASH_VALUES)
                energyBars[i].bg:SetTexture(Comergy_Settings.EnergyBGColorAlpha[1], Comergy_Settings.EnergyBGColorAlpha[2],
                    Comergy_Settings.EnergyBGColorAlpha[3], energyBars[i].bg.curValue[1])
                cmg_GradientObject(energyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.EnergyBGColorAlpha[4] * 0.3)
            end
        else
            for i = 1, numEnergyBars do
                cmg_ResetObject(energyBars[i].bg, { Comergy_Settings.EnergyBGColorAlpha[4] * 0.3 })
                energyBars[i].bg:SetTexture(Comergy_Settings.EnergyBGColorAlpha[1], Comergy_Settings.EnergyBGColorAlpha[2],
                    Comergy_Settings.EnergyBGColorAlpha[3], energyBars[i].bg.curValue[1])
            end
        end
    end

    if (Comergy_Settings.ShowPlayerHealthBar) then
        if (cmg_UpdateObject(playerBar, elapsed)) then
            playerBar:SetValue(playerBar.curValue[1])
            playerBar:GetStatusBarTexture():SetTexture(playerBar.curValue[2], playerBar.curValue[3], playerBar.curValue[4])
        end
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        if (cmg_UpdateObject(targetBar, elapsed)) then
            targetBar:SetValue(targetBar.curValue[1])
            targetBar:GetStatusBarTexture():SetTexture(targetBar.curValue[2], targetBar.curValue[3], targetBar.curValue[4])
        end
    end

    if (status.furyEnabled) then
        for i = 1, numFuryBars do
            if (cmg_UpdateObject(furyBars[i], elapsed)) then
                cmg_SetStatusBarValue(furyBars[i], furyBars[i].curValue[1])
                local r, g, b
                if (status.furyFlashing > 0) then
                    furyBars[i]:SetAlpha(furyBars[i].curValue[5])
                    r = Comergy_Settings.furyFlashColor[1]
                    g = Comergy_Settings.furyFlashColor[2]
                    b = Comergy_Settings.furyFlashColor[3]
                else
                    r = furyBars[i].curValue[2]
                    g = furyBars[i].curValue[3]
                    b = furyBars[i].curValue[4]
                end

                if (ComergyBarTextures[Comergy_Settings.BarTexture][2]) then
                    furyBars[i]:SetStatusBarColor(r, g, b)
                else
                    furyBars[i]:GetStatusBarTexture():SetTexture(r, g, b)
                end
            end

            if (cmg_UpdateObject(furyBars[i].bg, elapsed)) then
                furyBars[i].bg:SetTexture(Comergy_Settings.FuryBGColorAlpha[1], Comergy_Settings.FuryBGColorAlpha[2], 
                    Comergy_Settings.FuryBGColorAlpha[3], furyBars[i].bg.curValue[1])
            end
        end
    end

    if ((status.furyFlashing > 0) and (furyBars[1].curValue[5] == 0)) then
        local newValues = { -1, -1, -1, -1, 1 }
        for i = 1, numFuryBars do
            cmg_ResetObject(furyBars[i], newValues)
            furyBars[i]:SetAlpha(1)
            cmg_GradientObject(furyBars[i], 5, FLASH_DURATION, 0)
        end
    end

    if ((status.furyBGFlashing > 0) and (furyBars[1].bg.curValue[1] == Comergy_Settings.FuryBGColorAlpha[4] * 0.3)) then
        status.furyBGFlashing = status.furyBGFlashing - 1
        if (status.furyBGFlashing > 0) then
            for i = 1, numFuryBars do
                cmg_ResetObject(furyBars[i].bg, FLASH_VALUES)
                furyBars[i].bg:SetTexture(Comergy_Settings.FuryBGColorAlpha[1], Comergy_Settings.FuryBGColorAlpha[2],
                    Comergy_Settings.FuryBGColorAlpha[3], furyBars[i].bg.curValue[1])
                cmg_GradientObject(furyBars[i].bg, 1, FLASH_DURATION, Comergy_Settings.FuryBGColorAlpha[4] * 0.3)
            end
        else
            for i = 1, numFuryBars do
                cmg_ResetObject(furyBars[i].bg, { Comergy_Settings.FuryBGColorAlpha[4] * 0.3 })
                furyBars[i].bg:SetTexture(Comergy_Settings.FuryBGColorAlpha[1], Comergy_Settings.FuryBGColorAlpha[2],
                    Comergy_Settings.FuryBGColorAlpha[3], furyBars[i].bg.curValue[1])
            end
        end
    end
end



--move sound, not registering max power
function OnPeriodicUpdate()
    if (status.energyEnabled) then
        local curEnergy = UnitPower(status.curUnit)
        if (status.curEnergy ~= curEnergy) then
            if ((curEnergy > status.curEnergy) and ((not Comergy_Settings.ShowOnlyInCombat) or (status.playerInCombat))) then
                local sound = false
                for i = 1, ENERGY_SUBBAR_NUM - 1 do
                    if ((Comergy_Settings["EnergyThreshold"..i] > status.curEnergy) and (Comergy_Settings["EnergyThreshold"..i] <= curEnergy) and (Comergy_Settings["SoundEnergy"..i])) then
                        sound = true
                        break
                    end
                end
                if ((status.maxEnergy == curEnergy) and (Comergy_Settings["SoundEnergy"..ENERGY_SUBBAR_NUM])) then
                    sound = true
                end
                if (sound) then
                    PlaySoundFile("Interface\\AddOns\\Comergy_Redux\\sound\\energytick.ogg")
                end
            end

            local diff = curEnergy - status.curEnergy
            local isSmallInc = (diff >= 1) and (diff <= 3)
            status.curEnergy = curEnergy

            if ((status.curEnergy == status.maxEnergy) and ((status.curPowerType == "ENERGY") or (status.curPowerType == "FOCUS"))) then
                MainFrameToggle()
            end
            if ((status.curEnergy == 0) and ((status.curPowerType == "RAGE") or (status.curPowerType == "RUNIC_POWER"))) then
                MainFrameToggle()
            end

            EnergyChanged(isSmallInc)
        end
    end

    if (status.manaEnabled) then
        local curMana = UnitPower(status.curUnit, SPELL_POWER_MANA)
        if (status.curMana ~= curMana) then
            if ((curMana > status.curMana) and ((not Comergy_Settings.ShowOnlyInCombat) or (status.playerInCombat))) then
                local sound = false
                for i = 1, ENERGY_SUBBAR_NUM - 1 do
                    if ((Comergy_Settings["ManaThreshold"..i] > status.curMana) and (Comergy_Settings["ManaThreshold"..i] <= curMana) and (Comergy_Settings["SoundMana"..i])) then
                        sound = true
                        break
                    end
                end
                if ((status.maxMana == curMana) and (Comergy_Settings["SoundMana"..ENERGY_SUBBAR_NUM])) then
                    sound = true
                end
                if (sound) then
                    PlaySoundFile("Interface\\AddOns\\Comergy_Redux\\sound\\energytick.ogg")
                end
            end

            local diff = curMana - status.curMana
            local isSmallInc = (diff >= 1) and (diff <= 3)
            status.curMana = curMana

            if ((status.curMana == status.maxMana) and ((status.curPowerType == "MANA") or (status.curPowerType == "FOCUS"))) then
                MainFrameToggle()
            end
            if ((status.curMana == 0) and ((status.curPowerType == "RAGE") or (status.curPowerType == "RUNIC_POWER"))) then
                MainFrameToggle()
            end

            ManaChanged(isSmallInc)
        end
    end

    if (status.furyEnabled) then
        local curFury = UnitPower(status.curUnit, SPELL_POWER_DEMONIC_FURY)
        if (status.curFury ~= curFury) then
            if ((curFury > status.curFury) and ((not Comergy_Settings.ShowOnlyInCombat) or (status.playerInCombat))) then
                local sound = false
                for i = 1, ENERGY_SUBBAR_NUM - 1 do
                    if ((Comergy_Settings["FuryThreshold"..i] > status.curFury) and (Comergy_Settings["FuryThreshold"..i] <= curFury) and (Comergy_Settings["SoundFury"..i])) then
                        sound = true
                        break
                    end
                end
                if ((status.maxFury == curFury) and (Comergy_Settings["SoundFury"..ENERGY_SUBBAR_NUM])) then
                    sound = true
                end
                if (sound) then
                    PlaySoundFile("Interface\\AddOns\\Comergy_Redux\\sound\\energytick.ogg")
                end
            end

            local diff = curFury - status.curFury
            local isSmallInc = (diff >= 1) and (diff <= 3)
            status.curFury = curFury

            if ((status.curFury == status.maxFury) and ((status.curPowerType == "ENERGY") or (status.curPowerType == "FOCUS"))) then
                MainFrameToggle()
            end
            if ((status.curFury == 0) and ((status.curPowerType == "RAGE") or (status.curPowerType == "RUNIC_POWER"))) then
                MainFrameToggle()
            end

            FuryChanged(isSmallInc)
        end
    end

    if (status.runeEnabled) then
        for i = 1, 6 do
            if (status.runeFlashing[i] == -1) then
                j = ConvertRune(i)
                local runeStart, runeDuration, isReady = GetRuneCooldown(j)
                if (not isReady) then
                    local value = (runeDuration - (GetTime() - runeStart)) * -1
                    if (value >= -10 and value <= 0) then
                        chiBars[i]:SetValue(value)
                    elseif (value < -10) then
                        chiBars[i]:SetValue(-10)
                    end
                end
            end
        end
    end

    if (Comergy_Settings.ShowPlayerHealthBar) then
        local curHealth = UnitHealth(status.curUnit)
        local maxHealth = UnitHealthMax(status.curUnit)
        if (status.curPlayerHealth ~= curHealth) then
            status.curPlayerHealth = curHealth
            PlayerHealthChanged()
            MainFrameToggle()
        end
        if (status.maxPlayerHealth ~= maxHealth) then
            status.maxPlayerHealth = maxHealth
            PlayerHealthChanged()
            MainFrameToggle()
        end
    end

    if (Comergy_Settings.ShowTargetHealthBar) then
        local curHealth = UnitHealth("target")
        if (status.curTargetHealth ~= curHealth) then
            status.curTargetHealth = curHealth
            TargetHealthChanged()
        end
    end
end
