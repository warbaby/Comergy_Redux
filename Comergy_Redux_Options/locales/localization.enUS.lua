if (true) then
    COMERGY_GENERAL = "General"
    COMERGY_BAR = "Bars and Text"
    COMERGY_ENERGY = "Energy"
    COMERGY_FOCUS = "Focus"
    COMERGY_RAGE = "Rage"
    COMERGY_RUNIC_POWER = "Runic Power"
    COMERGY_MANA = "Mana"
    COMERGY_CHI = "Chi"
    COMERGY_COMBO = "Combo"
    COMERGY_HOLY_POWER = "Holy Power"
    COMERGY_SHADOW_ORB = "Shadow Orb"
    COMERGY_SOUL_SHARD = "Soul Shard"
    COMERGY_DEMONIC_FURY = "Demonic Fury"
    COMERGY_ROGUE = "Rogue"
    COMERGY_RUNE = "Rune"
    COMERGY_BLOOD = "Blood"
    COMERGY_FROST = "Frost"
    COMERGY_UNHOLY = "Unholy"
    COMERGY_DEATH = "Death"

    COMERGY_LOW = "Low"
    COMERGY_HIGH = "High"
    COMERGY_LEFT = "Left"
    COMERGY_RIGHT = "Right"
    
    COMERGY_TARGET_HEALTH_WARNING = "note: may require reload to take effect"

    COMERGY_TEXT_SOUND = "Sound"
    COMERGY_TEXT_SPLIT = "Split"
    COMERGY_TEXT_COLOR = "Color"
    COMERGY_TEXT_FLASH = "When Vendetta, Adrenaline Rush or Shadow Dance:"
    COMERGY_TEXT_ANTICIPATION = "When using lvl 90 talent Anticipation:"

    COMERGY_TEXTURE = "Bar texture"
    COMERGY_FONT = "Font"

    COMERGY_SLIDERINFO = {
        ["X"] = "Horizontal Position",
        ["Y"] = "Vertical Position",
        ["Width"] = "Length",
        ["Spacing"] = "Spacing",
        ["TextHeight"] = "Font size",
        ["DurationScale"] = "Fading delay",
        ["FrameStrata"] = "Frame strata",
        ["PlayerHeight"] = "Player's health bar height",
        ["TargetHeight"] = "Target's health bar height",
        ["FuryHeight"] = "Fury bar thickness",
    }

    COMERGY_SLIDERINFO_ENERGY = {
        ["EnergyHeight"] = "Energy bar thickness",
    }

    COMERGY_SLIDERINFO_FOCUS = {
        ["EnergyHeight"] = "Focus bar thickness",
    }

    COMERGY_SLIDERINFO_RAGE = {
        ["EnergyHeight"] = "Rage bar thickness",
    }

    COMERGY_SLIDERINFO_RUNIC = {
        ["EnergyHeight"] = "Runic bar thickness",
    }

    COMERGY_SLIDERINFO_MANA = {
        ["ManaHeight"] = "Mana bar thickness",
    }

    COMERGY_SLIDERINFO_COMBO = {
        ["ChiHeight"] = "Combo bar thickness",
        ["ChiBGAlpha"] = "Combo BG alpha",
        ["ChiDiff"] = "Fancy combo bars",
    }

    COMERGY_SLIDERINFO_CHI = {
        ["ChiHeight"] = "Chi bar thickness",
        ["ChiBGAlpha"] = "Chi BG alpha",
        ["ChiDiff"] = "Fancy chi bars",
    }

    COMERGY_SLIDERINFO_HOLY_POWER = {
        ["ChiHeight"] = "Holy power bar thickness",
        ["ChiBGAlpha"] = "Holy power BG alpha",
        ["ChiDiff"] = "Fancy holy power bars",
    }

    COMERGY_SLIDERINFO_SHADOW_ORB = {
        ["ChiHeight"] = "Orb bar thickness",
        ["ChiBGAlpha"] = "Orb BG alpha",
        ["ChiDiff"] = "Fancy orb bars",
    }

    COMERGY_SLIDERINFO_RUNE = {
        ["RuneHeight"] = "Rune bar thickness",
        ["RuneBGAlpha"] = "Rune cd alpha",
        ["RuneDiff"] = "Fancy rune bars",
    }

    COMERGY_CHECKOPTINFO = {
        ["Enabled"] = "Enable add-on",
        ["ShowOnlyInCombat"] = "Hide Comergy out of combat",
        ["ShowInStealth"] = "Show add-on in stealth",
        ["ShowWhenEnergyNotFull"] = "but show when energy/health not full",
        ["Locked"] = "Lock position",
        ["CritSound"] = "Critical sound",
        ["StealthSound"] = "Add missing Stealth sound",
        ["TextCenter"] = "Centered text",
        ["TextCenterUp"] = "Above frame",
        ["FlipBars"] = "Flip energy/combo bars",
        ["FlipOrientation"] = "Flip orientation",
        ["VerticalBars"] = "Vertical bars",
        ["ShowPlayerHealthBar"] = "Show",
        ["ShowTargetHealthBar"] = "Show",
        ["EnergyFlash"] = "Flash energy bars",
        ["Anticipation"] = "Recolor bars",
        ["AnticipationCombo"] = "Only recolor active combo points",
        ["FuryText"] = "Fury text",
        ["UnifiedFuryColor"] = "Unified fury color",
        ["GradientFuryColor"] = "Gradient fury color",
        ["FuryBGFlash"] = "Flash BG when \"Not enough fury\"",
    }

    COMERGY_CHECKOPTINFO_ENERGY = {
        ["EnergyText"] = "Energy text",
        ["UnifiedEnergyColor"] = "Unified energy color",
        ["GradientEnergyColor"] = "Gradient energy color",
        ["EnergyBGFlash"] = "Flash BG when \"Not enough energy\"",
    }

    COMERGY_CHECKOPTINFO_FOCUS = {
        ["EnergyText"] = "Focus text",
        ["UnifiedEnergyColor"] = "Unified foucs color",
        ["GradientEnergyColor"] = "Gradient focus color",
        ["EnergyBGFlash"] = "Flash BG when \"Not enough focus\"",
    }

    COMERGY_CHECKOPTINFO_RAGE = {
        ["EnergyText"] = "Rage text",
        ["UnifiedEnergyColor"] = "Unified rage color",
        ["GradientEnergyColor"] = "Gradient rage color",
        ["EnergyBGFlash"] = "Flash BG when \"Not enough rage\"",
    }

    COMERGY_CHECKOPTINFO_RUNIC = {
        ["EnergyText"] = "Runic text",
        ["UnifiedEnergyColor"] = "Unified runic color",
        ["GradientEnergyColor"] = "Gradient runic color",
        ["EnergyBGFlash"] = "Flash BG when \"Not enough runic\"",
    }

    COMERGY_CHECKOPTINFO_MANA = {
        ["ManaText"] = "Mana text",
        ["ManaShortText"] = "300k",
        ["UnifiedManaColor"] = "Unified mana color",
        ["GradientManaColor"] = "Gradient mana color",
        ["ManaBGFlash"] = "Flash BG when \"Not enough mana\"",
    }

    COMERGY_CHECKOPTINFO_COMBO = {
        ["ChiText"] = "Combo text",
        ["UnifiedChiColor"] = "Unified combo color",
        ["ChiFlash"] = "Flash combo points when 5 Combos",
    }

    COMERGY_CHECKOPTINFO_CHI = {
        ["ChiText"] = "Chi text",
        ["UnifiedChiColor"] = "Unified chi color",
        ["ChiFlash"] = "Flash chi points when full chi",
    }

    COMERGY_CHECKOPTINFO_SHADOW_ORB = {
        ["ChiText"] = "Shadow orb text",
        ["UnifiedChiColor"] = "Unified shadow orb color",
        ["ChiFlash"] = "Flash shadow orbs when full shadow orbs",
    }

    COMERGY_CHECKOPTINFO_HOLY_POWER = {
        ["ChiText"] = "Holy power text",
        ["UnifiedChiColor"] = "Unified holy power color",
        ["ChiFlash"] = "Flash holy power when full holy power",
    }

    COMERGY_CHECKOPTINFO_RUNE = {
        ["RuneText"] = "Rune text",
        ["UnifiedRuneColor"] = "Unified rune color",
        ["RuneFlash"] = "Flash runes",
    }


    COMERGY_COLORPICKERINFO = {
        ["TextColor"] = "Text color",
        ["BGColorAlpha"] = "BG color",
        ["RuneBGColorAlpha"] = "Rune BG",
        ["FuryBGColorAlpha"] = "Fury BG",
    }

    COMERGY_COLORPICKERINFO_ENERGY = {
        ["EnergyBGColorAlpha"] = "Energy BG",
    }

    COMERGY_COLORPICKERINFO_FOCUS = {
        ["EnergyBGColorAlpha"] = "Focus BG",
    }

    COMERGY_COLORPICKERINFO_RAGE = {
        ["EnergyBGColorAlpha"] = "Rage BG",
    }

    COMERGY_COLORPICKERINFO_RUNIC = {
        ["EnergyBGColorAlpha"] = "Runic BG",
    }

    COMERGY_COLORPICKERINFO_MANA = {
        ["ManaBGColorAlpha"] = "Mana BG",
    }

    COMERGY_TALENT_PRIMARY = "Primary"
    COMERGY_TALENT_SECONDARY = "Secondary"

    COMERGY_TALENT = " talent"
end