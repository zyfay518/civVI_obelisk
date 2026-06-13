-- Obelisk: first in-game UI context prototype.
-- This file intentionally avoids gameplay changes. It only proves that the
-- overlay context can load and respond inside Civilization VI.

local AUTO_COLLAPSE_SECONDS:number = 20;
local MAX_JOURNAL_ENTRIES:number = 12;
local JOURNAL_PROPERTY_KEY:string = "OBELISK_JOURNAL_V1";
local isExpanded:boolean = false;
local collapseElapsed:number = 0;
local currentMode:string = "data";
local journal:table = {};
local journalSequence:number = 0;
local persistedEntryCount:number = 0;
local persistenceLoadStatus:string = "not_checked";
local persistenceSaveStatus:string = "not_checked";

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

local function FormatDelta(value:number)
  if value == nil then
    return "0";
  end

  if value > 0 then
    return "+" .. tostring(value);
  end

  return tostring(value);
end

local function SafeText(value, fallback:string)
  if value == nil or value == "" then
    return fallback;
  end

  return tostring(value);
end

local function SafeCall(fallback, callback)
  local success:boolean, value = pcall(callback);

  if success and value ~= nil then
    return value;
  end

  return fallback;
end

local function AuditStatus(value, isChinese:boolean)
  if value == nil then
    return isChinese and "缺口" or "gap";
  end

  return isChinese and "已读" or "read";
end

local function AuditValue(value, fallback:string)
  if value == nil then
    return fallback;
  end

  return tostring(value);
end

local function StatusText(value, isChinese:boolean)
  local status:string = SafeText(value, "unknown");

  if not isChinese then
    return status;
  end

  if status == "saved" then
    return "saved（已写入）";
  elseif status == "loaded" then
    return "loaded（已读回）";
  elseif status == "loaded_legacy" then
    return "loaded_legacy（读到旧格式）";
  elseif status == "empty" then
    return "empty（没有旧记录）";
  elseif status == "unavailable" then
    return "unavailable（接口不可用）";
  elseif status == "save_failed" then
    return "save_failed（写入失败）";
  elseif status == "load_failed" then
    return "load_failed（读取失败）";
  elseif status == "not_checked" then
    return "not_checked（未检查）";
  end

  return status;
end

local function GetLocalPlayerObject()
  local localPlayerID:number = Game.GetLocalPlayer();

  if localPlayerID == -1 or Players[localPlayerID] == nil then
    return nil;
  end

  return Players[localPlayerID];
end

local function LookupProductionName(productionHash:number)
  if productionHash == nil or productionHash == 0 then
    return "-";
  end

  for row in GameInfo.Units() do
    if row.Hash == productionHash then
      return Locale.Lookup(row.Name);
    end
  end

  for row in GameInfo.Buildings() do
    if row.Hash == productionHash then
      return Locale.Lookup(row.Name);
    end
  end

  for row in GameInfo.Districts() do
    if row.Hash == productionHash then
      return Locale.Lookup(row.Name);
    end
  end

  for row in GameInfo.Projects() do
    if row.Hash == productionHash then
      return Locale.Lookup(row.Name);
    end
  end

  return "-";
end

local function EncodeJournalProbe()
  local lastEntry:table = #journal > 0 and journal[#journal] or nil;
  local lastTurn:string = lastEntry ~= nil and tostring(lastEntry.turn or "-") or "-";
  local lastReason:string = lastEntry ~= nil and tostring(lastEntry.reason or "-") or "-";

  return "v1|" ..
    tostring(Game.GetCurrentGameTurn()) .. "|" ..
    tostring(journalSequence) .. "|" ..
    tostring(#journal) .. "|" ..
    lastTurn .. "|" ..
    lastReason;
end

local function DecodeJournalProbe(payload:string)
  local parts:table = {};

  for part in string.gmatch(payload or "", "([^|]+)") do
    table.insert(parts, part);
  end

  return {
    version = parts[1],
    savedAtTurn = tonumber(parts[2]) or -1,
    savedSequence = tonumber(parts[3]) or 0,
    entryCount = tonumber(parts[4]) or 0,
    lastTurn = parts[5] or "-",
    lastReason = parts[6] or "-"
  };
end

local function PersistJournal()
  local player:table = GetLocalPlayerObject();

  if player == nil or player.SetProperty == nil then
    persistenceSaveStatus = "unavailable";
    return false;
  end

  local payload:string = EncodeJournalProbe();

  local success:boolean = pcall(function()
    player:SetProperty(JOURNAL_PROPERTY_KEY, payload);
  end);

  if success then
    persistedEntryCount = #journal;
    persistenceSaveStatus = "saved";
    return true;
  end

  persistenceSaveStatus = "save_failed";
  return false;
end

local function LoadPersistedJournal()
  local player:table = GetLocalPlayerObject();

  if player == nil or player.GetProperty == nil then
    persistenceLoadStatus = "unavailable";
    return;
  end

  local success:boolean, payload = pcall(function()
    return player:GetProperty(JOURNAL_PROPERTY_KEY);
  end);

  if not success then
    persistenceLoadStatus = "load_failed";
    return;
  end

  if payload == nil or payload == "" then
    persistenceLoadStatus = "empty";
    return;
  end

  if type(payload) ~= "string" then
    persistenceLoadStatus = "loaded_legacy";
    return;
  end

  local decoded:table = DecodeJournalProbe(payload);

  if decoded.savedSequence > journalSequence then
    journalSequence = decoded.savedSequence;
  end

  persistedEntryCount = decoded.entryCount;
  persistenceLoadStatus = "loaded";
end

local function CollectSnapshot()
  local snapshot:table = {
    turn = Game.GetCurrentGameTurn(),
    science = 0,
    culture = 0,
    goldBalance = 0,
    goldPerTurn = 0,
    cityCount = 0,
    firstCityName = "-",
    firstCityPopulation = 0,
    firstCityProduction = "-",
    firstCityProductionTurns = -1,
    cities = {},
    faithBalance = nil,
    faithPerTurn = nil,
    tourism = nil,
    score = nil,
    militaryStrength = nil,
    resourceCount = nil,
    resourceSamples = {},
    unitCount = nil,
    unitSamples = {},
    metCivilizations = nil,
    governmentName = nil,
    policySlotCount = nil,
    policyCards = {},
    currentTech = "-",
    currentTechTurns = -1,
    currentCivic = "-",
    currentCivicTurns = -1
  };

  local player:table = GetLocalPlayerObject();

  if player == nil then
    return snapshot;
  end

  if player:GetTechs() ~= nil then
    local techs:table = player:GetTechs();
    snapshot.science = Round(techs:GetScienceYield());

    local techID:number = techs:GetResearchingTech();

    if techID ~= -1 and GameInfo.Technologies[techID] ~= nil then
      snapshot.currentTech = Locale.Lookup(GameInfo.Technologies[techID].Name);
      snapshot.currentTechTurns = techs:GetTurnsLeft();
    end
  end

  if player:GetCulture() ~= nil then
    local culture:table = player:GetCulture();
    snapshot.culture = Round(culture:GetCultureYield());

    local civicID:number = culture:GetProgressingCivic();

    if civicID ~= -1 and GameInfo.Civics[civicID] ~= nil then
      snapshot.currentCivic = Locale.Lookup(GameInfo.Civics[civicID].Name);
      snapshot.currentCivicTurns = culture:GetTurnsLeft();
    end

    local governmentID:number = SafeCall(-1, function() return culture:GetCurrentGovernment(); end);

    if governmentID ~= -1 and GameInfo.Governments[governmentID] ~= nil then
      snapshot.governmentName = Locale.Lookup(GameInfo.Governments[governmentID].Name);
    end

    local policySlotCount:number = SafeCall(nil, function() return culture:GetNumPolicySlots(); end);

    if policySlotCount ~= nil then
      snapshot.policySlotCount = policySlotCount;

      for slotIndex:number = 0, policySlotCount - 1 do
        local policyID:number = SafeCall(-1, function() return culture:GetSlotPolicy(slotIndex); end);
        local slotTypeID:number = SafeCall(-1, function() return culture:GetSlotType(slotIndex); end);
        local slotName:string = "-";

        if slotTypeID ~= -1 and GameInfo.GovernmentSlots[slotTypeID] ~= nil then
          slotName = Locale.Lookup(GameInfo.GovernmentSlots[slotTypeID].Name);
        end

        if policyID ~= -1 and GameInfo.Policies[policyID] ~= nil then
          table.insert(snapshot.policyCards, slotName .. "：" .. Locale.Lookup(GameInfo.Policies[policyID].Name));
        end
      end
    end
  end

  if player:GetTreasury() ~= nil then
    local treasury:table = player:GetTreasury();
    snapshot.goldBalance = math.floor(treasury:GetGoldBalance());
    snapshot.goldPerTurn = Round(treasury:GetGoldYield() - treasury:GetTotalMaintenance());
  end

  if player:GetReligion() ~= nil then
    local religion:table = player:GetReligion();
    snapshot.faithBalance = SafeCall(nil, function() return Round(religion:GetFaithBalance()); end);
    snapshot.faithPerTurn = SafeCall(nil, function() return Round(religion:GetFaithYield()); end);
  end

  if player:GetStats() ~= nil then
    local stats:table = player:GetStats();
    snapshot.tourism = SafeCall(nil, function() return Round(stats:GetTourism()); end);
    snapshot.militaryStrength = SafeCall(nil, function() return Round(stats:GetMilitaryStrength()); end);
  end

  snapshot.score = SafeCall(nil, function() return Round(player:GetScore()); end);

  if player:GetResources() ~= nil then
    local resources:table = player:GetResources();
    local resourceCount:number = 0;

    for resource in GameInfo.Resources() do
      if resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_ARTIFACT" then
        local amount:number = SafeCall(0, function() return resources:GetResourceAmount(resource.ResourceType); end);

        if amount > 0 then
          resourceCount = resourceCount + 1;

          if #snapshot.resourceSamples < 5 then
            table.insert(snapshot.resourceSamples, Locale.Lookup(resource.Name) .. " " .. tostring(amount));
          end
        end
      end
    end

    snapshot.resourceCount = resourceCount;
  end

  if player:GetUnits() ~= nil then
    local units:table = player:GetUnits();
    local unitCount:number = 0;

    for _, unit in units:Members() do
      unitCount = unitCount + 1;

      if #snapshot.unitSamples < 5 then
        local unitType:number = SafeCall(-1, function() return unit:GetType(); end);
        local unitName:string = "-";

        if unitType ~= -1 and GameInfo.Units[unitType] ~= nil then
          unitName = Locale.Lookup(GameInfo.Units[unitType].Name);
        end

        table.insert(snapshot.unitSamples, unitName);
      end
    end

    snapshot.unitCount = unitCount;
  end

  if player:GetDiplomacy() ~= nil then
    local diplomacy:table = player:GetDiplomacy();
    local metCount:number = 0;

    for playerID:number = 0, 63 do
      if playerID ~= Game.GetLocalPlayer() and Players[playerID] ~= nil then
        local hasMet:boolean = SafeCall(false, function() return diplomacy:HasMet(playerID); end);

        if hasMet then
          metCount = metCount + 1;
        end
      end
    end

    snapshot.metCivilizations = metCount;
  end

  if player:GetCities() ~= nil then
    local cities:table = player:GetCities();
    snapshot.cityCount = cities:GetCount();
    local cityIndex:number = 0;

    for _, city in cities:Members() do
      cityIndex = cityIndex + 1;
      local citySnapshot:table = {
        name = Locale.Lookup(city:GetName()),
        population = 0,
        production = "-",
        productionTurns = -1,
        food = nil,
        foodSurplus = nil,
        housing = nil,
        amenities = nil,
        amenitiesNeeded = nil,
        yields = {}
      };

      citySnapshot.population = SafeCall(0, function() return city:GetPopulation(); end);
      citySnapshot.yields.food = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.FOOD)); end);
      citySnapshot.yields.production = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.PRODUCTION)); end);
      citySnapshot.yields.science = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.SCIENCE)); end);
      citySnapshot.yields.culture = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.CULTURE)); end);
      citySnapshot.yields.gold = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.GOLD)); end);

      if city:GetGrowth() ~= nil then
        local growth:table = city:GetGrowth();
        citySnapshot.food = SafeCall(nil, function() return Round(growth:GetFood()); end);
        citySnapshot.foodSurplus = SafeCall(nil, function() return Round(growth:GetFoodSurplus()); end);
        citySnapshot.housing = SafeCall(nil, function() return Round(growth:GetHousing()); end);
        citySnapshot.amenities = SafeCall(nil, function() return growth:GetAmenities(); end);
        citySnapshot.amenitiesNeeded = SafeCall(nil, function() return growth:GetAmenitiesNeeded(); end);
      end

      if city:GetBuildQueue() ~= nil then
        local buildQueue:table = city:GetBuildQueue();
        citySnapshot.productionTurns = buildQueue:GetTurnsLeft();

        if buildQueue:GetCurrentProductionTypeHash() ~= nil then
          citySnapshot.production = LookupProductionName(buildQueue:GetCurrentProductionTypeHash());
        end
      end

      table.insert(snapshot.cities, citySnapshot);

      if cityIndex == 1 then
        snapshot.firstCityName = citySnapshot.name;
        snapshot.firstCityPopulation = citySnapshot.population;
        snapshot.firstCityProduction = citySnapshot.production;
        snapshot.firstCityProductionTurns = citySnapshot.productionTurns;
      end
    end
  end

  return snapshot;
end

local function RecordSnapshot(reason:string)
  local snapshot:table = CollectSnapshot();
  journalSequence = journalSequence + 1;
  snapshot.reason = reason or "manual";
  snapshot.sequence = journalSequence;
  table.insert(journal, snapshot);

  while #journal > MAX_JOURNAL_ENTRIES do
    table.remove(journal, 1);
  end

  PersistJournal();
  return snapshot;
end

local function FindPreviousTurnSnapshot(currentTurn:number)
  for index:number = #journal, 1, -1 do
    local snapshot:table = journal[index];

    if snapshot.turn ~= nil and snapshot.turn < currentTurn then
      return snapshot;
    end
  end

  return nil;
end

local function BuildDataAnswer(snapshot:table, isChinese:boolean)
  if isChinese then
    return "数据快照：[NEWLINE]" ..
      "城市：" .. snapshot.firstCityName .. "（人口 " .. tostring(snapshot.firstCityPopulation) .. "）[NEWLINE]" ..
      "生产：" .. snapshot.firstCityProduction .. "（剩余 " .. tostring(snapshot.firstCityProductionTurns) .. " 回合）[NEWLINE]" ..
      "科技：" .. snapshot.currentTech .. "（剩余 " .. tostring(snapshot.currentTechTurns) .. " 回合）[NEWLINE]" ..
      "市政：" .. snapshot.currentCivic .. "（剩余 " .. tostring(snapshot.currentCivicTurns) .. " 回合）";
  end

  return "Data snapshot:[NEWLINE]" ..
    "City: " .. snapshot.firstCityName .. " (population " .. tostring(snapshot.firstCityPopulation) .. ")[NEWLINE]" ..
    "Production: " .. snapshot.firstCityProduction .. " (" .. tostring(snapshot.firstCityProductionTurns) .. " turns left)[NEWLINE]" ..
    "Tech: " .. snapshot.currentTech .. " (" .. tostring(snapshot.currentTechTurns) .. " turns left)[NEWLINE]" ..
    "Civic: " .. snapshot.currentCivic .. " (" .. tostring(snapshot.currentCivicTurns) .. " turns left)";
end

local function BuildCitiesAnswer(snapshot:table, isChinese:boolean)
  if snapshot.cityCount <= 0 or snapshot.cities == nil or #snapshot.cities <= 0 then
    if isChinese then
      return "城市总览：[NEWLINE]当前还没有可读取的城市。";
    end

    return "City overview:[NEWLINE]No readable cities yet.";
  end

  local lines:table = {};
  local maxLines:number = math.min(#snapshot.cities, 6);

  if isChinese then
    table.insert(lines, "城市总览：共 " .. tostring(snapshot.cityCount) .. " 座城市。");

    for index:number = 1, maxLines do
      local city:table = snapshot.cities[index];
      table.insert(lines, tostring(index) .. ". " .. city.name .. "：人口 " .. tostring(city.population) .. "，生产“" .. city.production .. "”，剩余 " .. tostring(city.productionTurns) .. " 回合。");
    end

    if #snapshot.cities > maxLines then
      table.insert(lines, "另有 " .. tostring(#snapshot.cities - maxLines) .. " 座城市未在面板中展开。");
    end

    return table.concat(lines, "[NEWLINE]");
  end

  table.insert(lines, "City overview: " .. tostring(snapshot.cityCount) .. " cities.");

  for index:number = 1, maxLines do
    local city:table = snapshot.cities[index];
    table.insert(lines, tostring(index) .. ". " .. city.name .. ": population " .. tostring(city.population) .. ", producing " .. city.production .. ", " .. tostring(city.productionTurns) .. " turns left.");
  end

  if #snapshot.cities > maxLines then
    table.insert(lines, tostring(#snapshot.cities - maxLines) .. " more cities are not expanded in this panel.");
  end

  return table.concat(lines, "[NEWLINE]");
end

local function BuildAuditAnswer(snapshot:table, isChinese:boolean)
  local lines:table = {};
  local resourceSample:string = (#snapshot.resourceSamples > 0) and table.concat(snapshot.resourceSamples, "、") or "-";
  local unitSample:string = (#snapshot.unitSamples > 0) and table.concat(snapshot.unitSamples, "、") or "-";
  local policySample:string = (#snapshot.policyCards > 0) and table.concat(snapshot.policyCards, "、") or "-";
  local firstCity:table = (#snapshot.cities > 0) and snapshot.cities[1] or nil;
  local cityDetail:string = "-";

  if firstCity ~= nil then
    cityDetail = firstCity.name ..
      " 人口" .. tostring(firstCity.population) ..
      " 食物" .. AuditValue(firstCity.foodSurplus, "?") ..
      " 住房" .. AuditValue(firstCity.housing, "?") ..
      " 宜居" .. AuditValue(firstCity.amenities, "?") .. "/" .. AuditValue(firstCity.amenitiesNeeded, "?") ..
      " 产能" .. AuditValue(firstCity.yields.production, "?");
  end

  if isChinese then
    table.insert(lines, "数据体检：下面是 Obelisk 现在能直接读到的数据域。");
    table.insert(lines, "玩家产出：科技/文化/金币已读；信仰 " .. AuditStatus(snapshot.faithPerTurn, true) .. "，旅游 " .. AuditStatus(snapshot.tourism, true) .. "，军力 " .. AuditStatus(snapshot.militaryStrength, true) .. "，分数 " .. AuditStatus(snapshot.score, true) .. "。");
    table.insert(lines, "城市细节：" .. cityDetail .. "。");
    table.insert(lines, "全城列表：已读 " .. tostring(#snapshot.cities) .. "/" .. tostring(snapshot.cityCount) .. "；资源 " .. AuditStatus(snapshot.resourceCount, true) .. " " .. AuditValue(snapshot.resourceCount, "?") .. " 类：" .. resourceSample .. "。");
    table.insert(lines, "单位：" .. AuditStatus(snapshot.unitCount, true) .. " " .. AuditValue(snapshot.unitCount, "?") .. " 个：" .. unitSample .. "；外交已见文明 " .. AuditValue(snapshot.metCivilizations, "?") .. "。");
    table.insert(lines, "政体/政策：" .. AuditValue(snapshot.governmentName, "?") .. "；槽位 " .. AuditValue(snapshot.policySlotCount, "?") .. "；已挂 " .. tostring(#snapshot.policyCards) .. "：" .. policySample .. "。");
    table.insert(lines, "已知缺口：地块级可见收益、详细外交关系、胜利进度还没有进入本面板。");
    return table.concat(lines, "[NEWLINE]");
  end

  table.insert(lines, "Data audit: readable domains in this build.");
  table.insert(lines, "Player yields: science/culture/gold read; faith " .. AuditStatus(snapshot.faithPerTurn, false) .. ", tourism " .. AuditStatus(snapshot.tourism, false) .. ", military " .. AuditStatus(snapshot.militaryStrength, false) .. ", score " .. AuditStatus(snapshot.score, false) .. ".");
  table.insert(lines, "City detail: " .. cityDetail .. ".");
  table.insert(lines, "Cities: read " .. tostring(#snapshot.cities) .. "/" .. tostring(snapshot.cityCount) .. "; resources " .. AuditStatus(snapshot.resourceCount, false) .. " " .. AuditValue(snapshot.resourceCount, "?") .. ": " .. resourceSample .. ".");
  table.insert(lines, "Units: " .. AuditStatus(snapshot.unitCount, false) .. " " .. AuditValue(snapshot.unitCount, "?") .. ": " .. unitSample .. "; met civs " .. AuditValue(snapshot.metCivilizations, "?") .. ".");
  table.insert(lines, "Government/policies: " .. AuditValue(snapshot.governmentName, "?") .. "; slots " .. AuditValue(snapshot.policySlotCount, "?") .. "; active " .. tostring(#snapshot.policyCards) .. ": " .. policySample .. ".");
  table.insert(lines, "Known gaps: visible plot yields, detailed diplomacy, and victory progress are not in this panel yet.");
  return table.concat(lines, "[NEWLINE]");
end

local function BuildAdviceAnswer(snapshot:table, isChinese:boolean)
  if isChinese then
    if snapshot.cityCount <= 0 then
      return "规则建议：[NEWLINE]1. 还没有城市，优先观察首都落城位置。[NEWLINE]2. 落城后再校验科技、文化、金币和生产数据是否同步变化。";
    end

    local advice:string = "规则建议：[NEWLINE]";
    advice = advice .. "1. 先核对左上角产出：科技 " .. tostring(snapshot.science) .. "/回合、文化 " .. tostring(snapshot.culture) .. "/回合、金币 " .. tostring(snapshot.goldPerTurn) .. "/回合。[NEWLINE]";
    advice = advice .. "2. 观察城市“" .. snapshot.firstCityName .. "”的人口和生产队列，当前生产是“" .. snapshot.firstCityProduction .. "”。[NEWLINE]";

    if snapshot.science <= 3 then
      advice = advice .. "3. 科技仍处于开局低产阶段，先看科技目标和周围可改良资源，不急着下最终判断。";
    else
      advice = advice .. "3. 科技产出已有基础，下一步可以比较城市人口、改良和科技目标是否匹配。";
    end

    return advice;
  end

  if snapshot.cityCount <= 0 then
    return "Rule advice:[NEWLINE]1. No city yet; inspect the capital settle location first.[NEWLINE]2. After settling, re-check science, culture, gold, and production changes.";
  end

  return "Rule advice:[NEWLINE]" ..
    "1. Cross-check top-left yields: science " .. tostring(snapshot.science) .. "/turn, culture " .. tostring(snapshot.culture) .. "/turn, gold " .. tostring(snapshot.goldPerTurn) .. "/turn.[NEWLINE]" ..
    "2. Inspect " .. snapshot.firstCityName .. "'s population and build queue. Current production: " .. snapshot.firstCityProduction .. ".[NEWLINE]" ..
    "3. This is a fixed rule response for testing data-grounded advice.";
end

local function BuildCompareAnswer(snapshot:table, previous:table, isChinese:boolean)
  if previous == nil then
    if isChinese then
      return "回合对比：[NEWLINE]还没有上一回合快照。请先结束一回合，等新回合开始后再点这里。[NEWLINE]当前会话已记录 " .. tostring(#journal) .. " 条快照。";
    end

    return "Turn comparison:[NEWLINE]No previous-turn snapshot yet. End one turn, then open this again.[NEWLINE]This session has recorded " .. tostring(#journal) .. " snapshots.";
  end

  local scienceDelta:number = snapshot.science - previous.science;
  local cultureDelta:number = snapshot.culture - previous.culture;
  local goldPerTurnDelta:number = snapshot.goldPerTurn - previous.goldPerTurn;
  local goldDelta:number = snapshot.goldBalance - previous.goldBalance;
  local cityDelta:number = snapshot.cityCount - previous.cityCount;
  local populationDelta:number = snapshot.firstCityPopulation - previous.firstCityPopulation;

  if isChinese then
    return "回合对比：当前回合 " .. tostring(snapshot.turn) .. "，对比回合 " .. tostring(previous.turn) .. "。[NEWLINE]" ..
      "科技/回合 " .. FormatDelta(scienceDelta) .. "，文化/回合 " .. FormatDelta(cultureDelta) .. "，金币/回合 " .. FormatDelta(goldPerTurnDelta) .. "，金币总量 " .. FormatDelta(goldDelta) .. "。[NEWLINE]" ..
      "城市数 " .. FormatDelta(cityDelta) .. "，首城人口 " .. FormatDelta(populationDelta) .. "。[NEWLINE]" ..
      "当前生产：“" .. snapshot.firstCityProduction .. "”；上一回合记录：“" .. previous.firstCityProduction .. "”。[NEWLINE]" ..
      "当前会话已记录 " .. tostring(#journal) .. " 条快照。";
  end

  return "Turn comparison: current turn " .. tostring(snapshot.turn) .. ", compared with turn " .. tostring(previous.turn) .. ".[NEWLINE]" ..
    "Science/turn " .. FormatDelta(scienceDelta) .. ", culture/turn " .. FormatDelta(cultureDelta) .. ", gold/turn " .. FormatDelta(goldPerTurnDelta) .. ", gold balance " .. FormatDelta(goldDelta) .. ".[NEWLINE]" ..
    "Cities " .. FormatDelta(cityDelta) .. ", first-city population " .. FormatDelta(populationDelta) .. ".[NEWLINE]" ..
    "Current production: " .. snapshot.firstCityProduction .. "; previous record: " .. previous.firstCityProduction .. ".[NEWLINE]" ..
    "This session has recorded " .. tostring(#journal) .. " snapshots.";
end

local function BuildMemoryAnswer(snapshot:table, isChinese:boolean)
  local lastEntry:table = nil;

  if #journal > 0 then
    lastEntry = journal[#journal];
  end

  local lastTurn:string = lastEntry ~= nil and tostring(lastEntry.turn) or "-";
  local lastReason:string = lastEntry ~= nil and tostring(lastEntry.reason or "-") or "-";

  if isChinese then
    return "记忆状态：[NEWLINE]" ..
      "会话快照：" .. tostring(#journal) .. "/" .. tostring(MAX_JOURNAL_ENTRIES) .. " 条；已写入：" .. tostring(persistedEntryCount) .. " 条。[NEWLINE]" ..
      "读取状态：" .. StatusText(persistenceLoadStatus, true) .. "。[NEWLINE]" ..
      "写入状态：" .. StatusText(persistenceSaveStatus, true) .. "。[NEWLINE]" ..
      "最后记录：回合 " .. lastTurn .. "，来源 " .. lastReason .. "。[NEWLINE]" ..
      "当前快照：回合 " .. tostring(snapshot.turn) .. "，城市 " .. tostring(snapshot.cityCount) .. "，金币 " .. tostring(snapshot.goldBalance) .. "。";
  end

  return "Memory status:[NEWLINE]" ..
    "Session snapshots: " .. tostring(#journal) .. "/" .. tostring(MAX_JOURNAL_ENTRIES) .. "; persisted: " .. tostring(persistedEntryCount) .. ".[NEWLINE]" ..
    "Load status: " .. StatusText(persistenceLoadStatus, false) .. ".[NEWLINE]" ..
    "Save status: " .. StatusText(persistenceSaveStatus, false) .. ".[NEWLINE]" ..
    "Last record: turn " .. lastTurn .. ", reason " .. lastReason .. ".[NEWLINE]" ..
    "Current snapshot: turn " .. tostring(snapshot.turn) .. ", cities " .. tostring(snapshot.cityCount) .. ", gold " .. tostring(snapshot.goldBalance) .. ".";
end

local function RefreshAnswer(mode:string, recordReason:string)
  currentMode = mode or currentMode;
  local snapshot:table = RecordSnapshot(recordReason or currentMode);
  local isChinese:boolean = IsChineseUI();

  local fallbackQuestion:string = currentMode == "data" and "What is the current data?" or "What should I inspect right now?";
  local fallbackMetrics:string = "Turn {1} · Science {2}/turn · Culture {3}/turn · Gold {4} ({5}/turn) · Cities {6}";
  local answer:string = BuildDataAnswer(snapshot, isChinese);

  if isChinese then
    fallbackQuestion = currentMode == "data" and "当前数据是什么？" or "根据当前数据，有什么建议？";
    fallbackMetrics = "回合 {1} · 科技 {2}/回合 · 文化 {3}/回合 · 金币 {4}（{5}/回合）· 城市 {6}";
  end

  if currentMode == "advice" then
    answer = BuildAdviceAnswer(snapshot, isChinese);
  end

  if currentMode == "compare" then
    fallbackQuestion = isChinese and "和上一回合相比，发生了什么变化？" or "What changed since the previous turn?";
    answer = BuildCompareAnswer(snapshot, FindPreviousTurnSnapshot(snapshot.turn), isChinese);
  end

  if currentMode == "memory" then
    fallbackQuestion = isChinese and "Obelisk 现在记住了什么？" or "What does Obelisk remember?";
    answer = BuildMemoryAnswer(snapshot, isChinese);
  end

  if currentMode == "cities" then
    fallbackQuestion = isChinese and "我现在有哪些城市？" or "What cities do I have?";
    answer = BuildCitiesAnswer(snapshot, isChinese);
  end

  if currentMode == "audit" then
    fallbackQuestion = isChinese and "Obelisk 现在能读到哪些数据？" or "What data can Obelisk read?";
    answer = BuildAuditAnswer(snapshot, isChinese);
  end

  if Controls.QuestionLabel ~= nil then
    Controls.QuestionLabel:SetText(fallbackQuestion);
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
    Controls.AnswerLabel:SetText(answer);
  end
end

local function SetExpanded(expanded:boolean)
  isExpanded = expanded;
  collapseElapsed = 0;

  if expanded then
    RefreshAnswer(currentMode);
  end

  if Controls.ExpandedPanel ~= nil then
    Controls.ExpandedPanel:SetHide(not expanded);
  end

  if Controls.IdlePanel ~= nil then
    Controls.IdlePanel:SetHide(false);
  end
end

local function OnAsk()
  currentMode = "data";
  SetExpanded(true);
end

local function OnData()
  RefreshAnswer("data");
end

local function OnAdvice()
  RefreshAnswer("advice");
end

local function OnCompare()
  RefreshAnswer("compare");
end

local function OnMemory()
  RefreshAnswer("memory");
end

local function OnCities()
  RefreshAnswer("cities");
end

local function OnAudit()
  RefreshAnswer("audit");
end

local function OnCollapse()
  SetExpanded(false);
end

local function OnLocalPlayerTurnBegin()
  RecordSnapshot("turn_begin");

  if isExpanded then
    RefreshAnswer(currentMode, "turn_begin_refresh");
  end
end

local function Initialize()
  ContextPtr:SetHide(false);

  if Controls.AskButton ~= nil then
    local askFallback:string = IsChineseUI() and "询问 Obelisk..." or "Ask Obelisk...";
    Controls.AskButton:SetText(LookupOrDefault("LOC_OBELISK_ASK", askFallback));
  end

  if Controls.DataButton ~= nil then
    Controls.DataButton:SetText(IsChineseUI() and "当前数据" or "Data");
  end

  if Controls.AdviceButton ~= nil then
    Controls.AdviceButton:SetText(IsChineseUI() and "规则建议" or "Advice");
  end

  if Controls.CompareButton ~= nil then
    Controls.CompareButton:SetText(IsChineseUI() and "回合对比" or "Compare");
  end

  if Controls.MemoryButton ~= nil then
    Controls.MemoryButton:SetText(IsChineseUI() and "记忆状态" or "Memory");
  end

  if Controls.CitiesButton ~= nil then
    Controls.CitiesButton:SetText(IsChineseUI() and "城市总览" or "Cities");
  end

  if Controls.AuditButton ~= nil then
    Controls.AuditButton:SetText(IsChineseUI() and "数据体检" or "Audit");
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

  if Controls.DataButton ~= nil then
    Controls.DataButton:RegisterCallback(Mouse.eLClick, OnData);
  end

  if Controls.AdviceButton ~= nil then
    Controls.AdviceButton:RegisterCallback(Mouse.eLClick, OnAdvice);
  end

  if Controls.CompareButton ~= nil then
    Controls.CompareButton:RegisterCallback(Mouse.eLClick, OnCompare);
  end

  if Controls.MemoryButton ~= nil then
    Controls.MemoryButton:RegisterCallback(Mouse.eLClick, OnMemory);
  end

  if Controls.CitiesButton ~= nil then
    Controls.CitiesButton:RegisterCallback(Mouse.eLClick, OnCities);
  end

  if Controls.AuditButton ~= nil then
    Controls.AuditButton:RegisterCallback(Mouse.eLClick, OnAudit);
  end

  if Events.LocalPlayerTurnBegin ~= nil then
    Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
  end

  LoadPersistedJournal();
  RecordSnapshot("initialize");
  SetExpanded(false);
  print("Obelisk UI context loaded.");
end

Initialize();
