local Transmog = _G.ChromieTransmog
local _, race = UnitRace('player')
local _, class = UnitClass('player')

Transmog.race = string.lower(race)
Transmog.class = string.lower(class)
Transmog.faction = 'A'
if Transmog.race ~= 'human' and Transmog.race ~= 'gnome' and Transmog.race ~= 'dwarf' and Transmog.race ~= 'nightelf' and Transmog.race ~= 'bloodelf' then
    Transmog.faction = 'H'
end

-- Preview backdrop: assets/transmogbackground<key>.blp
-- UnitRace "Scourge" → undead file; unknown races fall back to human.
local RACE_BACKGROUND = {
    human = 'human',
    dwarf = 'dwarf',
    gnome = 'gnome',
    nightelf = 'nightelf',
    bloodelf = 'bloodelf',
    draenei = 'draenei',
    orc = 'orc',
    tauren = 'tauren',
    troll = 'troll',
    undead = 'undead',
    scourge = 'undead',
    goblin = 'goblin',
    highelf = 'highelf',
}
Transmog.raceBackground = RACE_BACKGROUND[Transmog.race] or 'human'

-- azerothcore/mod-transmog default NPCs (ChromieCraft Warpweaver / portable pet).
Transmog.CHROMIE_NPC_IDS = {
    [190010] = true,
    [190011] = true,
}

Transmog.inventorySlots = {
    ['HeadSlot'] = 1,
    ['ShoulderSlot'] = 3,
    ['ChestSlot'] = 5,
    ['WaistSlot'] = 6,
    ['LegsSlot'] = 7,
    ['FeetSlot'] = 8,
    ['WristSlot'] = 9,
    ['HandsSlot'] = 10,
    ['BackSlot'] = 15,
    ['MainHandSlot'] = 16,
    ['SecondaryHandSlot'] = 17,
    ['RangedSlot'] = 18
}

Transmog.inventorySlotNames = {
    [1] = "Head Slot",
    [3] = "Shoulder Slot",
    [5] = "Chest Slot",
    [6] = "Waist Slot",
    [7] = "Legs Slot",
    [8] = "Feet Slot",
    [9] = "Wrist Slot",
    [10] = "Hand Slot",
    [15] = "Back Slot",
    [16] = "Main Hand Slot",
    [17] = "Off Hand Slot",
    [18] = "Ranged Slot"
}

-- Must stay in sync with HIDDEN_ITEM_ID in azerothcore/mod-transmog (item id 1).
Transmog.HIDDEN_ITEM_ID = 1
Transmog.UNKNOWN_MOG_ID = -1

-- Slots that can be hidden. ChromieCraft gossip offers Hide Slot on weapons too.
Transmog.hideableSlots = {
    [1] = true,  -- Head
    [3] = true,  -- Shoulder
    [5] = true,  -- Chest
    [6] = true,  -- Waist
    [7] = true,  -- Legs
    [8] = true,  -- Feet
    [9] = true,  -- Wrist
    [10] = true, -- Hands
    [15] = true, -- Back
    [16] = true, -- Main Hand
    [17] = true, -- Off Hand
    [18] = true, -- Ranged
}

-- DressUpModel TryOn order: armor first, weapons last (main hand re-applied after offhand).
-- Ranged (18) is only dressed when that slot has a pending preview change.
Transmog.previewArmorOrder = { 1, 3, 5, 6, 7, 8, 9, 10, 15 }
Transmog.previewWeaponSlots = { 16, 17 }

Transmog.invTypes = {
    ['INVTYPE_HEAD'] = 1,
    ['INVTYPE_SHOULDER'] = 3,
    ['INVTYPE_CLOAK'] = 16,
    ['INVTYPE_CHEST'] = 5,
    ['INVTYPE_ROBE'] = 20,
    ['INVTYPE_WAIST'] = 6,
    ['INVTYPE_LEGS'] = 7,
    ['INVTYPE_FEET'] = 8,
    ['INVTYPE_WRIST'] = 9,
    ['INVTYPE_HAND'] = 10,

    ['INVTYPE_WEAPON'] = 13,
    ['INVTYPE_WEAPONMAINHAND'] = 21,

    ['INVTYPE_2HWEAPON'] = 17,

    ['INVTYPE_SHIELD'] = 14,
    ['INVTYPE_WEAPONOFFHAND'] = 22,
    ['INVTYPE_HOLDABLE'] = 23,

    ['INVTYPE_THROWN'] = 25,
    ['INVTYPE_RANGED'] = 15,
    ['INVTYPE_RANGEDRIGHT'] = 26,
    ['INVTYPE_RELIC'] = 28,
}

EQUIPMENT_SLOT_HEAD = 0
EQUIPMENT_SLOT_SHOULDERS = 2
EQUIPMENT_SLOT_BODY = 3
EQUIPMENT_SLOT_CHEST = 4
EQUIPMENT_SLOT_WAIST = 5
EQUIPMENT_SLOT_LEGS = 6
EQUIPMENT_SLOT_FEET = 7
EQUIPMENT_SLOT_WRISTS = 8
EQUIPMENT_SLOT_HANDS = 9
EQUIPMENT_SLOT_BACK = 14
EQUIPMENT_SLOT_MAINHAND = 15
EQUIPMENT_SLOT_OFFHAND = 16
EQUIPMENT_SLOT_RANGED = 17

C_INVTYPE_HEAD = 1;
C_INVTYPE_SHOULDERS = 3;
C_INVTYPE_BODY = 4;
C_INVTYPE_CHEST = 5;
C_INVTYPE_WAIST = 6;
C_INVTYPE_LEGS = 7;
C_INVTYPE_FEET = 8;
C_INVTYPE_WRISTS = 9;
C_INVTYPE_HANDS = 10;
C_INVTYPE_WEAPON = 13;
C_INVTYPE_SHIELD = 14;
C_INVTYPE_RANGED = 15;
C_INVTYPE_CLOAK = 16;
C_INVTYPE_2HWEAPON = 17;
C_INVTYPE_ROBE = 20;
C_INVTYPE_WEAPONMAINHAND = 21;
C_INVTYPE_WEAPONOFFHAND = 22;
C_INVTYPE_HOLDABLE = 23;
C_INVTYPE_THROWN = 25;
C_INVTYPE_RANGEDRIGHT = 26;

