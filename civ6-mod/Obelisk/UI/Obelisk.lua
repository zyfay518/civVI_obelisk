-- Obelisk: first in-game UI context prototype.
-- This file intentionally avoids gameplay changes. It only proves that the
-- overlay context can load and respond inside Civilization VI.

local AUTO_COLLAPSE_SECONDS:number = 8;
local isExpanded:boolean = false;
local collapseElapsed:number = 0;

local function LookupOrDefault(tag:string, fallback:string, ...)
  local value:string = Locale.Lookup(tag, ...);

  if value == nil or value == "" or value == tag then
    if select("#", ...) > 0 then
      local args:table = { ... };
      value = fallback;

      for index:number, replacement in ipairs(args) do
        value = string.gsub(value, "{" .. tostring(index) .. "}", tostring(replacement));
      end

      return value;
    end

    return fallback;
  end

  return value;
end

local function IsChineseUI()
  local localizedResearch:string = Locale.Lookup("LOC_TECH_TREE_CHOOSE_RESEARCH");

  if localizedResearch ~= nil and string.find(localizedResearch, "研究") ~= nil then
    return true;
  end

  local localizedWorldTracker:string = Locale.Lookup("LOC_WORLD_TRACKER_CHOOSE_RESEARCH");

  if localizedWorldTracker ~= nil and string.find(localizedWorldTracker, "研究") ~= nil then
    return true;
  end

  return false;
end

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
  local isChinese:boolean = IsChineseUI();

  local fallbackQuestion:string = "What should I inspect right now?";
  local fallbackMetrics:string = "Turn {1} · Science {2}/turn · Culture {3}/turn · Gold {4} ({5}/turn) · Cities {6}";
  local fallbackOpening:string = "Opening snapshot: you have not settled a city yet. Founding the capital is the first state change to inspect; after that Obelisk can compare science, culture, gold, and city output.";
  local fallbackWithCity:string = "Current rule check: science is {1}/turn, culture is {2}/turn, and gold flow is {3}/turn. This is a local data read, not AI yet. Next we can add city-level details and then replace this rule response with the AI Consul.";

  if isChinese then
    fallbackQuestion = "现在我应该先看什么？";
    fallbackMetrics = "回合 {1} · 科技 {2}/回合 · 文化 {3}/回合 · 金币 {4}（{5}/回合）· 城市 {6}";
    fallbackOpening = "开局快照：你还没有建立城市。第一件值得观察的状态变化是首都落城；之后 Obelisk 就可以比较科技、文化、金币和城市产出。";
    fallbackWithCity = "当前规则检查：科技为 {1}/回合，文化为 {2}/回合，金币流为 {3}/回合。这是本地数据读取，不是 AI 回复。下一步可以加入城市级细节，之后再把这段规则回复替换为 AI Consul。";
  end

  if Controls.QuestionLabel ~= nil then
    Controls.QuestionLabel:SetText(LookupOrDefault("LOC_OBELISK_SAMPLE_QUESTION", fallbackQuestion));
  end

  if Controls.MetricsLabel ~= nil then
    Controls.MetricsLabel:SetText(LookupOrDefault(
      "LOC_OBELISK_METRICS",
      fallbackMetrics,
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
    local fallbackAnswer:string = fallbackOpening;

    if snapshot.cityCount > 0 then
      answerTag = "LOC_OBELISK_RULE_ANSWER_WITH_CITY";
      fallbackAnswer = fallbackWithCity;
    end

    Controls.AnswerLabel:SetText(LookupOrDefault(answerTag, fallbackAnswer, snapshot.science, snapshot.culture, snapshot.goldPerTurn));
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
    local askFallback:string = IsChineseUI() and "询问 Obelisk..." or "Ask Obelisk...";
    Controls.AskButton:SetText(LookupOrDefault("LOC_OBELISK_ASK", askFallback));
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
