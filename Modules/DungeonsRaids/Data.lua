-- Seviath's Dungeons & Raids - class data
-- Check these after big patches: Blizzard sometimes moves raid buffs between classes.
local _, ns = SFP_Module("DungeonsRaids")
local D = {}
ns.Data = D

-- Mists of Pandaria raid buffs. Several classes (or hunter pets) can bring each one,
-- so every buff lists all of its providers; "class" is the one shown in the "who brings it" text.
D.BUFFS = {
  { key = "STATS", name = "+5% Stats",          short = "Stats", class = "DRUID",       classes = { DRUID = true, MONK = true, PALADIN = true, HUNTER = true } },
  { key = "STAM",  name = "+10% Stamina",       short = "Stam",  class = "PRIEST",      classes = { PRIEST = true, WARRIOR = true, WARLOCK = true } },
  { key = "AP",    name = "+10% Attack Power",  short = "AP",    class = "WARRIOR",     classes = { WARRIOR = true, DEATHKNIGHT = true, HUNTER = true } },
  { key = "SP",    name = "+10% Spell Power",   short = "SP",    class = "MAGE",        classes = { MAGE = true, WARLOCK = true, SHAMAN = true } },
  { key = "HASTE", name = "+5% Haste",          short = "Haste", class = "SHAMAN",      classes = { SHAMAN = true, ROGUE = true, DEATHKNIGHT = true, DRUID = true, PRIEST = true } },
  { key = "CRIT",  name = "+5% Critical Strike", short = "Crit", class = "MAGE",        classes = { MAGE = true, DRUID = true, SHAMAN = true, MONK = true, HUNTER = true } },
  { key = "MAST",  name = "Mastery",            short = "Mast",  class = "PALADIN",     classes = { PALADIN = true, SHAMAN = true, HUNTER = true } },
}

-- does this class bring the buff?
function D.Provides(buff, class)
  return (buff.classes and buff.classes[class]) or buff.class == class
end

-- "Mage, Warlock, Shaman" in the player's language
function D.ProviderText(buff)
  local names = {}
  for class in pairs(buff.classes or { [buff.class] = true }) do names[#names + 1] = D.ClassLabel(class) end
  table.sort(names)
  return table.concat(names, ", ")
end

-- Bloodlust / Heroism / Time Warp (hunter pets: Core Hound) and combat resurrection
D.LUST = { SHAMAN = true, MAGE = true, HUNTER = true }
D.BREZ = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true }

D.ARMOR = {
  WARRIOR = "Plate", PALADIN = "Plate", DEATHKNIGHT = "Plate",
  HUNTER = "Mail", SHAMAN = "Mail",
  ROGUE = "Leather", DRUID = "Leather", MONK = "Leather",
  PRIEST = "Cloth", MAGE = "Cloth", WARLOCK = "Cloth",
}

-- Tier token groups (Mists: Conqueror / Protector / Vanquisher)
D.TOKEN = {
  PALADIN = "Conqueror", PRIEST = "Conqueror", WARLOCK = "Conqueror",
  WARRIOR = "Protector", HUNTER = "Protector", SHAMAN = "Protector", MONK = "Protector",
  ROGUE = "Vanquisher", DEATHKNIGHT = "Vanquisher", MAGE = "Vanquisher", DRUID = "Vanquisher",
}

D.DIFF_ID = { N = 14, H = 15, M = 16 }
-- Every difficulty that counts as Normal / Heroic / Mythic, including old 10/25/40-player raids
D.DIFF_IDS = { N = { 14, 3, 4, 9, 1 }, H = { 15, 5, 6, 2 }, M = { 16, 23, 8 } } -- Mists has no Mythic; 10/25 and flex are covered

-- Small class icon for use inside text
function D.ClassIcon(class, size)
  size = size or 14
  local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if c then
    return string.format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:%d:%d:0:0:256:256:%d:%d:%d:%d|t",
      size, size, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
  end
  return "|A:classicon-" .. class:lower() .. ":" .. size .. ":" .. size .. "|a"
end
D.DIFF_LABEL = { N = "Normal", H = "Heroic", M = "Mythic" }
D.ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

function D.ClassLabel(class)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end
