-- Obelisk: first in-game UI context prototype.
-- This file intentionally avoids gameplay changes. It only proves that the
-- overlay context can load and respond inside Civilization VI.

local AUTO_COLLAPSE_SECONDS:number = 8;
local isExpanded:boolean = false;
local collapseElapsed:number = 0;

local function Round(value:number)
  return math.floor((value or 0) + 0.5);
end

local function CollectSnapshot()
  local snapshot:table = {
    turn = Game.GetCurrentGameTurn(),
    science = 0,
    culture = 0,
    goldBalance = 0,
    goldPerTurn = 0,
    cityCount = 0
  };

  local localPlayerID:number = Game.GetLocalPlayer();

  if localPlayerID == -1 or Players[localPlayerID] == nil then
    return snapshot;
  end

  local player:table = Players[localPlayerID];

  if player:GetTechs() ~= nil then
    snapshot.science = Round(player:GetTechs():GetScienceYield());
  end

  if player:GetCulture() ~= nil then
    snapshot.culture = Round(player:GetCulture():GetCultureYield());
  end

  if player:GetTreasury() ~= nil then
    local treasury:table = player:GetTreasury();
    snapshot.goldBalance = math.floor(treasury:GetGoldBalance());
    snapshot.goldPerTurn = Round(treasury:GetGoldYield() - treasury:GetTotalMaintenance());
  end

  if player:GetCities() ~= nil then
    snapshot.cityCount = player:GetCities():GetCount();
  end

  return snapshot;
end

local function RefreshAnswer()
  local snapshot:table = CollectSnapshot();

  if Controls.QuestionLabel ~= nil then
    Controls.QuestionLabel:SetText(Locale.Lookup("LOC_OBELISK_SAMPLE_QUESTION"));
  end

  if Controls.MetricsLabel ~= nil then
    Controls.MetricsLabel:SetText(Locale.Lookup(
      "LOC_OBELISK_METRICS",
      snapshot.turn,
      snapshot.science,
      snapshot.culture,
      snapshot.goldBalance,
      snapshot.goldPerTurn,
      snapshot.cityCount
    ));
  end

  if Controls.AnswerLabel ~= nil then
    local answerTag:string = "LOC_OBELISK_RULE_ANSWER_OPENING";

    if snapshot.cityCount > 0 then
      answerTag = "LOC_OBELISK_RULE_ANSWER_WITH_CITY";
    end

    Controls.AnswerLabel:SetText(Locale.Lookup(answerTag, snapshot.science, snapshot.culture, snapshot.goldPerTurn));
  end
end

local function SetExpanded(expanded:boolean)
  isExpanded = expanded;
  collapseElapsed = 0;

  if expanded then
    RefreshAnswer();
  end

  if Controls.ExpandedPanel ~= nil then
    Controls.ExpandedPanel:SetHide(not expanded);
  end

  if Controls.IdlePanel ~= nil then
    Controls.IdlePanel:SetHide(false);
  end
end

local function OnAsk()
  SetExpanded(true);
end

local function OnCollapse()
  SetExpanded(false);
end

local function Initialize()
  ContextPtr:SetHide(false);

  if Controls.AskButton ~= nil then
    Controls.AskButton:SetText(Locale.Lookup("LOC_OBELISK_ASK"));
  end

  ContextPtr:SetUpdate(function(deltaTime:number)
    if isExpanded then
      collapseElapsed = collapseElapsed + deltaTime;

      if collapseElapsed >= AUTO_COLLAPSE_SECONDS then
        SetExpanded(false);
      end
    end
  end);

  if Controls.AskButton ~= nil then
    Controls.AskButton:RegisterCallback(Mouse.eLClick, OnAsk);
  end

  if Controls.CollapseButton ~= nil then
    Controls.CollapseButton:RegisterCallback(Mouse.eLClick, OnCollapse);
  end

  SetExpanded(false);
  print("Obelisk UI context loaded.");
end

Initialize();
