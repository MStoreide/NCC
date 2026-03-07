-- NCC.lua (Midnight-compatible, sound-only)
local ADDON = ...
local f = CreateFrame("Frame")
NCCDB = NCCDB or {}

local NCC_PREFIX = "NCC_SYNC"
C_ChatInfo.RegisterAddonMessagePrefix(NCC_PREFIX)


-- ===== Settings =====
local defaults = { enabled = true, customNames = {}, debug = false }
local function applyDefaults()
  NCCDB = NCCDB or {}
  for k, v in pairs(defaults) do
    if NCCDB[k] == nil then
      if type(v) == "table" then
        NCCDB[k] = {}
      else
        NCCDB[k] = v
      end
    end
  end
end


-- ===== File paths =====
local PATH_LUST        = "Interface\\AddOns\\NCC\\media\\lust.ogg"
local PATH_RING        = "Interface\\AddOns\\NCC\\media\\finger.ogg"
local PATH_PULL_START  = "Interface\\AddOns\\NCC\\media\\pull_start.mp3"
local PATH_PULL_END    = "Interface\\AddOns\\NCC\\media\\beastlong.mp3"
local PATH_COUNTDOWN = {
  [5] = "Interface\\AddOns\\NCC\\media\\5.ogg",
  [4] = "Interface\\AddOns\\NCC\\media\\4.ogg",
  [3] = "Interface\\AddOns\\NCC\\media\\3.ogg",
  [2] = "Interface\\AddOns\\NCC\\media\\2.ogg",
  [1] = "Interface\\AddOns\\NCC\\media\\1.ogg",
}


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
  if NCCDB.debug then print("NCC debug: tryFile", path, "->", ok, handle) end
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
  local ok, result = pcall(function()
    local base = string.match(name, "^[^-]+") or name
    return string.lower(base)
  end)
  if ok then return result end
  return nil
end


-- ===== Player groups (by normalized name) =====
local PLAYER_GROUPS = {
  group1 = {"wesø","pjsuka","scailie","haugerbooy","slikkeplott","slabedask","slaskepott","klonkedonke"},
  group2 = {"dafuqzmonk","dafuqzhunt","dafuqzlock","dafuqzhauger","dafuqz","dafuqzwar","dafuqzshaman","dafuqzevoker","dafuqzdh","dafuqzsneak","dafuqzdruid","dafuqzmage","dafuqzprest"},
  group3 = {"rocketboy","boltsman","furryfaen","beefclown","smoothfuk","mugork"},
  group4 = {"trollfjert","plipp","divahauger","månki","jøssånøfyse","lupercal","pissdoggo"},
  group5 = {"theshtwinds","speltlompe"},
  group6 = {"dovaahki","werloth"},
  group7 = {"hooleesheet"},
  group8 = {"shandriz"},
}


local nameToGroup = {}
for group, names in pairs(PLAYER_GROUPS) do
  for _, name in ipairs(names) do
    nameToGroup[NormalizeName(name)] = group
  end
end

local function LoadCustomNames()
  if not NCCDB or not NCCDB.customNames then return end
  for _, entry in ipairs(NCCDB.customNames) do
    local name, group = entry.name, entry.group
    if PLAYER_GROUPS[group] then
      local normName = NormalizeName(name)
      if not nameToGroup[normName] then
        table.insert(PLAYER_GROUPS[group], name)
        nameToGroup[normName] = group
      end
    end
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


local function PlayPullStartSound()
  if not NCCDB.enabled then return end
  if tryFile(PATH_PULL_START) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end


local function PlayPullEndSound()
  if not NCCDB.enabled then return end
  if tryFile(PATH_PULL_END) then return end
  PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
end


local function PlayCountdownTick(num)
  if not NCCDB.enabled then return end
  local path = PATH_COUNTDOWN[num]
  if path then tryFile(path) end
end


-- ===== Scope helper: only ring pings in 5-man dungeons =====
local function InPartyDungeon()
  local inInst, instType = IsInInstance()
  return inInst and instType == "party"
end


-- ===== Lust debuff SpellIDs =====
local LUST_IDS = {
  [57723]  = true, -- Exhaustion
  [57724]  = true, -- Sated
  [80354]  = true, -- Temporal Displacement
  [95809]  = true, -- Insanity (Hunter pet)
  [160455] = true, -- Fatigued (Hunter pet)
  [264689] = true, -- Fatigued (alt Hunter pet)
  [390435] = true, -- Exhaustion (new)
}


-- ===== UNIT_HEALTH: death detection =====
local deadPlayed = {}
local lastSadAt  = 0


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


-- ===== Pull Timer (On-Screen Countdown) =====
local pullTicker = nil
local pullFrame  = nil


local function CreatePullFrame()
  if pullFrame then return end

  pullFrame = CreateFrame("Frame", "NCCPullFrame", UIParent)
  pullFrame:SetSize(512, 256)
  pullFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  pullFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  pullFrame:Hide()

  local text = pullFrame:CreateFontString(nil, "OVERLAY")
  text:SetFont("Fonts\\FRIZQT__.TTF", 120, "THICKOUTLINE")
  text:SetPoint("CENTER", pullFrame, "CENTER", 0, 0)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  pullFrame.text = text
end


local function ShowCountdown(num)
  if not pullFrame then CreatePullFrame() end
  pullFrame.text:SetText(tostring(num))
  pullFrame:Show()
  pullFrame:SetAlpha(1)

  if type(num) == "number" and num <= 3 then
    pullFrame.text:SetTextColor(1, 0.2, 0.2, 1)  -- Red
  elseif num == "GO" then
    pullFrame.text:SetTextColor(0.2, 1, 0.2, 1)  -- Green
  else
    pullFrame.text:SetTextColor(1, 1, 1, 1)       -- White
  end
end


local function HideCountdown()
  if not pullFrame then return end
  if not pullFrame:IsShown() then return end
  pullFrame.text:SetText("")
  UIFrameFadeOut(pullFrame, 0.8, 1, 0)
  C_Timer.After(0.8, function()
    if pullFrame then pullFrame:Hide() end
  end)
end


local function CancelPullTimer()
  if pullTicker then
    pullTicker:Cancel()
    pullTicker = nil
  end
  HideCountdown()
end


local function SendPullSync(seconds)
  if not IsInGroup() and not IsInRaid() then return end
  local channel = IsInRaid() and "RAID" or "PARTY"
  C_ChatInfo.SendAddonMessage(NCC_PREFIX, "PULL:" .. seconds, channel)
end

local function SendCancelSync()
  if not IsInGroup() and not IsInRaid() then return end
  local channel = IsInRaid() and "RAID" or "PARTY"
  C_ChatInfo.SendAddonMessage(NCC_PREFIX, "CANCEL", channel)
end


local function StartPullTimer(seconds, isInitiator)
  CancelPullTimer()
  if not NCCDB.enabled then return end

  local remaining = seconds
  print(string.format("|cff00ff88NCC:|r Pull timer started: %d seconds", seconds))

  local chatType = nil
  if isInitiator then
    chatType = IsInRaid() and "RAID_WARNING" or (IsInGroup() and "PARTY" or nil)
  end
  if chatType then SendChatMessage("Pull in " .. remaining .. "s", chatType) end

  PlayPullStartSound()
  ShowCountdown(remaining)

  pullTicker = C_Timer.NewTicker(1, function()
    remaining = remaining - 1
    if remaining > 0 then
      ShowCountdown(remaining)
      if remaining <= 5 then
        PlayCountdownTick(remaining)
      end
      if remaining % 10 == 0 or remaining <= 5 then
        print(string.format("|cff00ff88NCC:|r Pull in %ds", remaining))
        if chatType then SendChatMessage("Pull in " .. remaining .. "s", chatType) end
      end
    else
      ShowCountdown("GO")
      print("|cffff4444NCC:|r >> PULL NOW <<")
      if chatType then SendChatMessage(">> PULL NOW <<", chatType) end
      PlayPullEndSound()
      pullTicker:Cancel()
      pullTicker = nil
      C_Timer.After(1.2, HideCountdown)
    end
  end)
end


-- ===== Slash Commands =====
SLASH_NCC1 = "/ncc"
SlashCmdList["NCC"] = function(msg)
  if NCCDB.debug then print("NCC debug: raw msg:", msg) end
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
    local normName = NormalizeName(name)
    for _, existing in ipairs(PLAYER_GROUPS[group]) do
      if NormalizeName(existing) == normName then
        print("|cff00ff88NCC:|r Name '"..name.."' is already in "..group..".")
        return
      end
    end
    table.insert(PLAYER_GROUPS[group], name)
    nameToGroup[normName] = group
    table.insert(NCCDB.customNames, { name = name, group = group })
    print("|cff00ff88NCC:|r Added '"..name.."' to "..group.." (saved).")
    return

  elseif msg == "on" then
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
      for g in pairs(SAD_SOUND_PATHS) do print("  "..g) end
    end
  elseif msg == "ring" then
    print("|cff00ff88NCC:|r test ring sound"); PlayRingSound()

  elseif msg == "pull" then
    StartPullTimer(10, true)
    SendPullSync(10)
  elseif msg:match("^pull%s+%d+$") then
    local secs = tonumber(msg:match("^pull%s+(%d+)$"))
    if secs and secs > 0 and secs <= 60 then
      StartPullTimer(secs, true)
      SendPullSync(secs)
    else
      print("|cff00ff88NCC:|r Pull timer must be between 1 and 60 seconds.")
    end
  elseif msg == "pull cancel" or msg == "pullcancel" then
    CancelPullTimer()
    SendCancelSync()
    print("|cff00ff88NCC:|r Pull timer cancelled.")

  elseif msg == "debug" then
    NCCDB.debug = not NCCDB.debug
    print(string.format("|cff00ff88NCC:|r Debug mode: %s", NCCDB.debug and "ON" or "OFF"))

  else
    print("|cff00ff88NCC commands:|r")
    print("  /ncc on|off|toggle")
    print("  /ncc test                  - play lust.ogg")
    print("  /ncc death                 - play sad sound for group1")
    print("  /ncc test <groupname>      - play sad sound for specific group")
    print("  /ncc ring                  - play finger.ogg")
    print("  /ncc groups                - list NCC groups and members")
    print("  /ncc add <name> <group>    - add a name to a group")
    print("  /ncc pull [seconds]        - start pull timer (default 10s, max 60s)")
    print("  /ncc pull cancel           - cancel active pull timer")
    print("  /ncc debug                 - toggle debug output")
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
f:RegisterEvent("CHAT_MSG_ADDON")


f:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
    applyDefaults()
    LoadCustomNames()
    RebuildPartySet()
    wipe(deadPlayed)
    CancelPullTimer()
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    RebuildPartySet()
    wipe(deadPlayed)
  elseif event == "UNIT_HEALTH" then
    HandleUnitHealth(...)
  elseif event == "ENCOUNTER_LOOT_RECEIVED" then
    OnEncounterLootReceived(...)
  elseif event == "CHAT_MSG_LOOT" then
    OnChatMsgLoot(...)
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    if prefix == NCC_PREFIX then
      local myName = GetUnitName("player", true)
      if Ambiguate(sender, "short") == Ambiguate(myName, "short") then return end
      local cmd, arg = string.match(message, "^(%a+):?(%d*)$")
      if cmd == "PULL" and tonumber(arg) then
        local secs = tonumber(arg)
        if secs > 0 and secs <= 60 then
          print(string.format("|cff00ff88NCC:|r Pull timer synced from %s: %ds", sender, secs))
          StartPullTimer(secs)
        end
      elseif cmd == "CANCEL" then
        print(string.format("|cff00ff88NCC:|r Pull timer cancelled by %s", sender))
        CancelPullTimer()
      end
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    HandleUnitSpellcastSucceeded(...)
  end
end)
