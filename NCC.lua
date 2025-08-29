-- NCC.lua (silent, sound-only)
local ADDON = ...
local f = CreateFrame("Frame")
NCCDB = NCCDB or {}

-- ===== Settings (simple) =====
local defaults = {
  enabled = true,
}

local function applyDefaults()
  NCCDB = NCCDB or {}
  for k, v in pairs(defaults) do
    if NCCDB[k] == nil then NCCDB[k] = v end
  end
end

-- ===== File paths =====
local PATH_LUST = "Interface\\\\AddOns\\\\NCC\\\\media\\\\lust.ogg"

-- Define player groups linked to sad sounds
local SAD_SOUND_PATHS = {
  group1 = "Interface\\AddOns\\NCC\\media\\braka_sad.ogg",
  group2 = "Interface\\AddOns\\NCC\\media\\martin_sad.ogg",
  group3 = "Interface\\AddOns\\NCC\\media\\marius_sad.ogg",
  group4 = "Interface\\AddOns\\NCC\\media\\markus_sad.ogg",
}

local PLAYER_GROUPS = {
  group1 = {"haugerbooy", --braka characters
            "pjsuka", 
            "slabedask"}, 
  group2 = {"dafuqzmonk",     -- martin characters
            "dafuqzhunt",
            "dafuqzlock",
            "dafuqzhauger",
            "dafuqz",
            "dafuqzwar",
            "dafuqzshaman",
            "dafuqzevoker",
            "dafuqzdh",
            "dafuqzsneak",
            "dafuqzdruid",
            "dafuqzmage",
            "dafuqzprest"},
  group3 = {"rocketboy", -- marius characters
            "boltsman", 
            "furryfaen", 
            "beefclown", 
            "smoothfuk"},
  group4 = {"trollfjert", -- markus characters
            "plipp", 
            "divahauger", 
            "månki"}
}

-- ===== Safe sound helpers =====
local function tryFile(path) return PlaySoundFile(path, "Master") or false end
local function trySoundKit(sk)
  if type(sk) == "number" then
    local ok = pcall(PlaySound, sk, "Master")
    if ok then return true end
  end
  return false
end

local function PlayLustSound()
  if not NCCDB.enabled then return end
  if tryFile(PATH_LUST) then return end
  if trySoundKit(SOUNDKIT and SOUNDKIT.READY_CHECK) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end

-- Normalize and map player names to groups
local nameToGroup = {}
for group, names in pairs(PLAYER_GROUPS) do
  for _, name in ipairs(names) do
    nameToGroup[name] = group
  end
end

-- Track GUIDs for living targets by group
local guidToGroup = {}

-- Update GUIDs for all target players in groups
local function UpdateTargetGUIDs()
  guidToGroup = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid"..i
      if UnitExists(unit) then
        local nm = NormalizeName(GetUnitName(unit, true))
        local group = nameToGroup[nm]
        if group then
          guidToGroup[UnitGUID(unit)] = group
        end
      end
    end
  elseif IsInGroup() then
    for i = 1, 4 do
      local unit = "party"..i
      if UnitExists(unit) then
        local nm = NormalizeName(GetUnitName(unit, true))
        local group = nameToGroup[nm]
        if group then
          guidToGroup[UnitGUID(unit)] = group
        end
      end
    end
    if UnitExists("player") then
      local nm = NormalizeName(GetUnitName("player", true))
      local group = nameToGroup[nm]
      if group then
        guidToGroup[UnitGUID("player")] = group
      end
    end
  end
end

-- Play the sad sound for a given group
local function PlaySadSoundForGroup(group)
  if not NCCDB.enabled then return end
  local path = SAD_SOUND_PATHS[group]
  if not path then path = "Sound\\Interface\\RaidWarning.ogg" end
  if tryFile(path) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end

-- ===== Lust SpellIDs =====
local LUST_IDS = {
  [2825]   = "Bloodlust",
  [32182]  = "Heroism",
  [80353]  = "Time Warp",
  [90355]  = "Ancient Hysteria",
  [264667] = "Primal Rage",
  [390386] = "Fury of the Aspects",
  [309658] = "Drums of Deathly Ferocity",
  [230935] = "Drums of the Mountain",
  [178207] = "Drums of Fury",
}

-- ===== Name/roster helpers =====
local function NormalizeName(name)
  if not name then return nil end
  local base = name:match("^[^-]+") or name
  return base:lower()
end

local playerGUID

-- ===== Combat log =====
local lastSadAt = 0

local function HandleCombatLog()
  local _, subevent,
        _, _, _, _, _,
        destGUID, destName, _, _,
        spellId = CombatLogGetCurrentEventInfo()

  -- Lust on YOU
  if subevent == "SPELL_AURA_APPLIED" and destGUID == playerGUID then
    if LUST_IDS[spellId] then
      PlayLustSound()
    end
    return
  end

  -- Death of tracked players
  if subevent == "UNIT_DIED" then
    local now = GetTime()
    local nameNorm = NormalizeName(destName)
    local group = nil

    group = guidToGroup[destGUID]
    if not group and nameNorm then
      group = nameToGroup[nameNorm]
    end

    if group and now - lastSadAt > 1.5 then
      lastSadAt = now
      PlaySadSoundForGroup(group)
    end
  end
end

-- ===== Slash: on/off/toggle/test/death/group tests =====
SLASH_NCC1 = "/ncc"
SlashCmdList["NCC"] = function(msg)
  msg = (msg and msg:lower() or "")
  if msg == "on" then
    NCCDB.enabled = true
    print("|cff00ff88NCC:|r enabled = true")
  elseif msg == "off" then
    NCCDB.enabled = false
    print("|cff00ff88NCC:|r enabled = false")
  elseif msg == "toggle" then
    NCCDB.enabled = not NCCDB.enabled
    print("|cff00ff88NCC:|r enabled =", NCCDB.enabled)
  elseif msg == "test" then
    print("|cff00ff88NCC:|r test lust sound")
    PlayLustSound()
  elseif msg:match("^test%s+%w+") then
    -- individual test for group sounds: /ncc test group1, group2, ...
    local _, _, group = msg:find("^test%s+(%w+)")
    if group and SAD_SOUND_PATHS[group] then
      print(string.format("|cff00ff88NCC:|r test sad sound for group '%s'", group))
      PlaySadSoundForGroup(group)
    else
      print("|cff00ff88NCC:|r unknown group. Available groups:")
      for g, _ in pairs(SAD_SOUND_PATHS) do
        print("  " .. g)
      end
    end
  elseif msg == "death" then
    print("|cff00ff88NCC:|r test sad sound for group1 (default)")
    PlaySadSoundForGroup("group1")
  else
    print("|cff00ff88NCC commands:|r")
    print("  /ncc on|off|toggle")
    print("  /ncc test             - play lust.ogg")
    print("  /ncc death            - play sad sound for group1")
    print("  /ncc test <groupname> - play sad sound for specific group")
  end
end

-- ===== Events =====
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

f:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
    applyDefaults()
    playerGUID = UnitGUID("player")
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    UpdateTargetGUIDs()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog()
  end
end)
