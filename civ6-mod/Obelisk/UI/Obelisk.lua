-- Obelisk: first in-game UI context prototype.
-- This file intentionally avoids gameplay changes. It only proves that the
-- overlay context can load and respond inside Civilization VI.

local AUTO_COLLAPSE_SECONDS:number = 8;
local isExpanded:boolean = false;
local collapseElapsed:number = 0;

local function SetExpanded(expanded:boolean)
  isExpanded = expanded;
  collapseElapsed = 0;

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
