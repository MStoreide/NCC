-- NCC.lua (Midnight-compatible, sound-only)
local ADDON = ...
local f = CreateFrame("Frame")
NCCDB = NCCDB or {}

-- ===== Settings =====
local defaults = { enabled = true }
local function applyDefaults()
  NCCDB = NCCDB or {}
  for k, v in pairs(defaults) do
    if NCCDB[k] == nil then
      NCCDB[k] = v
    end
  end
end

-- ===== File paths =====
local PATH_LUST            = "Interface\\AddOns\\NCC\\media\\lust.ogg"
local PATH_RING            = "Interface\\AddOns\\NCC\\media\\finger.ogg"

local SAD_SOUND_PATHS = {
  group1 = "Interface\\AddOns\\NCC\\media\\braka_sad.ogg",
  group2 = "Interface\\AddOns\\NCC\\media\\martin_sad.ogg",
  group3 = "Interface\\AddOns\\NCC\\media\\marius_sad.ogg",
  group4 = "Interface\\AddOns\\NCC\\media\\markus_sad.ogg",
  group5 = "Interface\\AddOns\\NCC\\media\\hasse_sad.ogg",
  group6 = "Interface\\AddOns\\NCC\\media\\hamrick_sad.ogg",
  group7 = "Interface\\AddOns\\NCC\\media\\kevin_sad.mp3",
  group8 = "Interface\\AddOns\\NCC\\media\\shandriz_sad.ogg",
}


-- ===== Helpers =====
local function tryFile(path)
  local ok, handle = PlaySoundFile(path, "Master")
  print("NCC debug: tryFile", path, "->", ok, handle)
  return ok
end

local function trySoundKit(sk)
  if type(sk) == "number" then
    local ok = pcall(PlaySound, sk, "Master")
    if ok then return true end
  end
  return false
end

local function NormalizeName(name)
  if not name then return nil end
  local base = name:match("^[^-]+") or name
  return base:lower()
end

-- ===== Player groups (by normalized name) =====
local PLAYER_GROUPS = {
  group1 = {"wesø","pjsuka","scailie","haugerbooy","slikkeplott","slabedask","slaskepott","klonkedonke"},
  group2 = {"dafuqzmonk","dafuqzhunt","dafuqzlock","dafuqzhauger","dafuqz","dafuqzwar","dafuqzshaman","dafuqzevoker","dafuqzdh","dafuqzsneak","dafuqzdruid","dafuqzmage","dafuqzprest"},
  group3 = {"rocketboy","boltsman","furryfaen","beefclown","smoothfuk","mugork"},
  group4 = {"trollfjert","plipp","divahauger","månki","jøssånøfyse","lupercal", "pissdoggo"},
  group5 = {"theshtwinds", "speltlompe"},
  group6 = {"dovaahki", "werloth"},
  group7 = {"hooleesheet"},
  group8 = {"shandriz"},
}

local nameToGroup = {}
for group, names in pairs(PLAYER_GROUPS) do
  for _, name in ipairs(names) do
    nameToGroup[NormalizeName(name)] = group
  end
end

-- ===== Party set (for loot checks) =====
local partySet = {}
local function RebuildPartySet()
  wipe(partySet)
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local u = "raid"..i
      if UnitExists(u) then
        partySet[NormalizeName(GetUnitName(u, true))] = true
      end
    end
  elseif IsInGroup() then
    for i = 1, 4 do
      local u = "party"..i
      if UnitExists(u) then
        partySet[NormalizeName(GetUnitName(u, true))] = true
      end
    end
    partySet[NormalizeName(GetUnitName("player", true))] = true
  else
    partySet[NormalizeName(GetUnitName("player", true))] = true
  end
end

-- ===== Sound wrappers =====
local function PlayLustSound()
  if not NCCDB.enabled then return end
  if tryFile(PATH_LUST) then return end
  if trySoundKit(SOUNDKIT and SOUNDKIT.READY_CHECK) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end

local function PlaySadSoundForGroup(group)
  if not NCCDB.enabled then return end
  local path = SAD_SOUND_PATHS[group] or "Sound\\Interface\\RaidWarning.ogg"
  if tryFile(path) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end

local function PlayRingSound()
  if not NCCDB.enabled then return end
  if tryFile(PATH_RING) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end


-- ===== Scope helper: only ring pings in 5-man dungeons =====
local function InPartyDungeon()
  local inInst, instType = IsInInstance()
  return inInst and instType == "party"
end

-- ===== Lust debuff SpellIDs (Sated/Exhaustion, non-secret in Midnight) =====
local LUST_IDS = {
  [57723]  = true, -- Exhaustion
  [57724]  = true, -- Sated
  [80354]  = true, -- Temporal Displacement
  [95809]  = true, -- Insanity (Hunter pet)
  [160455] = true, -- Fatigued (Hunter pet)
  [264689] = true, -- Fatigued (alt Hunter pet)
  [390435] = true, -- Exhaustion (new)
}

-- ===== UNIT_AURA: lust detection on player (via debuffs) =====
--local lustActive = false

-- local function HandleUnitAura(unit)
--  if unit ~= "player" then return end
--  local index = 1
--  while true do
--    local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")
--    if not aura then break end
--    local spellName = GetSpellInfo(aura.spellId)
--    if spellName and (spellName == "Sated" or spellName == "Exhaustion" or spellName == "Temporal Displacement") then
--      if not lustActive then
--        lustActive = true
--        PlayLustSound()
--      end
--      break
--    end
--    index = index + 1
--  end
--end



-- ===== UNIT_HEALTH: death detection =====
local deadPlayed = {}  -- unit token -> true once sad sound has fired for this death
local lastSadAt  = 0   -- global cooldown to avoid rapid stacking if multiple die at once

local function HandleUnitHealth(unit)
  if not UnitExists(unit) then return end
  if UnitIsDeadOrGhost(unit) then
    if not deadPlayed[unit] then
      local nm    = NormalizeName(GetUnitName(unit, true))
      local group = nameToGroup[nm]
      if group then
        local now = GetTime()
        if now - lastSadAt > 1.5 then
          lastSadAt        = now
          deadPlayed[unit] = true
          PlaySadSoundForGroup(group)
        end
      end
    end
  else
    deadPlayed[unit] = nil
  end
end

-- ===== Loot handlers: ring detection =====
local function IsRingItemID(itemID)
  if not itemID then return false end
  local _, _, _, equipLoc = GetItemInfoInstant(itemID)
  return equipLoc == "INVTYPE_FINGER"
end

local function OnEncounterLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
  if not InPartyDungeon() then return end
  if not playerName then return end
  if not partySet[NormalizeName(playerName)] then return end
  if IsRingItemID(itemID) then PlayRingSound() end
end

local function OnChatMsgLoot(msg, playerName)
  if not InPartyDungeon() then return end
  for itemID in msg:gmatch("|Hitem:(%d+):") do
    if IsRingItemID(tonumber(itemID)) then
      PlayRingSound()
      break
    end
  end
end

SLASH_NCC1 = "/ncc"
SlashCmdList["NCC"] = function(msg)
  print("NCC debug: raw msg:", msg)
  msg = (msg and msg:lower() or "")
  if msg == "groups" then
    print("|cff00ff88NCC:|r Available NCC groups:")
    for group, members in pairs(PLAYER_GROUPS) do
      print("  "..group..": "..table.concat(members, ", "))
    end
    return
  elseif msg:match("^add%s+[%w%-_]+%s+group%d$") then
    local name, group = msg:match("^add%s+([%w%-_]+)%s+(group%d)$")
    if not name or not group then
      print("|cff00ff88NCC:|r Usage: /ncc add <name> <group>")
      return
    end
    if not PLAYER_GROUPS[group] then
      print("|cff00ff88NCC:|r Group '"..group.."' does not exist.")
      return
    end
    -- Normalize name and check if already present
    local normName = NormalizeName(name)
    for _, existing in ipairs(PLAYER_GROUPS[group]) do
      if NormalizeName(existing) == normName then
        print("|cff00ff88NCC:|r Name '"..name.."' is already in "..group..".")
        return
      end
    end
    table.insert(PLAYER_GROUPS[group], name)
    nameToGroup[normName] = group
    print("|cff00ff88NCC:|r Added '"..name.."' to "..group..".")
    return
  end
  if msg == "on" then
    NCCDB.enabled = true;  print("|cff00ff88NCC:|r enabled = true")
  elseif msg == "off" then
    NCCDB.enabled = false; print("|cff00ff88NCC:|r enabled = false")
  elseif msg == "toggle" then
    NCCDB.enabled = not NCCDB.enabled; print("|cff00ff88NCC:|r enabled =", NCCDB.enabled)
  elseif msg == "test" then
    print("|cff00ff88NCC:|r test lust sound"); PlayLustSound()
  elseif msg == "death" then
    print("|cff00ff88NCC:|r test sad sound for group1"); PlaySadSoundForGroup("group1")
  elseif msg:match("^test%s+%w+") then
    local grp = msg:match("^test%s+(%w+)")
    if grp and SAD_SOUND_PATHS[grp] then
      print(string.format("|cff00ff88NCC:|r test sad sound for group '%s'", grp))
      PlaySadSoundForGroup(grp)
    else
      print("|cff00ff88NCC:|r unknown group. Available groups:")
      for g in pairs(SAD_SOUND_PATHS) do
        print("  "..g)
      end
    end
  elseif msg == "ring" then
    print("|cff00ff88NCC:|r test ring sound"); PlayRingSound()
  else
    print("|cff00ff88NCC commands:|r")
    print("  /ncc on|off|toggle")
    print("  /ncc test             - play lust.ogg")
    print("  /ncc death            - play sad sound for group1")
    print("  /ncc test <groupname> - play sad sound for specific group")
    print("  /ncc ring             - play finger.ogg")
    print("  /ncc groups           - list NCC groups and members")
    print("  /ncc add <name> <group> - add a name to a group (e.g., /ncc add Bob group1)")
    print("  /ncc spiritlink       - play spirit_link.ogg")
    print("  /ncc tod              - play touch_of_death.ogg")
  end
end

-- ===== Events =====
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
f:RegisterEvent("CHAT_MSG_LOOT")

f:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
    applyDefaults()
    RebuildPartySet()
    wipe(deadPlayed)
    lustActive = false
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    RebuildPartySet()
    wipe(deadPlayed)
  elseif event == "UNIT_HEALTH" then
    HandleUnitHealth(...)
  elseif event == "ENCOUNTER_LOOT_RECEIVED" then
    OnEncounterLootReceived(...)
  elseif event == "CHAT_MSG_LOOT" then
    OnChatMsgLoot(...)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    HandleUnitSpellcastSucceeded(...)
  end
end)