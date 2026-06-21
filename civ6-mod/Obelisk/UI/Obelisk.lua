-- Obelisk: first in-game UI context prototype.
-- This file intentionally avoids gameplay changes. It only proves that the
-- overlay context can load and respond inside Civilization VI.

include("TradeSupport");

local AUTO_COLLAPSE_SECONDS:number = 45;
local MAX_JOURNAL_ENTRIES:number = 12;
local JOURNAL_PROPERTY_KEY:string = "OBELISK_JOURNAL_V1";
local isExpanded:boolean = false;
local collapseElapsed:number = 0;
local currentMode:string = "advice";
local currentQuestion:string = "";
local isResettingQueryBox:boolean = false;
local journal:table = {};
local journalSequence:number = 0;
local persistenceLoadStatus:string = "not_checked";
local persistenceSaveStatus:string = "not_checked";
local persistenceLoadAttempted:boolean = false;
local currentSnapshot:table = nil;

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

local function SafeComponent(owner:table, getterName:string)
  if owner == nil then
    return nil;
  end

  return SafeCall(nil, function()
    return owner[getterName](owner);
  end);
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

local function FormatYieldSet(food, production, gold, science, culture, faith, isChinese:boolean)
  if isChinese then
    return "食" .. tostring(food or 0) ..
      " 产" .. tostring(production or 0) ..
      " 金" .. tostring(gold or 0) ..
      " 科" .. tostring(science or 0) ..
      " 文" .. tostring(culture or 0) ..
      " 信" .. tostring(faith or 0);
  end

  return "F" .. tostring(food or 0) ..
    " P" .. tostring(production or 0) ..
    " G" .. tostring(gold or 0) ..
    " S" .. tostring(science or 0) ..
    " C" .. tostring(culture or 0) ..
    " Fa" .. tostring(faith or 0);
end

local function FormatYieldValues(yieldValues:table)
  if yieldValues == nil then
    return "-";
  end

  return FormatYieldSet(
    yieldValues[YieldTypes.FOOD + 1] or 0,
    yieldValues[YieldTypes.PRODUCTION + 1] or 0,
    yieldValues[YieldTypes.GOLD + 1] or 0,
    yieldValues[YieldTypes.SCIENCE + 1] or 0,
    yieldValues[YieldTypes.CULTURE + 1] or 0,
    yieldValues[YieldTypes.FAITH + 1] or 0,
    true
  );
end

local function LookupCityStateCategory(playerID:number)
  local playerConfig:table = PlayerConfigurations[playerID];

  if playerConfig == nil or GameInfo.Civilizations == nil then
    return "-";
  end

  local civilizationType:string = SafeCall(nil, function() return playerConfig:GetCivilizationTypeName(); end);
  local civilizationInfo:table = civilizationType ~= nil and GameInfo.Civilizations[civilizationType] or nil;

  if civilizationInfo ~= nil and civilizationInfo.CityStateCategory ~= nil then
    return tostring(civilizationInfo.CityStateCategory);
  end

  return "-";
end

local function LookupIndexedName(infoTable, index:number, fallback:string)
  if index == nil or index < 0 or infoTable == nil or infoTable[index] == nil then
    return fallback;
  end

  return Locale.Lookup(infoTable[index].Name);
end

local function LookupTypedName(infoTable, typeName:string, fallback:string)
  if typeName == nil or typeName == "" or infoTable == nil then
    return fallback;
  end

  local row:table = infoTable[typeName];

  if row ~= nil and row.Name ~= nil then
    return Locale.Lookup(row.Name);
  end

  return fallback;
end

local function LookupReligionName(religionID:number, fallback:string)
  if religionID == nil or religionID < 0 or GameInfo.Religions == nil then
    return fallback;
  end

  for religion in GameInfo.Religions() do
    if religion.Index == religionID then
      return Locale.Lookup(religion.Name);
    end
  end

  return fallback;
end

local function FormatPlotDetail(plot:table, ownerCityName:string)
  local terrainName:string = LookupIndexedName(GameInfo.Terrains, SafeCall(-1, function() return plot:GetTerrainType(); end), "-");
  local featureName:string = LookupIndexedName(GameInfo.Features, SafeCall(-1, function() return plot:GetFeatureType(); end), "-");
  local resourceName:string = LookupIndexedName(GameInfo.Resources, SafeCall(-1, function() return plot:GetResourceType(); end), "-");
  local improvementName:string = LookupIndexedName(GameInfo.Improvements, SafeCall(-1, function() return plot:GetImprovementType(); end), "-");
  local districtName:string = LookupIndexedName(GameInfo.Districts, SafeCall(-1, function() return plot:GetDistrictType(); end), "-");
  local x:number = SafeCall(-1, function() return plot:GetX(); end);
  local y:number = SafeCall(-1, function() return plot:GetY(); end);

  return "(" .. tostring(x) .. "," .. tostring(y) .. ") " ..
    terrainName .. "/" .. featureName ..
    " 资源" .. resourceName ..
    " 改良" .. improvementName ..
    " 区域" .. districtName ..
    " 城市" .. ownerCityName ..
    " " .. FormatYieldSet(
      SafeCall(0, function() return plot:GetYield(YieldTypes.FOOD); end),
      SafeCall(0, function() return plot:GetYield(YieldTypes.PRODUCTION); end),
      SafeCall(0, function() return plot:GetYield(YieldTypes.GOLD); end),
      SafeCall(0, function() return plot:GetYield(YieldTypes.SCIENCE); end),
      SafeCall(0, function() return plot:GetYield(YieldTypes.CULTURE); end),
      SafeCall(0, function() return plot:GetYield(YieldTypes.FAITH); end),
      true
    );
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
  elseif status == "session_only" then
    return "session_only（仅当前会话）";
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

local function LoadPersistedJournal()
  persistenceLoadAttempted = true;

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
    domesticTourists = nil,
    visitingTourists = nil,
    cultureVictoryTurns = nil,
    score = nil,
    militaryStrength = nil,
    diplomaticVictoryPoints = nil,
    citiesFollowingReligion = nil,
    resourceCount = nil,
    resourceSamples = {},
    horseCount = 0,
    ironCount = 0,
    bonusResourceCount = 0,
    luxuryResourceCount = 0,
    strategicResourceCount = 0,
    unitCount = nil,
    unitSamples = {},
    spyCapacity = nil,
    spyCount = 0,
    activeSpyCount = 0,
    idleSpyCount = 0,
    capturedSpyCount = 0,
    offMapSpyCount = 0,
    spySamples = {},
    metCivilizations = nil,
    governmentName = nil,
    policySlotCount = nil,
    policyCards = {},
    governorPoints = nil,
    governorPointsSpent = nil,
    canAppointGovernor = nil,
    canPromoteGovernor = nil,
    governorSamples = {},
    majorContacts = nil,
    minorContacts = nil,
    atWarCount = nil,
    diplomacySamples = {},
    diplomacyModifierSamples = {},
    cityStateSamples = {},
    cityStateMetCount = 0,
    cityStateSuzerainCount = 0,
    enabledVictoryCount = nil,
    victorySamples = {},
    victoryDetailSamples = {},
    victoryMetricSamples = {},
    currentTech = "-",
    currentTechTurns = -1,
    techCandidateSamples = {},
    currentCivic = "-",
    currentCivicTurns = -1,
    civicCandidateSamples = {},
    eraName = nil,
    techCompletedCount = nil,
    civicCompletedCount = nil,
    religionSummary = "-",
    greatPeopleSamples = {},
    unitDetailSamples = {},
    buildingCount = 0,
    districtCount = 0,
    wonderCount = 0,
    tradeRouteActive = nil,
    tradeRouteCapacity = nil,
    tradeRouteSamples = {},
    incomingTradeRouteCount = 0,
    averageCityProduction = 0,
    firstCityLoyaltySummary = nil,
    revealedPlotCount = 0,
    visiblePlotCount = 0,
    ownedPlotCount = 0,
    strategicMapScore = 0,
    expansionCandidateCount = 0,
    borderPressureCount = 0,
    strategicMapSamples = {}
  };

  local player:table = GetLocalPlayerObject();
  local localPlayerID:number = Game.GetLocalPlayer();

  if player == nil then
    return snapshot;
  end

  local techs:table = SafeComponent(player, "GetTechs");
  local ownedCityCenters:table = {};

  if techs ~= nil then
    snapshot.science = SafeCall(0, function() return Round(techs:GetScienceYield()); end);

    local techID:number = SafeCall(-1, function() return techs:GetResearchingTech(); end);

    if techID ~= -1 and GameInfo.Technologies[techID] ~= nil then
      snapshot.currentTech = Locale.Lookup(GameInfo.Technologies[techID].Name);
      snapshot.currentTechTurns = SafeCall(-1, function() return techs:GetTurnsLeft(); end);
    end

    local completedTechs:number = 0;

    for tech in GameInfo.Technologies() do
      if SafeCall(false, function() return techs:HasTech(tech.Index); end) then
        completedTechs = completedTechs + 1;
      end
    end

    snapshot.techCompletedCount = completedTechs;

    for tech in GameInfo.Technologies() do
      if #snapshot.techCandidateSamples >= 5 then
        break;
      end

      local techID:number = tech.Index;
      local canResearch:boolean = SafeCall(false, function() return techs:CanResearch(techID); end);

      if canResearch then
        local researchCost:number = SafeCall(0, function() return techs:GetResearchCost(techID); end);
        local researchProgress:number = researchCost > 0 and SafeCall(0, function() return techs:GetResearchProgress(techID); end) or 0;
        local boostTriggered:boolean = SafeCall(false, function() return techs:HasBoostBeenTriggered(techID); end);
        table.insert(snapshot.techCandidateSamples, Locale.Lookup(tech.Name) ..
          " " .. tostring(researchProgress) .. "/" .. tostring(researchCost) ..
          " " .. tostring(SafeCall(-1, function() return techs:GetTurnsToResearch(techID); end)) .. "回合" ..
          (boostTriggered and " 已尤里卡" or ""));
      end
    end
  end

  local culture:table = SafeComponent(player, "GetCulture");

  if culture ~= nil then
    snapshot.culture = SafeCall(0, function() return Round(culture:GetCultureYield()); end);
    snapshot.domesticTourists = SafeCall(nil, function() return culture:GetStaycationers(); end);
    snapshot.visitingTourists = SafeCall(nil, function() return culture:GetTouristsTo(); end);
    snapshot.cultureVictoryTurns = SafeCall(nil, function() return culture:GetTurnsUntilVictory(); end);

    local civicID:number = SafeCall(-1, function() return culture:GetProgressingCivic(); end);

    if civicID ~= -1 and GameInfo.Civics[civicID] ~= nil then
      snapshot.currentCivic = Locale.Lookup(GameInfo.Civics[civicID].Name);
      snapshot.currentCivicTurns = SafeCall(-1, function() return culture:GetTurnsLeft(); end);
    end

    local completedCivics:number = 0;

    for civic in GameInfo.Civics() do
      if SafeCall(false, function() return culture:HasCivic(civic.Index); end) then
        completedCivics = completedCivics + 1;
      end
    end

    snapshot.civicCompletedCount = completedCivics;

    for civic in GameInfo.Civics() do
      if #snapshot.civicCandidateSamples >= 5 then
        break;
      end

      local civicID:number = civic.Index;
      local canProgress:boolean = SafeCall(false, function() return culture:CanProgress(civicID); end);

      if canProgress then
        local progressCost:number = SafeCall(0, function() return culture:GetCultureCost(civicID); end);
        local civicProgress:number = progressCost > 0 and SafeCall(0, function() return culture:GetCulturalProgress(civicID); end) or 0;
        local boostTriggered:boolean = SafeCall(false, function() return culture:HasBoostBeenTriggered(civicID); end);
        table.insert(snapshot.civicCandidateSamples, Locale.Lookup(civic.Name) ..
          " " .. tostring(civicProgress) .. "/" .. tostring(progressCost) ..
          " " .. tostring(SafeCall(-1, function() return culture:GetTurnsToProgressCivic(civicID); end)) .. "回合" ..
          (boostTriggered and " 已鼓舞" or ""));
      end
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

  local governors:table = SafeComponent(player, "GetGovernors");

  if governors ~= nil then
    snapshot.governorPoints = SafeCall(nil, function() return governors:GetGovernorPoints(); end);
    snapshot.governorPointsSpent = SafeCall(nil, function() return governors:GetGovernorPointsSpent(); end);
    snapshot.canAppointGovernor = SafeCall(nil, function() return governors:CanAppoint(); end);
    snapshot.canPromoteGovernor = SafeCall(nil, function() return governors:CanPromote(); end);

    local governorList:table = SafeCall(nil, function()
      local hasGovernors, list = governors:GetGovernorList();

      if hasGovernors then
        return list;
      end

      return nil;
    end);

    if type(governorList) == "table" then
      for _, governor in ipairs(governorList) do
        if #snapshot.governorSamples >= 5 then
          break;
        end

        local governorType:number = SafeCall(-1, function() return governor:GetType(); end);
        local governorDef:table = governorType ~= -1 and GameInfo.Governors ~= nil and GameInfo.Governors[governorType] or nil;
        local governorName:string = SafeCall(nil, function() return Locale.Lookup(governor:GetName()); end);

        if (governorName == nil or governorName == "") and governorDef ~= nil then
          governorName = Locale.Lookup(governorDef.Name);
        end

        local assignedCity:table = SafeCall(nil, function() return governor:GetAssignedCity(); end);
        local assignedCityName:string = assignedCity ~= nil and SafeCall("-", function() return assignedCity:GetName(); end) or "-";
        local established:boolean = SafeCall(false, function() return governor:IsEstablished(); end);
        local turnsOnSite:number = SafeCall(0, function() return governor:GetTurnsOnSite(); end);
        local turnsToEstablish:number = SafeCall(0, function() return governor:GetTurnsToEstablish(); end);
        local turnsUntilEstablished:number = math.max(0, turnsToEstablish - turnsOnSite);

        governorName = governorName or "-";
        assignedCityName = assignedCityName or "-";

        table.insert(snapshot.governorSamples, governorName ..
          " 城市" .. assignedCityName ..
          (established and " 已就位" or (" 建立剩余" .. tostring(turnsUntilEstablished))));
      end
    end
  end

  local treasury:table = SafeComponent(player, "GetTreasury");

  if treasury ~= nil then
    snapshot.goldBalance = SafeCall(0, function() return math.floor(treasury:GetGoldBalance()); end);
    snapshot.goldPerTurn = SafeCall(0, function() return Round(treasury:GetGoldYield() - treasury:GetTotalMaintenance()); end);
  end

  local religion:table = SafeComponent(player, "GetReligion");

  if religion ~= nil then
    snapshot.faithBalance = SafeCall(nil, function() return Round(religion:GetFaithBalance()); end);
    snapshot.faithPerTurn = SafeCall(nil, function() return Round(religion:GetFaithYield()); end);
    local religionType:number = SafeCall(-1, function() return religion:GetReligionTypeCreated(); end);
    local pantheonType:number = SafeCall(-1, function() return religion:GetPantheon(); end);
    snapshot.religionSummary = "宗教 " .. LookupReligionName(religionType, "-") .. "；万神殿 " .. LookupIndexedName(GameInfo.Beliefs, pantheonType, "-");
  end

  local stats:table = SafeComponent(player, "GetStats");

  if stats ~= nil then
    snapshot.tourism = SafeCall(nil, function() return Round(stats:GetTourism()); end);
    snapshot.militaryStrength = SafeCall(nil, function() return Round(stats:GetMilitaryStrength()); end);
    snapshot.diplomaticVictoryPoints = SafeCall(nil, function() return stats:GetDiplomaticVictoryPoints(); end);
    snapshot.citiesFollowingReligion = SafeCall(nil, function() return stats:GetNumCitiesFollowingReligion(); end);
  end

  local playerTrade:table = SafeComponent(player, "GetTrade");

  if playerTrade ~= nil then
    snapshot.tradeRouteActive = SafeCall(nil, function() return playerTrade:GetNumOutgoingRoutes(); end);
    snapshot.tradeRouteCapacity = SafeCall(nil, function() return playerTrade:GetOutgoingRouteCapacity(); end);

    local playerCities:table = SafeComponent(player, "GetCities");

    if playerCities ~= nil then
      for _, city in playerCities:Members() do
        if #snapshot.tradeRouteSamples >= 5 then
          break;
        end

        local cityTrade:table = SafeComponent(city, "GetTrade");
        local outgoingRoutes:table = cityTrade ~= nil and SafeCall({}, function() return cityTrade:GetOutgoingRoutes(); end) or {};

        if type(outgoingRoutes) == "table" then
          for _, route in ipairs(outgoingRoutes) do
            if #snapshot.tradeRouteSamples >= 5 then
              break;
            end

            local destinationPlayerID:number = route.DestinationCityPlayer;
            local destinationCityID:number = route.DestinationCityID;
            local destinationPlayer:table = destinationPlayerID ~= nil and Players[destinationPlayerID] or nil;
            local destinationCity:table = (destinationPlayer ~= nil and destinationCityID ~= nil) and SafeCall(nil, function() return destinationPlayer:GetCities():FindID(destinationCityID); end) or nil;

            if destinationCity ~= nil then
              local routeInfo:table = SafeCall(nil, function() return GetYieldsForRoute(city, destinationCity); end);
              local turnsRemaining = route.TurnsRemaining or route.TurnsLeft or route.RemainingTurns or nil;
              table.insert(snapshot.tradeRouteSamples, city:GetName() ..
                "→" .. destinationCity:GetName() ..
                " " .. FormatYieldValues(routeInfo ~= nil and routeInfo.kYieldValues or nil) ..
                " 剩余" .. AuditValue(turnsRemaining, "?"));
            end
          end
        end
      end
    end

    local allPlayers:table = SafeCall({}, function() return Game.GetPlayers(); end);

    if type(allPlayers) == "table" then
      for _, otherPlayer in ipairs(allPlayers) do
        if otherPlayer:GetID() ~= Game.GetLocalPlayer() then
          local otherCities:table = SafeComponent(otherPlayer, "GetCities");

          if otherCities ~= nil then
            for _, otherCity in otherCities:Members() do
              local otherCityTrade:table = SafeComponent(otherCity, "GetTrade");
              local outgoingRoutes:table = otherCityTrade ~= nil and SafeCall({}, function() return otherCityTrade:GetOutgoingRoutes(); end) or {};

              if type(outgoingRoutes) == "table" then
                for _, route in ipairs(outgoingRoutes) do
                  if route.DestinationCityPlayer == Game.GetLocalPlayer() then
                    snapshot.incomingTradeRouteCount = snapshot.incomingTradeRouteCount + 1;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  local greatPeoplePoints:table = SafeComponent(player, "GetGreatPeoplePoints");

  if greatPeoplePoints ~= nil and GameInfo.GreatPersonClasses ~= nil then
    for class in GameInfo.GreatPersonClasses() do
      local points:number = SafeCall(0, function() return greatPeoplePoints:GetPointsTotal(class.Index); end);
      local pointsPerTurn:number = SafeCall(0, function() return greatPeoplePoints:GetPointsPerTurn(class.Index); end);

      if (points > 0 or pointsPerTurn > 0) and #snapshot.greatPeopleSamples < 4 then
        table.insert(snapshot.greatPeopleSamples, Locale.Lookup(class.Name) .. " " .. tostring(points) .. "(+" .. tostring(pointsPerTurn) .. ")");
      end
    end
  end

  snapshot.score = SafeCall(nil, function() return Round(player:GetScore()); end);
  snapshot.eraName = LookupIndexedName(GameInfo.Eras, SafeCall(-1, function() return player:GetEra(); end), nil);

  local resources:table = SafeComponent(player, "GetResources");

  if resources ~= nil then
    local resourceCount:number = 0;

    for resource in GameInfo.Resources() do
      if resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_ARTIFACT" then
        local amount:number = SafeCall(0, function() return resources:GetResourceAmount(resource.ResourceType); end);

        if amount > 0 then
          resourceCount = resourceCount + 1;

          if resource.ResourceClassType == "RESOURCECLASS_BONUS" then
            snapshot.bonusResourceCount = snapshot.bonusResourceCount + 1;
          elseif resource.ResourceClassType == "RESOURCECLASS_LUXURY" then
            snapshot.luxuryResourceCount = snapshot.luxuryResourceCount + 1;
          elseif resource.ResourceClassType == "RESOURCECLASS_STRATEGIC" then
            snapshot.strategicResourceCount = snapshot.strategicResourceCount + 1;
          end

          local resourceType:string = tostring(resource.ResourceType or "");
          local resourceName:string = tostring(Locale.Lookup(resource.Name) or "");

          if resourceType == "RESOURCE_HORSES" or string.find(resourceType, "HORSE") ~= nil or string.find(resourceName, "马") ~= nil or string.find(string.lower(resourceName), "horse") ~= nil then
            snapshot.horseCount = amount;
          elseif resourceType == "RESOURCE_IRON" or string.find(resourceType, "IRON") ~= nil or string.find(resourceName, "铁") ~= nil or string.find(string.lower(resourceName), "iron") ~= nil then
            snapshot.ironCount = amount;
          end

          if #snapshot.resourceSamples < 5 then
            table.insert(snapshot.resourceSamples, resourceName .. " " .. tostring(amount));
          end
        end
      end
    end

    snapshot.resourceCount = resourceCount;
  end

  local units:table = SafeComponent(player, "GetUnits");

  if units ~= nil then
    local unitCount:number = 0;

    for _, unit in units:Members() do
      unitCount = unitCount + 1;
      local unitType:number = SafeCall(-1, function() return unit:GetType(); end);
      local unitDef:table = unitType ~= -1 and GameInfo.Units ~= nil and GameInfo.Units[unitType] or nil;

      if #snapshot.unitSamples < 5 then
        local unitName:string = "-";

        if unitDef ~= nil then
          unitName = Locale.Lookup(unitDef.Name);
        end

        table.insert(snapshot.unitSamples, unitName);

        if #snapshot.unitDetailSamples < 5 then
          local experience:table = SafeCall(nil, function() return unit:GetExperience(); end);
          local xp:number = experience ~= nil and SafeCall(0, function() return experience:GetExperiencePoints(); end) or 0;
          table.insert(snapshot.unitDetailSamples, unitName ..
            "@(" .. tostring(SafeCall(-1, function() return unit:GetX(); end)) .. "," .. tostring(SafeCall(-1, function() return unit:GetY(); end)) .. ")" ..
            " 伤" .. tostring(SafeCall(0, function() return unit:GetDamage(); end)) ..
            " 移" .. tostring(SafeCall(0, function() return unit:GetMovesRemaining(); end)) ..
            " XP" .. tostring(xp));
        end
      end

      if unitDef ~= nil and unitDef.Spy == true then
        snapshot.spyCount = snapshot.spyCount + 1;

        local operationType:number = SafeCall(-1, function() return unit:GetSpyOperation(); end);
        local spyName:string = SafeCall(nil, function() return Locale.Lookup(unit:GetName()); end) or Locale.Lookup(unitDef.Name);
        local spyPlot:table = SafeCall(nil, function() return Map.GetPlot(unit:GetX(), unit:GetY()); end);
        local ownerCity:table = spyPlot ~= nil and SafeCall(nil, function() return Cities.GetPlotPurchaseCity(spyPlot); end) or nil;
        local cityName:string = ownerCity ~= nil and SafeCall("-", function() return ownerCity:GetName(); end) or "-";

        if operationType == -1 then
          snapshot.idleSpyCount = snapshot.idleSpyCount + 1;

          if #snapshot.spySamples < 5 then
            table.insert(snapshot.spySamples, spyName .. " 待命 城市" .. cityName);
          end
        else
          snapshot.activeSpyCount = snapshot.activeSpyCount + 1;

          if #snapshot.spySamples < 5 then
            local operationInfo:table = GameInfo.UnitOperations ~= nil and GameInfo.UnitOperations[operationType] or nil;
            local operationName:string = operationInfo ~= nil and Locale.Lookup(operationInfo.Description) or "任务";
            local remainingTurns:number = math.max(0, SafeCall(Game.GetCurrentGameTurn(), function() return unit:GetSpyOperationEndTurn(); end) - Game.GetCurrentGameTurn());
            table.insert(snapshot.spySamples, spyName .. " " .. operationName .. " 城市" .. cityName .. " 剩余" .. tostring(remainingTurns));
          end
        end
      end
    end

    snapshot.unitCount = unitCount;
  end

  local playerDiplomacy:table = SafeComponent(player, "GetDiplomacy");

  if playerDiplomacy ~= nil then
    snapshot.spyCapacity = SafeCall(nil, function() return playerDiplomacy:GetSpyCapacity(); end);

    local offMapSpyCount:number = SafeCall(0, function() return playerDiplomacy:GetNumSpiesOffMap(); end);

    for spyIndex = 0, offMapSpyCount - 1, 1 do
      local spyInfo:table = SafeCall(nil, function() return playerDiplomacy:GetNthOffMapSpy(localPlayerID, spyIndex); end);

      if spyInfo ~= nil and spyInfo.ReturnTurn ~= -1 then
        snapshot.offMapSpyCount = snapshot.offMapSpyCount + 1;
        snapshot.spyCount = snapshot.spyCount + 1;

        if #snapshot.spySamples < 5 then
          local remainingTurns:number = math.max(0, (spyInfo.ReturnTurn or Game.GetCurrentGameTurn()) - Game.GetCurrentGameTurn());
          table.insert(snapshot.spySamples, (spyInfo.Name or "间谍") .. " 返程中 剩余" .. tostring(remainingTurns));
        end
      end
    end

    for _, otherPlayer in ipairs(Game.GetPlayers()) do
      local otherDiplomacy:table = SafeComponent(otherPlayer, "GetDiplomacy");
      local capturedCount:number = otherDiplomacy ~= nil and SafeCall(0, function() return otherDiplomacy:GetNumSpiesCaptured(); end) or 0;

      for spyIndex = 0, capturedCount - 1, 1 do
        local spyInfo:table = SafeCall(nil, function() return otherDiplomacy:GetNthCapturedSpy(otherPlayer:GetID(), spyIndex); end);

        if spyInfo ~= nil and spyInfo.OwningPlayer == localPlayerID then
          snapshot.capturedSpyCount = snapshot.capturedSpyCount + 1;
          snapshot.spyCount = snapshot.spyCount + 1;

          if #snapshot.spySamples < 5 then
            local captorName:string = GetPlayerCivilizationName(otherPlayer:GetID());
            table.insert(snapshot.spySamples, (spyInfo.Name or "间谍") .. " 被俘 于" .. captorName);
          end
        end
      end
    end
  end

  snapshot.majorContacts = 0;
  snapshot.minorContacts = 0;
  snapshot.atWarCount = 0;

  local localDiplomacy:table = SafeComponent(player, "GetDiplomacy");

  if localDiplomacy ~= nil then
    for playerID:number = 0, 63 do
      local otherPlayer:table = Players[playerID];

      if playerID ~= localPlayerID and otherPlayer ~= nil then
        local hasMet:boolean = SafeCall(false, function() return localDiplomacy:HasMet(playerID); end);

        if hasMet then
          local isMajor:boolean = SafeCall(false, function() return otherPlayer:IsMajor(); end);
          local isMinor:boolean = SafeCall(false, function() return otherPlayer:IsMinor(); end);
          local isAtWar:boolean = SafeCall(false, function() return localDiplomacy:IsAtWarWith(playerID); end);

          if isMajor then
            snapshot.majorContacts = snapshot.majorContacts + 1;
          end

          if isMinor then
            snapshot.minorContacts = snapshot.minorContacts + 1;
            snapshot.cityStateMetCount = snapshot.cityStateMetCount + 1;
          end

          if isAtWar then
            snapshot.atWarCount = snapshot.atWarCount + 1;
          end

          if isMinor and #snapshot.cityStateSamples < 5 then
            local playerConfig:table = PlayerConfigurations[playerID];
            local displayName:string = playerConfig ~= nil and Locale.Lookup(playerConfig:GetCivilizationShortDescription()) or tostring(playerID);
            local influence:table = SafeComponent(otherPlayer, "GetInfluence");
            local envoyCount:number = influence ~= nil and SafeCall(0, function() return influence:GetTokensReceived(localPlayerID); end) or 0;
            local suzerainID:number = influence ~= nil and SafeCall(-1, function() return influence:GetSuzerain(); end) or -1;
            local isSuzerain:boolean = suzerainID == localPlayerID;
            local questCount:number = 0;
            local questsManager:table = SafeCall(nil, function() return Game.GetQuestsManager(); end);

            if isSuzerain then
              snapshot.cityStateSuzerainCount = snapshot.cityStateSuzerainCount + 1;
            end

            if questsManager ~= nil and GameInfo.Quests ~= nil then
              for questInfo in GameInfo.Quests() do
                if SafeCall(false, function() return questsManager:HasActiveQuestFromPlayer(localPlayerID, playerID, questInfo.Index); end) then
                  questCount = questCount + 1;
                end
              end
            end

            table.insert(snapshot.cityStateSamples, displayName ..
              " " .. LookupCityStateCategory(playerID) ..
              " 使者" .. tostring(envoyCount) ..
              (isSuzerain and " 宗主" or "") ..
              " 任务" .. tostring(questCount));
          end

          if #snapshot.diplomacySamples < 4 then
            local playerConfig:table = PlayerConfigurations[playerID];
            local displayName:string = tostring(playerID);
            local relationName:string = "-";
            local diplomaticAI:table = SafeCall(nil, function() return otherPlayer:GetDiplomaticAI(); end);

            if playerConfig ~= nil then
              displayName = SafeCall(displayName, function()
                local civilizationID:number = playerConfig:GetCivilizationTypeID();

                if civilizationID ~= -1 and GameInfo.Civilizations[civilizationID] ~= nil then
                  return Locale.Lookup(GameInfo.Civilizations[civilizationID].Name);
                end

                return Locale.Lookup(playerConfig:GetCivilizationTypeName());
              end);
            end

            if diplomaticAI ~= nil then
              local relationID:number = SafeCall(-1, function() return diplomaticAI:GetDiplomaticStateIndex(localPlayerID); end);

              if relationID ~= -1 and GameInfo.DiplomaticStates[relationID] ~= nil then
                relationName = Locale.Lookup(GameInfo.DiplomaticStates[relationID].Name);
              end
            end

            if isAtWar then
              relationName = relationName .. "/war";
            end

            table.insert(snapshot.diplomacySamples, displayName .. " " .. relationName);

            local modifiers:table = SafeCall(nil, function() return diplomaticAI:GetDiplomaticModifiers(localPlayerID); end);

            if modifiers ~= nil and #snapshot.diplomacyModifierSamples < 4 then
              local modifierText:string = "-";

              if type(modifiers) == "table" then
                for _, modifier in pairs(modifiers) do
                  modifierText = tostring(modifier);
                  break;
                end
              else
                modifierText = tostring(modifiers);
              end

              table.insert(snapshot.diplomacyModifierSamples, displayName .. "：" .. modifierText);
            end
          end
        end
      end
    end

    snapshot.metCivilizations = snapshot.majorContacts;
  end

  snapshot.enabledVictoryCount = 0;

  for victory in GameInfo.Victories() do
    local victoryType:string = victory.VictoryType;
    local isEnabled:boolean = SafeCall(false, function() return Game.IsVictoryEnabled(victoryType); end);

    if isEnabled then
      snapshot.enabledVictoryCount = snapshot.enabledVictoryCount + 1;

      if #snapshot.victorySamples < 4 then
        local teamID:number = SafeCall(-1, function() return player:GetTeam(); end);
        local progress = nil;

        if teamID ~= -1 then
          progress = SafeCall(nil, function() return Game.GetVictoryProgressForTeam(victoryType, teamID); end);
        end

        table.insert(snapshot.victorySamples, Locale.Lookup(victory.Name) .. " " .. AuditValue(progress, "?"));

        if #snapshot.victoryDetailSamples < 4 then
          local description:string = "-";

          if victory.Description ~= nil then
            description = Locale.Lookup(victory.Description);
          elseif victory.RequirementSetId ~= nil then
            description = "RequirementSet " .. tostring(victory.RequirementSetId);
          end

          table.insert(snapshot.victoryDetailSamples, Locale.Lookup(victory.Name) .. "：" .. description);
        end
      end
    end
  end

  local scienceProjectSamples:table = {};

  if GameInfo.Projects ~= nil then
    local localCities:table = SafeComponent(player, "GetCities");
    local playerStats:table = SafeComponent(player, "GetStats");

    if localCities ~= nil then
      for project in GameInfo.Projects() do
        if #scienceProjectSamples >= 5 then
          break;
        end

        local projectType:string = tostring(project.ProjectType or "");
        local isScienceProject:boolean =
          project.SpaceRace == true or
          project.SpaceRace == 1 or
          string.find(projectType, "SPACE") ~= nil or
          string.find(projectType, "SATELLITE") ~= nil or
          string.find(projectType, "MOON") ~= nil or
          string.find(projectType, "MARS") ~= nil or
          string.find(projectType, "EXOPLANET") ~= nil;

        if isScienceProject then
          local completedCount:number = playerStats ~= nil and SafeCall(0, function() return playerStats:GetNumProjectsAdvanced(project.Index); end) or 0;
          local bestProgress:number = 0;
          local bestCost:number = 0;

          for _, city in localCities:Members() do
            local buildQueue:table = SafeComponent(city, "GetBuildQueue");

            if buildQueue ~= nil then
              local projectCost:number = SafeCall(0, function() return buildQueue:GetProjectCost(project.Index); end);
              local projectProgress:number = SafeCall(0, function() return buildQueue:GetProjectProgress(project.Index); end);

              if projectCost > 0 and projectProgress > bestProgress then
                bestProgress = projectProgress;
                bestCost = projectCost;
              elseif projectCost > 0 and bestCost == 0 then
                bestCost = projectCost;
              end
            end
          end

          table.insert(scienceProjectSamples, Locale.Lookup(project.Name) ..
            " 完成" .. tostring(completedCount) ..
            " 进度" .. tostring(bestProgress) .. "/" .. tostring(bestCost));
        end
      end
    end
  end

  if snapshot.domesticTourists ~= nil or snapshot.visitingTourists ~= nil then
    table.insert(snapshot.victoryMetricSamples, "文化游客 " ..
      AuditValue(snapshot.visitingTourists, "?") .. "/" ..
      AuditValue(snapshot.domesticTourists, "?") ..
      " 预计" .. AuditValue(snapshot.cultureVictoryTurns, "?") .. "回合");
  end

  if snapshot.diplomaticVictoryPoints ~= nil then
    table.insert(snapshot.victoryMetricSamples, "外交胜利点 " .. tostring(snapshot.diplomaticVictoryPoints));
  end

  if snapshot.citiesFollowingReligion ~= nil then
    table.insert(snapshot.victoryMetricSamples, "宗教城市 " .. tostring(snapshot.citiesFollowingReligion));
  end

  for _, projectSample in ipairs(scienceProjectSamples) do
    if #snapshot.victoryMetricSamples >= 6 then
      break;
    end

    table.insert(snapshot.victoryMetricSamples, projectSample);
  end

  local cities:table = SafeComponent(player, "GetCities");

  if cities ~= nil then
    snapshot.cityCount = SafeCall(0, function() return cities:GetCount(); end);
    local cityIndex:number = 0;
    local totalProduction:number = 0;
    local productionCityCount:number = 0;

    for _, city in cities:Members() do
      cityIndex = cityIndex + 1;
      local cityX:number = SafeCall(-1, function() return city:GetX(); end);
      local cityY:number = SafeCall(-1, function() return city:GetY(); end);
      local citySnapshot:table = {
        name = SafeCall("-", function() return Locale.Lookup(city:GetName()); end),
        x = cityX,
        y = cityY,
        population = 0,
        production = "-",
        productionTurns = -1,
        food = nil,
        foodSurplus = nil,
        housing = nil,
        amenities = nil,
        amenitiesNeeded = nil,
        workedPlotCount = nil,
        workedPlotSamples = {},
        plotDetailSamples = {},
        buildingCount = 0,
        districtCount = 0,
        wonderCount = 0,
        loyalty = nil,
        loyaltyMax = nil,
        loyaltyPerTurn = nil,
        loyaltyLevel = nil,
        yields = {}
      };

      if cityX >= 0 and cityY >= 0 then
        table.insert(ownedCityCenters, { x = cityX, y = cityY, name = citySnapshot.name });
      end

      citySnapshot.population = SafeCall(0, function() return city:GetPopulation(); end);
      citySnapshot.yields.food = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.FOOD)); end);
      citySnapshot.yields.production = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.PRODUCTION)); end);
      citySnapshot.yields.science = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.SCIENCE)); end);
      citySnapshot.yields.culture = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.CULTURE)); end);
      citySnapshot.yields.gold = SafeCall(nil, function() return Round(city:GetYield(YieldTypes.GOLD)); end);

      if citySnapshot.yields.production ~= nil then
        totalProduction = totalProduction + citySnapshot.yields.production;
        productionCityCount = productionCityCount + 1;
      end

      local growth:table = SafeComponent(city, "GetGrowth");

      if growth ~= nil then
        citySnapshot.food = SafeCall(nil, function() return Round(growth:GetFood()); end);
        citySnapshot.foodSurplus = SafeCall(nil, function() return Round(growth:GetFoodSurplus()); end);
        citySnapshot.housing = SafeCall(nil, function() return Round(growth:GetHousing()); end);
        citySnapshot.amenities = SafeCall(nil, function() return growth:GetAmenities(); end);
        citySnapshot.amenitiesNeeded = SafeCall(nil, function() return growth:GetAmenitiesNeeded(); end);
      end

      local culturalIdentity:table = SafeComponent(city, "GetCulturalIdentity");

      if culturalIdentity ~= nil then
        citySnapshot.loyalty = SafeCall(nil, function() return Round(culturalIdentity:GetLoyalty()); end);
        citySnapshot.loyaltyMax = SafeCall(nil, function() return Round(culturalIdentity:GetMaxLoyalty()); end);
        citySnapshot.loyaltyPerTurn = SafeCall(nil, function() return Round(culturalIdentity:GetLoyaltyPerTurn()); end);

        local loyaltyLevel:number = SafeCall(-1, function() return culturalIdentity:GetLoyaltyLevel(); end);

        if loyaltyLevel ~= -1 and GameInfo.LoyaltyLevels ~= nil and GameInfo.LoyaltyLevels[loyaltyLevel] ~= nil then
          citySnapshot.loyaltyLevel = Locale.Lookup(GameInfo.LoyaltyLevels[loyaltyLevel].Name);
        end
      end

      local cityPlots:table = SafeCall(nil, function() return Map.GetCityPlots():GetPurchasedPlots(city); end);

      if cityPlots ~= nil then
        local workedPlotCount:number = 0;

        for _, plotID in pairs(cityPlots) do
          local plot:table = SafeCall(nil, function() return Map.GetPlotByIndex(plotID); end);

          if plot ~= nil then
            local workerCount:number = SafeCall(0, function() return plot:GetWorkerCount(); end);

            if workerCount > 0 then
              workedPlotCount = workedPlotCount + workerCount;

              if #citySnapshot.workedPlotSamples < 3 then
                table.insert(citySnapshot.workedPlotSamples, FormatYieldSet(
                  SafeCall(0, function() return plot:GetYield(YieldTypes.FOOD); end),
                  SafeCall(0, function() return plot:GetYield(YieldTypes.PRODUCTION); end),
                  SafeCall(0, function() return plot:GetYield(YieldTypes.GOLD); end),
                  SafeCall(0, function() return plot:GetYield(YieldTypes.SCIENCE); end),
                  SafeCall(0, function() return plot:GetYield(YieldTypes.CULTURE); end),
                  SafeCall(0, function() return plot:GetYield(YieldTypes.FAITH); end),
                  true
                ));
              end

              if #citySnapshot.plotDetailSamples < 3 then
                local ownerCity:table = SafeCall(nil, function() return Cities.GetPlotPurchaseCity(plot); end);
                local ownerCityName:string = ownerCity ~= nil and Locale.Lookup(ownerCity:GetName()) or "-";
                table.insert(citySnapshot.plotDetailSamples, FormatPlotDetail(plot, ownerCityName));
              end
            end
          end
        end

        citySnapshot.workedPlotCount = workedPlotCount;
      end

      local cityBuildings:table = SafeComponent(city, "GetBuildings");

      if cityBuildings ~= nil and cityPlots ~= nil then
        for _, plotID in pairs(cityPlots) do
          local buildingTypes:table = SafeCall({}, function() return cityBuildings:GetBuildingsAtLocation(plotID); end);

          if type(buildingTypes) == "table" then
            for _, buildingType in ipairs(buildingTypes) do
              citySnapshot.buildingCount = citySnapshot.buildingCount + 1;

              if GameInfo.Buildings[buildingType] ~= nil and GameInfo.Buildings[buildingType].IsWonder then
                citySnapshot.wonderCount = citySnapshot.wonderCount + 1;
              end
            end
          end
        end
      end

      local cityDistricts:table = SafeComponent(city, "GetDistricts");

      if cityDistricts ~= nil then
        citySnapshot.districtCount = SafeCall(0, function()
          local count:number = 0;

          for _, district in cityDistricts:Members() do
            count = count + 1;
          end

          return count;
        end);
      end

      local buildQueue:table = SafeComponent(city, "GetBuildQueue");

      if buildQueue ~= nil then
        citySnapshot.productionTurns = SafeCall(-1, function() return buildQueue:GetTurnsLeft(); end);

        local productionHash:number = SafeCall(nil, function() return buildQueue:GetCurrentProductionTypeHash(); end);

        if productionHash ~= nil then
          citySnapshot.production = LookupProductionName(productionHash);
        end
      end

      table.insert(snapshot.cities, citySnapshot);
      snapshot.buildingCount = snapshot.buildingCount + citySnapshot.buildingCount;
      snapshot.districtCount = snapshot.districtCount + citySnapshot.districtCount;
      snapshot.wonderCount = snapshot.wonderCount + citySnapshot.wonderCount;

      if cityIndex == 1 then
        snapshot.firstCityName = citySnapshot.name;
        snapshot.firstCityPopulation = citySnapshot.population;
        snapshot.firstCityProduction = citySnapshot.production;
        snapshot.firstCityProductionTurns = citySnapshot.productionTurns;

        local loyaltyPerTurnText:string = citySnapshot.loyaltyPerTurn ~= nil and FormatDelta(citySnapshot.loyaltyPerTurn) or "?";

        snapshot.firstCityLoyaltySummary =
          AuditValue(citySnapshot.loyalty, "?") ..
          "/" ..
          AuditValue(citySnapshot.loyaltyMax, "?") ..
          " " ..
          AuditValue(citySnapshot.loyaltyLevel, "?") ..
          " (" ..
          loyaltyPerTurnText ..
          "/回合)";
      end
    end

    if productionCityCount > 0 then
      snapshot.averageCityProduction = Round(totalProduction / productionCityCount);
    end
  end

  local localVisibility:table = PlayersVisibility ~= nil and PlayersVisibility[localPlayerID] or nil;

  if localVisibility ~= nil then
    local plotCount:number = SafeCall(0, function() return Map.GetPlotCount(); end);
    local maxPlotsToScan:number = math.min(plotCount, 12000);
    local expansionSamples:table = {};
    local pressureSamples:table = {};

    for plotIndex = 0, maxPlotsToScan - 1, 1 do
      local plot:table = SafeCall(nil, function() return Map.GetPlotByIndex(plotIndex); end);

      if plot ~= nil then
        local plotX:number = SafeCall(-1, function() return plot:GetX(); end);
        local plotY:number = SafeCall(-1, function() return plot:GetY(); end);
        local isRevealed:boolean = plotX >= 0 and plotY >= 0 and SafeCall(false, function() return localVisibility:IsRevealed(plotX, plotY); end);

        if isRevealed then
          snapshot.revealedPlotCount = snapshot.revealedPlotCount + 1;

          if SafeCall(false, function() return localVisibility:IsVisible(plotX, plotY); end) then
            snapshot.visiblePlotCount = snapshot.visiblePlotCount + 1;
          end

          local ownerID:number = SafeCall(-1, function() return plot:GetOwner(); end);

          if ownerID == localPlayerID then
            snapshot.ownedPlotCount = snapshot.ownedPlotCount + 1;
          elseif ownerID ~= -1 then
            for _, cityCenter in ipairs(ownedCityCenters) do
              local distance:number = SafeCall(99, function() return Map.GetPlotDistance(cityCenter.x, cityCenter.y, plotX, plotY); end);

              if distance <= 5 then
                snapshot.borderPressureCount = snapshot.borderPressureCount + 1;

                if #pressureSamples < 3 then
                  table.insert(pressureSamples, "近" .. cityCenter.name .. " 距" .. tostring(distance) .. " 有他方边境");
                end

                break;
              end
            end
          elseif SafeCall(false, function() return plot:IsWater(); end) == false then
            for _, cityCenter in ipairs(ownedCityCenters) do
              local distance:number = SafeCall(99, function() return Map.GetPlotDistance(cityCenter.x, cityCenter.y, plotX, plotY); end);

              if distance >= 4 and distance <= 8 then
                snapshot.expansionCandidateCount = snapshot.expansionCandidateCount + 1;

                if #expansionSamples < 3 then
                  local featureText:string = SafeCall(false, function() return plot:IsHills(); end) and "丘陵" or "陆地";
                  table.insert(expansionSamples, "近" .. cityCenter.name .. " 距" .. tostring(distance) .. " " .. featureText);
                end

                break;
              end
            end
          end
        end
      end
    end

    snapshot.strategicMapScore =
      snapshot.cityCount * 20 +
      snapshot.ownedPlotCount +
      math.floor(snapshot.revealedPlotCount / 10) +
      snapshot.expansionCandidateCount -
      snapshot.borderPressureCount;

    table.insert(snapshot.strategicMapSamples, "已揭示" .. tostring(snapshot.revealedPlotCount) .. " 可见" .. tostring(snapshot.visiblePlotCount) .. " 本方地块" .. tostring(snapshot.ownedPlotCount));

    for _, sample in ipairs(expansionSamples) do
      if #snapshot.strategicMapSamples >= 5 then
        break;
      end

      table.insert(snapshot.strategicMapSamples, "扩张候选 " .. sample);
    end

    for _, sample in ipairs(pressureSamples) do
      if #snapshot.strategicMapSamples >= 5 then
        break;
      end

      table.insert(snapshot.strategicMapSamples, "边境压力 " .. sample);
    end
  end

  return snapshot;
end

local function RecordSnapshot(reason:string)
  local snapshot:table = CollectSnapshot();
  currentSnapshot = snapshot;
  journalSequence = journalSequence + 1;
  snapshot.reason = reason or "manual";
  snapshot.sequence = journalSequence;
  table.insert(journal, {
    turn = snapshot.turn,
    science = snapshot.science,
    culture = snapshot.culture,
    goldBalance = snapshot.goldBalance,
    goldPerTurn = snapshot.goldPerTurn,
    cityCount = snapshot.cityCount,
    firstCityPopulation = snapshot.firstCityPopulation,
    firstCityProduction = snapshot.firstCityProduction,
    reason = snapshot.reason,
    sequence = snapshot.sequence
  });

  while #journal > MAX_JOURNAL_ENTRIES do
    table.remove(journal, 1);
  end

  persistenceSaveStatus = "session_only";
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

  if isChinese then
    table.insert(lines, "后台数据状态：Obelisk 已记录当前快照。");
    table.insert(lines, "已采集：玩家产出、科技/市政候选、金币/信仰、城市、单位、间谍、资源、政策、总督、外交、城邦、胜利深层指标、伟人、商路明细、全城忠诚、战略地图评分。");
    table.insert(lines, "当前规模：回合 " .. tostring(snapshot.turn) .. "；城市 " .. tostring(snapshot.cityCount) .. "；单位 " .. AuditValue(snapshot.unitCount, "?") .. "；已见文明 " .. AuditValue(snapshot.metCivilizations, "?") .. "。");
    table.insert(lines, "后台策略：完整数据只保留当前快照；历史只保存轻量摘要，用于回合对比和之后的 AI 上下文。");
    table.insert(lines, "地图边界：战略评分只扫描已揭示/可见格子，不读取隐藏资源或敌方隐藏单位。");
    return table.concat(lines, "[NEWLINE]");
  end

  table.insert(lines, "Backend data status: Obelisk recorded the current snapshot.");
  table.insert(lines, "Captured: yields, tech/civic candidates, gold/faith, cities, units, spies, resources, policies, governors, diplomacy, city-states, deep victory metrics, great people, trade route details, all-city loyalty, strategic map scoring.");
  table.insert(lines, "Current scale: turn " .. tostring(snapshot.turn) .. "; cities " .. tostring(snapshot.cityCount) .. "; units " .. AuditValue(snapshot.unitCount, "?") .. "; met civs " .. AuditValue(snapshot.metCivilizations, "?") .. ".");
  table.insert(lines, "Storage policy: full data is current-snapshot only; history keeps compact summaries for comparison and future AI context.");
  table.insert(lines, "Map boundary: strategic scoring only scans revealed/visible plots; it does not read hidden resources or hidden enemy units.");
  return table.concat(lines, "[NEWLINE]");
end

local function BuildAdviceAnswer(snapshot:table, isChinese:boolean)
  if isChinese then
    if snapshot.cityCount <= 0 then
      return "我会先看落城位置。[NEWLINE]1. 还没有城市，优先观察首都落城位置。[NEWLINE]2. 落城后再校验科技、文化、金币和生产数据是否同步变化。";
    end

    local advice:string = "我会先看这几项：[NEWLINE]";
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
    return "I would inspect the settle location first.[NEWLINE]1. No city yet; inspect the capital settle location first.[NEWLINE]2. After settling, re-check science, culture, gold, and production changes.";
  end

  return "I would inspect these first:[NEWLINE]" ..
    "1. Cross-check top-left yields: science " .. tostring(snapshot.science) .. "/turn, culture " .. tostring(snapshot.culture) .. "/turn, gold " .. tostring(snapshot.goldPerTurn) .. "/turn.[NEWLINE]" ..
    "2. Inspect " .. snapshot.firstCityName .. "'s population and build queue. Current production: " .. snapshot.firstCityProduction .. ".[NEWLINE]" ..
    "3. This is a fixed rule response for testing data-grounded advice.";
end

local function TextContains(text:string, pattern:string)
  return text ~= nil and pattern ~= nil and string.find(text, pattern) ~= nil;
end

local function TextContainsAny(text:string, patterns:table)
  for _, pattern in ipairs(patterns) do
    if TextContains(text, pattern) then
      return true;
    end
  end

  return false;
end

local function IsEarlyEra(eraName:string)
  local era:string = tostring(eraName or "");
  return era == "" or
    TextContains(era, "远古") or
    TextContains(era, "古典") or
    TextContains(string.lower(era), "ancient") or
    TextContains(string.lower(era), "classical");
end

local function NewFlowScore(id:string, name:string, goal:string)
  return {
    id = id,
    name = name,
    goal = goal,
    score = 0,
    maxScore = 0,
    blockers = {},
    warnings = {},
    matched = {},
    checks = {}
  };
end

local function AddFlowCondition(flow:table, passed:boolean, weight:number, matchedText:string, failedText:string, checkText:string, isBlocking:boolean)
  flow.maxScore = flow.maxScore + weight;

  if passed then
    flow.score = flow.score + weight;
    if matchedText ~= nil and matchedText ~= "" then
      table.insert(flow.matched, matchedText);
    end
  else
    if isBlocking then
      table.insert(flow.blockers, failedText);
    else
      table.insert(flow.warnings, failedText);
    end
  end

  if checkText ~= nil and checkText ~= "" then
    table.insert(flow.checks, checkText);
  end
end

local function FinalizeFlowScore(flow:table)
  if flow.maxScore > 0 then
    flow.score = math.floor((flow.score * 100 / flow.maxScore) + 0.5);
  end

  if #flow.blockers > 0 and flow.score > 35 then
    flow.score = 35;
  end

  if #flow.blockers > 0 then
    flow.fit = "不适合";
  elseif flow.score >= 75 then
    flow.fit = "适合";
  elseif flow.score >= 50 then
    flow.fit = "有条件适合";
  elseif flow.score >= 30 then
    flow.fit = "偏弱";
  else
    flow.fit = "不适合";
  end

  return flow;
end

local function ScoreXiaomaFlow(snapshot:table)
  local flow:table = NewFlowScore("xiaoma", "小马流", "用早期骑兵窗口压制近邻或夺取关键城市");
  local horseCount:number = snapshot.horseCount or 0;

  AddFlowCondition(flow, horseCount > 0, 30, "已看到马资源 " .. tostring(horseCount), "没有稳定马资源", "资源栏 / 地图马资源", true);
  AddFlowCondition(flow, IsEarlyEra(snapshot.eraName), 20, "仍在早期骑兵窗口", "时代窗口偏晚", "右上角时代信息", true);
  AddFlowCondition(flow, (snapshot.majorContacts or 0) >= 1, 15, "已见主要文明 " .. tostring(snapshot.majorContacts or 0), "还没有明确主要文明目标", "外交面板 / 已见文明", false);
  AddFlowCondition(flow, (snapshot.goldPerTurn or 0) >= 5, 15, "金币收入可支撑维护", "金币收入偏低，维护和升级有压力", "顶部金币收入", false);
  AddFlowCondition(flow, snapshot.militaryStrength == nil or snapshot.militaryStrength >= 80, 10, "军力不是明显短板", "当前军力偏弱，窗口还没形成", "外交界面 / 军力对比", false);

  table.insert(flow.checks, "科技树：是否接近骑马");
  table.insert(flow.checks, "目标城市：是否已有城墙或反骑兵单位");
  return FinalizeFlowScore(flow);
end

local function ScoreCampusFlow(snapshot:table)
  local flow:table = NewFlowScore("campus", "学院流", "用学院和科研积累建立科技领先或追赶能力");

  AddFlowCondition(flow, (snapshot.science or 0) < 35, 20, "科研仍有提升空间", "当前科研压力不高，学院不是唯一短板", "顶部科研 / 科技树", false);
  AddFlowCondition(flow, (snapshot.cityCount or 0) >= 2, 20, "城市数能承载学院投资", "城市太少，通常先扩张更稳", "城市数量 / 城市总览", true);
  AddFlowCondition(flow, (snapshot.averageCityProduction or 0) >= 6, 15, "平均产能可支撑区域建设", "城市产能偏低，硬造学院会拖节奏", "城市生产力 / 建造回合", false);
  AddFlowCondition(flow, (snapshot.atWarCount or 0) == 0, 10, "没有被战争强迫转产", "战争压力下学院优先级下降", "外交面板 / 战争状态", false);
  AddFlowCondition(flow, true, 15, "科技路线对通用发展有效", "", "当前科技 / 尤里卡候选", false);

  table.insert(flow.checks, "地图：山脉、礁石、地热的学院相邻");
  table.insert(flow.checks, "城市：哪座城能最快完成学院");
  return FinalizeFlowScore(flow);
end

local function ScoreTradeRouteFlow(snapshot:table)
  local flow:table = NewFlowScore("trade", "大商路流", "通过商路容量、金币、道路和城邦滚动经济优势");
  local activeRoutes:number = snapshot.tradeRouteActive or 0;
  local capacity:number = snapshot.tradeRouteCapacity or 0;
  local unusedRoutes:number = math.max(0, capacity - activeRoutes);

  AddFlowCondition(flow, capacity > 0, 25, "已有商路容量 " .. tostring(capacity), "没有商路容量，无法启动商路流", "顶部商路容量", true);
  AddFlowCondition(flow, unusedRoutes > 0, 25, "存在空余商路 " .. tostring(unusedRoutes), "商路已跑满，继续补商人收益下降", "顶部商路容量 / 商人单位", false);
  AddFlowCondition(flow, (snapshot.minorContacts or 0) >= 1, 10, "已遇见城邦 " .. tostring(snapshot.minorContacts or 0), "外部商路目标不足", "城邦面板 / 外交面板", false);
  AddFlowCondition(flow, (snapshot.goldPerTurn or 0) < 20, 15, "金币仍有提升空间", "金币收入已较高，商路不一定是最短板", "顶部金币收入", false);

  if (snapshot.atWarCount or 0) > 0 then
    table.insert(flow.warnings, "战争状态下商人路线有被掠夺风险");
  end

  table.insert(flow.checks, "路线安全：蛮族、战争、敌军位置");
  table.insert(flow.checks, "路线选择：内商补生产/食物，外商补金币/城邦收益");
  return FinalizeFlowScore(flow);
end

local function ScoreAllFlows(snapshot:table)
  local flows:table = {
    ScoreXiaomaFlow(snapshot),
    ScoreCampusFlow(snapshot),
    ScoreTradeRouteFlow(snapshot)
  };

  table.sort(flows, function(left:table, right:table) return left.score > right.score; end);
  return flows;
end

local function BuildFlowAnswer(flow:table)
  local reasons:string = #flow.matched > 0 and table.concat(flow.matched, "；") or "核心条件不足";
  local problems:table = {};

  for _, blocker in ipairs(flow.blockers) do
    table.insert(problems, blocker);
  end

  for _, warning in ipairs(flow.warnings) do
    table.insert(problems, warning);
  end

  local problemText:string = #problems > 0 and table.concat(problems, "；") or "暂无明显阻断项";
  local checkText:string = #flow.checks > 0 and table.concat(flow.checks, "；") or "继续观察当前局势";

  return flow.name .. "：" .. flow.fit .. "，适配评分 " .. tostring(flow.score) .. "/100。[NEWLINE]" ..
    "判断依据：" .. reasons .. "。[NEWLINE]" ..
    "风险/缺口：" .. problemText .. "。[NEWLINE]" ..
    "你下一步应在游戏里看：" .. checkText .. "。[NEWLINE]" ..
    "这不是替你下指令，只是把当前可见局势和规则条件对齐。";
end

local function BuildFlowRankingAnswer(snapshot:table)
  local flows:table = ScoreAllFlows(snapshot);
  local lines:table = {
    "当前更适合的流派排序："
  };

  for index:number = 1, #flows do
    local flow:table = flows[index];
    table.insert(lines, tostring(index) .. ". " .. flow.name .. "：" .. tostring(flow.score) .. "/100，" .. flow.fit);
  end

  table.insert(lines, "建议先看第一名的风险项，再决定是否执行。");
  table.insert(lines, "可继续问：为什么不适合小马流？/ 学院流下一步看什么？/ 大商路流缺什么？");
  return table.concat(lines, "[NEWLINE]");
end

local function BuildNextStepAnswer(snapshot:table)
  local flows:table = ScoreAllFlows(snapshot);
  local best:table = flows[1];

  return "我会先按三个层级检查当前局势：[NEWLINE]" ..
    "1. 基础盘：城市 " .. tostring(snapshot.cityCount) .. "，平均产能 " .. AuditValue(snapshot.averageCityProduction, "?") .. "，科技 " .. tostring(snapshot.science) .. "/回合，文化 " .. tostring(snapshot.culture) .. "/回合。[NEWLINE]" ..
    "2. 执行资源：金币 " .. tostring(snapshot.goldPerTurn) .. "/回合，马 " .. tostring(snapshot.horseCount or 0) .. "，商路 " .. AuditValue(snapshot.tradeRouteActive, "?") .. "/" .. AuditValue(snapshot.tradeRouteCapacity, "?") .. "。[NEWLINE]" ..
    "3. 外部机会：已见文明 " .. AuditValue(snapshot.majorContacts, "?") .. "，城邦 " .. AuditValue(snapshot.minorContacts, "?") .. "，战争数 " .. AuditValue(snapshot.atWarCount, "?") .. "。[NEWLINE]" ..
    "当前规则匹配最高的是：" .. best.name .. "（" .. tostring(best.score) .. "/100，" .. best.fit .. "）。[NEWLINE]" ..
    "下一步优先确认：" .. table.concat(best.checks, "；") .. "。";
end

local function BuildQuestionAnswer(snapshot:table, isChinese:boolean, question:string)
  local query:string = question or "";

  if isChinese then
    if TextContainsAny(query, { "更适合", "哪个流派", "流派排序", "小马流还是", "学院流还是", "商路流还是" }) then
      return BuildFlowRankingAnswer(snapshot);
    end

    if TextContainsAny(query, { "小马", "骑兵", "马" }) then
      return BuildFlowAnswer(ScoreXiaomaFlow(snapshot));
    end

    if TextContainsAny(query, { "学院", "科技", "科研" }) then
      return BuildFlowAnswer(ScoreCampusFlow(snapshot));
    end

    if TextContainsAny(query, { "商路", "贸易", "商人" }) then
      return BuildFlowAnswer(ScoreTradeRouteFlow(snapshot));
    end

    if TextContainsAny(query, { "适合", "该干嘛", "关注", "下一步", "建议", "现在做什么" }) then
      return BuildNextStepAnswer(snapshot);
    end

    return "当前版本先使用本地知识库评分，不接大模型，也不替玩家直接下指令。[NEWLINE]" ..
      "你可以验收这些问题：[NEWLINE]" ..
      "1. 我现在适合玩小马流吗？[NEWLINE]" ..
      "2. 我现在适合学院流吗？[NEWLINE]" ..
      "3. 我现在适合大商路流吗？[NEWLINE]" ..
      "4. 我现在更适合小马流还是学院流？[NEWLINE]" ..
      "5. 我下一步应该关注什么？";
  end

  if TextContainsAny(string.lower(query), { "horse", "cavalry" }) then
    return BuildFlowAnswer(ScoreXiaomaFlow(snapshot));
  end

  if TextContainsAny(string.lower(query), { "campus", "science" }) then
    return BuildFlowAnswer(ScoreCampusFlow(snapshot));
  end

  if TextContainsAny(string.lower(query), { "trade", "merchant" }) then
    return BuildFlowAnswer(ScoreTradeRouteFlow(snapshot));
  end

  return "This build uses the local knowledge matcher, not a large model yet.[NEWLINE]" ..
    "Try: Am I suited for a horse rush? / Am I suited for a campus strategy? / What should I focus on next?";
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
  if not persistenceLoadAttempted then
    LoadPersistedJournal();
  end

  local lastEntry:table = nil;

  if #journal > 0 then
    lastEntry = journal[#journal];
  end

  local lastTurn:string = lastEntry ~= nil and tostring(lastEntry.turn) or "-";
  local lastReason:string = lastEntry ~= nil and tostring(lastEntry.reason or "-") or "-";

  if isChinese then
    return "记忆状态：[NEWLINE]" ..
      "会话摘要：" .. tostring(#journal) .. "/" .. tostring(MAX_JOURNAL_ENTRIES) .. " 条；完整数据只保留当前快照。[NEWLINE]" ..
      "读取状态：" .. StatusText(persistenceLoadStatus, true) .. "。[NEWLINE]" ..
      "写入状态：" .. StatusText(persistenceSaveStatus, true) .. "。[NEWLINE]" ..
      "最后记录：回合 " .. lastTurn .. "，来源 " .. lastReason .. "。[NEWLINE]" ..
      "当前快照：回合 " .. tostring(snapshot.turn) .. "，城市 " .. tostring(snapshot.cityCount) .. "，金币 " .. tostring(snapshot.goldBalance) .. "。";
  end

  return "Memory status:[NEWLINE]" ..
    "Session summaries: " .. tostring(#journal) .. "/" .. tostring(MAX_JOURNAL_ENTRIES) .. "; full data is current-snapshot only.[NEWLINE]" ..
    "Load status: " .. StatusText(persistenceLoadStatus, false) .. ".[NEWLINE]" ..
    "Save status: " .. StatusText(persistenceSaveStatus, false) .. ".[NEWLINE]" ..
    "Last record: turn " .. lastTurn .. ", reason " .. lastReason .. ".[NEWLINE]" ..
    "Current snapshot: turn " .. tostring(snapshot.turn) .. ", cities " .. tostring(snapshot.cityCount) .. ", gold " .. tostring(snapshot.goldBalance) .. ".";
end

local function RefreshAnswer(mode:string, recordReason:string)
  currentMode = mode or currentMode;
  local snapshot:table = RecordSnapshot(recordReason or currentMode);
  local isChinese:boolean = IsChineseUI();

  local fallbackQuestion:string = currentQuestion ~= "" and currentQuestion or "Ask Obelisk";
  local fallbackMetrics:string = "Turn {1} · Cities {6} · Obelisk reads visible state only";
  local answer:string = BuildQuestionAnswer(snapshot, isChinese, currentQuestion);

  if isChinese then
    fallbackQuestion = currentQuestion ~= "" and currentQuestion or "向 Obelisk 提问";
    fallbackMetrics = "基于当前可见局势回答 · 回合 {1} · 城市 {6}";
  end

  if currentMode == "data" then
    answer = BuildQuestionAnswer(snapshot, isChinese, currentQuestion);
  end

  if currentMode == "advice" then
    answer = BuildQuestionAnswer(snapshot, isChinese, currentQuestion);
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
    fallbackQuestion = isChinese and "Obelisk 后台状态如何？" or "What is Obelisk's backend status?";
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

local function GetQueryPlaceholder()
  return IsChineseUI() and "问 Obelisk：这局我该关注什么？" or "Ask Obelisk: what should I focus on?";
end

local function NormalizeQueryText(value:string)
  if value == nil or type(value) ~= "string" then
    return "";
  end

  local placeholder:string = GetQueryPlaceholder();

  if value == placeholder then
    return "";
  end

  return value;
end

local function SubmitQuery(textString:string)
  local query:string = NormalizeQueryText(textString);

  if query == "" and Controls.QueryEditBox ~= nil then
    query = NormalizeQueryText(Controls.QueryEditBox:GetText());
  end

  currentQuestion = query ~= "" and query or GetQueryPlaceholder();
  currentMode = "advice";
  SetExpanded(true);

  if Controls.QueryEditBox ~= nil then
    isResettingQueryBox = true;
    Controls.QueryEditBox:ClearString();
    isResettingQueryBox = false;
  end
end

local function OnQueryChanged()
  if isResettingQueryBox then
    return;
  end

  if Controls.QueryEditBox ~= nil then
    currentQuestion = NormalizeQueryText(Controls.QueryEditBox:GetText());
  end
end

local function OnQueryFocus()
  if Controls.QueryEditBox ~= nil and Controls.QueryEditBox:GetText() == GetQueryPlaceholder() then
    Controls.QueryEditBox:ClearString();
  end
end

local function OnAsk()
  currentMode = "advice";
  SetExpanded(true);
end

local function OnSubmit()
  SubmitQuery("");
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
  if isExpanded then
    RefreshAnswer(currentMode, "turn_begin_refresh");
  end
end

local function Initialize()
  ContextPtr:SetHide(false);

  if Controls.QueryEditBox ~= nil then
    Controls.QueryEditBox:SetText(GetQueryPlaceholder());
  end

  if Controls.SubmitButton ~= nil then
    Controls.SubmitButton:SetText(IsChineseUI() and "发送" or "Ask");
  end

  if Controls.DataButton ~= nil then
    Controls.DataButton:SetHide(true);
    Controls.DataButton:SetText(IsChineseUI() and "当前数据" or "Data");
  end

  if Controls.AdviceButton ~= nil then
    Controls.AdviceButton:SetHide(true);
    Controls.AdviceButton:SetText("");
  end

  if Controls.CompareButton ~= nil then
    Controls.CompareButton:SetHide(true);
    Controls.CompareButton:SetText(IsChineseUI() and "回合对比" or "Compare");
  end

  if Controls.MemoryButton ~= nil then
    Controls.MemoryButton:SetHide(true);
    Controls.MemoryButton:SetText(IsChineseUI() and "记忆状态" or "Memory");
  end

  if Controls.CitiesButton ~= nil then
    Controls.CitiesButton:SetHide(true);
    Controls.CitiesButton:SetText(IsChineseUI() and "城市总览" or "Cities");
  end

  if Controls.AuditButton ~= nil then
    Controls.AuditButton:SetHide(true);
    Controls.AuditButton:SetText(IsChineseUI() and "后台状态" or "Backend");
  end

  ContextPtr:SetUpdate(function(deltaTime:number)
    if isExpanded then
      collapseElapsed = collapseElapsed + deltaTime;

      if collapseElapsed >= AUTO_COLLAPSE_SECONDS then
        SetExpanded(false);
      end
    end
  end);

  if Controls.QueryEditBox ~= nil then
    Controls.QueryEditBox:RegisterCommitCallback(SubmitQuery);
    Controls.QueryEditBox:RegisterStringChangedCallback(OnQueryChanged);
    Controls.QueryEditBox:RegisterHasFocusCallback(OnQueryFocus);
  end

  if Controls.SubmitButton ~= nil then
    Controls.SubmitButton:RegisterCallback(Mouse.eLClick, OnSubmit);
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

  SetExpanded(false);
  print("Obelisk UI context loaded.");
end

Initialize();
