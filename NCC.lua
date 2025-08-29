-- NCC.lua (silent, sound-only, fixed)
local ADDON = ...
local f = CreateFrame("Frame")
NCCDB = NCCDB or {}

-- ===== Settings (simple) =====
local defaults = { enabled = true }
local function applyDefaults()
  NCCDB = NCCDB or {}
  for k, v in pairs(defaults) do if NCCDB[k] == nil then NCCDB[k] = v end end
end

-- ===== File paths =====
local PATH_LUST  = "Interface\\AddOns\\NCC\\media\\lust.ogg"
local PATH_RING  = "Interface\\AddOns\\NCC\\media\\finger.ogg"   -- you named it PATH_FINGER before; using PATH_RING everywhere
-- Per-group sad sounds:
local SAD_SOUND_PATHS = {
  group1 = "Interface\\AddOns\\NCC\\media\\braka_sad.ogg",
  group2 = "Interface\\AddOns\\NCC\\media\\martin_sad.ogg",
  group3 = "Interface\\AddOns\\NCC\\media\\marius_sad.ogg",
  group4 = "Interface\\AddOns\\NCC\\media\\markus_sad.ogg",
}

-- ===== Helpers =====
local function tryFile(path) return PlaySoundFile(path, "Master") or false end
local function trySoundKit(sk)
  if type(sk) == "number" then local ok = pcall(PlaySound, sk, "Master"); if ok then return true end end
  return false
end

-- Normalize early (needed by many functions)
local function NormalizeName(name)
  if not name then return nil end
  local base = name:match("^[^-]+") or name
  return base:lower()
end

-- ===== Player groups (by normalized name) =====
local PLAYER_GROUPS = {
  group1 = { "haugerbooy","pjsuka","slabedask" },
  group2 = { "dafuqzmonk","dafuqzhunt","dafuqzlock","dafuqzhauger","dafuqz","dafuqzwar","dafuqzshaman","dafuqzevoker","dafuqzdh","dafuqzsneak","dafuqzdruid","dafuqzmage","dafuqzprest" },
  group3 = { "rocketboy","boltsman","furryfaen","beefclown","smoothfuk" },
  group4 = { "trollfjert","plipp","divahauger","månki" },
}

-- Fast lookup: normalized name -> group
local nameToGroup = {}
for group, names in pairs(PLAYER_GROUPS) do
  for _, name in ipairs(names) do
    nameToGroup[NormalizeName(name)] = group
  end
end

-- Track GUIDs for grouped players who are in our tables
local guidToGroup = {}

local function UpdateTargetGUID()
  wipe(guidToGroup)
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local u = "raid"..i
      if UnitExists(u) then
        local nm = NormalizeName(GetUnitName(u, true))
        local g = nameToGroup[nm]
        if g then guidToGroup[UnitGUID(u)] = g end
      end
    end
  elseif IsInGroup() then
    for i = 1, 4 do
      local u = "party"..i
      if UnitExists(u) then
        local nm = NormalizeName(GetUnitName(u, true))
        local g = nameToGroup[nm]
        if g then guidToGroup[UnitGUID(u)] = g end
      end
    end
    -- include player
    local nm = NormalizeName(GetUnitName("player", true))
    local g = nameToGroup[nm]
    if g then guidToGroup[UnitGUID("player")] = g end
  else
    -- solo: nothing to track
  end
end

-- Build/track party names for loot checks
local partySet = {}
local function RebuildPartySet()
  wipe(partySet)
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local u = "raid"..i
      if UnitExists(u) then partySet[NormalizeName(GetUnitName(u, true))] = true end
    end
  elseif IsInGroup() then
    for i = 1, 4 do
      local u = "party"..i
      if UnitExists(u) then partySet[NormalizeName(GetUnitName(u, true))] = true end
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

-- ===== Lust SpellIDs =====
local LUST_IDS = {
  [2825]=true,[32182]=true,[80353]=true,[90355]=true,[264667]=true,[390386]=true,
  [309658]=true,[230935]=true,[178207]=true,
}

-- ===== Combat log =====
local playerGUID, lastSadAt = nil, 0

local function HandleCombatLog()
  local _, subevent,_,_,_,_,_, destGUID, destName,_,_, spellId = CombatLogGetCurrentEventInfo()

  -- Lust on YOU
  if subevent == "SPELL_AURA_APPLIED" and destGUID == playerGUID and LUST_IDS[spellId] then
    PlayLustSound()
    return
  end

  -- Death of any tracked player
  if subevent == "UNIT_DIED" then
    local now = GetTime()
    local group = guidToGroup[destGUID]
    if not group and destName then
      group = nameToGroup[NormalizeName(destName)]
    end
    if group and (now - lastSadAt > 1.5) then
      lastSadAt = now
      PlaySadSoundForGroup(group)
    end
  end
end

-- ===== Loot handlers: ring detection =====
local function IsRingItemID(itemID)
  if not itemID then return false end
  local _,_,_, equipLoc = GetItemInfoInstant(itemID)
  return equipLoc == "INVTYPE_FINGER"
end

-- Boss loot
local function OnEncounterLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
  if not InPartyDungeon() then return end
  if not playerName then return end
  local n = NormalizeName(playerName)
  if not partySet[n] then return end
  if IsRingItemID(itemID) then PlayRingSound() end
end

-- Trash/general loot
local function OnChatMsgLoot(msg, playerName)
  if not InPartyDungeon() then return end
  local who = playerName and NormalizeName(playerName) or nil
  if who and not partySet[who] then
    -- name sometimes lives inside msg in some locales, but we still parse items below
  end
  for itemID in msg:gmatch("|Hitem:(%d+):") do
    if IsRingItemID(tonumber(itemID)) then
      PlayRingSound()
      break
    end
  end
end

-- ===== Slash: on/off/toggle/test/death/group/ring =====
SLASH_NCC1 = "/ncc"
SlashCmdList["NCC"] = function(msg)
  msg = (msg and msg:lower() or "")
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
      print("|cff00ff88NCC:|r unknown group. Available groups:"); for g,_ in pairs(SAD_SOUND_PATHS) do print("  "..g) end
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
  end
end

-- ===== Events =====
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
f:RegisterEvent("CHAT_MSG_LOOT")

f:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
    applyDefaults()
    RebuildPartySet()
    UpdateTargetGUID()
    playerGUID = UnitGUID("player")
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    RebuildPartySet()
    UpdateTargetGUID()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog()
  elseif event == "ENCOUNTER_LOOT_RECEIVED" then
    OnEncounterLootReceived(...)
  elseif event == "CHAT_MSG_LOOT" then
    OnChatMsgLoot(...)
  end
end)
