local f = CreateFrame("Frame")

-- Random MVP after boss
local function RandomGuildie()
  local t = {}
  for i = 1, GetNumGroupMembers() do
    local name = GetRaidRosterInfo(i)
    if name then table.insert(t, name) end
  end
  if #t == 0 then t[1] = UnitName("player") end
  return t[math.random(#t)]
end

local function OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
  if success == 1 then
    local mvp = RandomGuildie()
    SendChatMessage("🏆 MVP of " .. (encounterName or "that pull") .. ": " .. mvp .. "!", "RAID")
  else
    SendChatMessage("🎺 Womp womp… next pull is the one!", "RAID")
  end
end

-- /pizza gag
SLASH_NCCPIZZA1 = "/pizza"
SlashCmdList["NCCPIZZA"] = function(msg)
  local who = msg and strtrim(msg) ~= "" and msg or UnitName("player")
  SendChatMessage("🍕 Delivery for " .. who .. "! Extra haste, hold the mechanics.", "RAID")
end

-- /hug counter
NCCDB = NCCDB or {}
NCCDB.hugs = NCCDB.hugs or {}

SLASH_NCCHUG1 = "/hug"
SlashCmdList["NCCHUG"] = function(msg)
  local who = msg and strtrim(msg) ~= "" and msg or "everyone"
  NCCDB.hugs[who] = (NCCDB.hugs[who] or 0) + 1
  SendChatMessage("🤗 " .. UnitName("player") .. " hugs " .. who .. " (" .. NCCDB.hugs[who] .. " total)", "RAID")
end

-- Loot sparkle (epic+)
local function OnLootChat(_, text)
  if text:find("|cffa335ee") or text:find("|cffff8000") then
    PlaySound(SOUNDKIT.UI_PERSONAL_LOOT_BONUS_ROLL_REWARD, "Master")
    SendChatMessage("✨ Shiny acquired! Grats!", "RAID")
  end
end

f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", function(self, event, ...)
  if event == "ENCOUNTER_END" then
    OnEncounterEnd(...)
  elseif event == "CHAT_MSG_LOOT" then
    OnLootChat(...)
  end
end)
