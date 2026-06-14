# Project Obelisk 进度台账

本文档用于记录 Project Obelisk 的开发目标、当前进度、重要更新和验证结果。之后每轮开发都应更新本文档，避免只依赖聊天上下文。

## 工作约定

- 用户在当前 Windows 电脑的 Civilization VI 实机环境中验证整个 mod。
- Codex 负责代码修改、静态检查、安装/同步辅助、验证清单整理。
- 每轮代码更新后，应同步推送到 GitHub 远端分支 `codex/civ6-ingame-ui`。
- 每轮重要变更后，应更新本文档的“当前目标”“进度状态”“更新记录”和“验证记录”。
- 面向用户的验证清单使用中文，且只包含本轮新增或有回归风险的行为。

## 仓库与分支

- 远端仓库：`https://github.com/zyfay518/civVI_obelisk.git`
- 当前开发分支：`codex/civ6-ingame-ui`
- 当前本地路径：`C:\Users\张三一\Documents\CIV VI\civVI_obelisk`
- 当前 mod 源目录：`civ6-mod/Obelisk`

## 产品目标

Project Obelisk 是一个 Civilization VI 游戏内认知助手，帮助玩家理解可见游戏状态，但不替玩家操作游戏。

新增产品方向：建设一个可检索知识库，用来沉淀网上收集到的玩家 tips、机制解释、开局思路、文明/政策/科技路线经验。AI 回答玩家问题时应结合“当前可见游戏状态 + 知识库经验”，但知识库内容需要保留来源、版本/资料片适用性和可信度标记，避免把过期或错误攻略当作事实。

边界：

- 只读取玩家可见、合法的 Civ VI Lua API 数据。
- 不读取进程内存。
- 不注入游戏进程。
- 不自动点击、移动、购买、结束回合或执行任何游戏动作。
- 不暴露战争迷雾或隐藏信息。
- AI/API 密钥不得放进 Lua 或 Civ VI mod。

## 当前阶段

Phase 1：后台数据完整性已基本完成，UI 保持紧凑。

当前重点：

1. 后台快照字段进入“按问题补缺”阶段，不再盲目追求全量接入。
2. 下一阶段重点转向 Python Consul / AI 回答层 / 知识库检索。
3. UI 只展示摘要和有用答案，不展示长原始数据 dump。

## 进度状态

已完成：

- Obelisk 游戏内顶部面板。
- 中文 UI 文案适配。
- 当前数据、规则建议、回合对比、记忆状态、城市总览、后台状态按钮。
- 显式交互时采集当前快照。
- 当前 Lua 会话内保留完整 `currentSnapshot`。
- 历史只保留轻量摘要，不把完整嵌套快照写入 Civ VI player properties。
- 多城市、政策、资源、宗教、伟人、贸易路线数量、忠诚度相关数据已进入稳定方向。
- 后台状态已改为紧凑状态摘要。
- 科技/市政候选、商路明细、城邦详情、胜利深层指标、总督、间谍、战略地图评分边界版已通过 Windows Civ VI 实机验证。
- 每个城市的 `citySnapshot` 已包含后台忠诚度字段：
  - `loyalty`
  - `loyaltyMax`
  - `loyaltyPerTurn`
  - `loyaltyLevel`

本轮待验证：

1. 暂无。下一阶段重点转向知识库、Python Consul 和 AI 回答质量优化。

待做：

1. 设计玩家 tips 知识库：资料来源、结构、可信度、版本适用性、检索方式。
2. 后续接入 Python Consul 和 AI 回答质量优化。
3. 按实际提问暴露出的缺口继续补专项数据，而不是一次性接入所有 Civ VI API 数据。

高风险暂缓：

- 暂无。后续重点转向 Python Consul 和 AI 回答质量优化。

## 重要更新记录

### 2026-06-14

- 确认 Windows 本机可作为 Civ VI 实机验证环境。
- 新增本文档作为长期进度台账。
- 确认下一轮工作流：本机实机验证、代码更新、同步推送 GitHub、更新本文档。
- 检查 `Obelisk.lua` 后发现全城市忠诚度字段已在每个 `citySnapshot` 中采集，读取路径只使用 `city:GetCulturalIdentity()`。
- 更新后台状态文案：从“首城忠诚”改为“全城忠诚”。
- 更新 `schemas/game_state_snapshot.example.json`，加入城市忠诚度字段示例。
- 已把当前 mod 复制到 Windows Civ VI Mods 目录，准备进行本机实机测试。
- 修复“已见文明数”口径：不再把所有已见玩家都计入文明数，改为只统计 `IsMajor()` 为真的主要文明。
- 接入一批低风险后台-only 数据：商路明细样本、科技/市政候选、城邦详情、胜利深层指标。
- 接入总督后台-only 数据：总督点数、已花费点数、可任命/可晋升状态、总督样本。读取依据来自官方 UI 的 `player:GetGovernors()`、`GetGovernorList()`、`governor:GetAssignedCity()`、`governor:IsEstablished()`。
- 接入间谍后台-only 数据：容量、数量、待命/任务中/被俘/返程中数量和样本。读取依据来自官方 UI 的 `unit:GetSpyOperation()`、`unit:GetSpyOperationEndTurn()`、`playerDiplomacy:GetSpyCapacity()`、`GetNumSpiesOffMap()`、`GetNthCapturedSpy()`。
- 接入战略地图评分边界版：只扫描 `PlayersVisibility[localPlayerID]:IsRevealed/IsVisible` 允许的地块，统计已揭示、可见、本方地块、近城扩张候选、边境压力和综合评分；不读取隐藏资源或敌方隐藏单位。
- 新增产品需求：建立玩家 tips 知识库，用于收集网上玩家经验、机制解释和策略建议；AI 回答时结合当前局面数据和知识库检索结果。知识库内容需要记录来源、版本/资料片适用性、可信度和更新时间。
- 新增知识库结构设计文档 `docs/KNOWLEDGE_BASE_DESIGN.md`：定义规则层、机制解释层、玩家攻略层，以及攻略条目的适用条件、建议、反例、来源和可信度字段。
- 扩展知识库设计：玩家攻略可来自论坛、Bilibili/YouTube 视频、图文攻略和个人复盘；入库前需要先整理为文字策略条目，再与底层规则层做一致性校验，通过后才进入可检索攻略库。
- 初始化知识库数据目录 `knowledge/`：加入规则层、机制解释层、玩家攻略层的首批 JSON 种子数据，以及论坛/视频来源采集模板、待校验 claim 模板和攻略条目示例 schema。
- 扩展文明 6 底层规则库第一版：新增城市、区域、科技/市政、政体/政策/总督、外交/城邦、宗教、胜利、战争、经济/资源、地图/改良、间谍、时代/世界议会/气候等 12 个规则文件，共 47 条结构化规则，用于后续校验网络玩家攻略。
- 落地本地知识库 MVP：新增 `python-consul/obelisk_knowledge/`，可读取 JSON 规则/流派，基于 mock game state 对“小马流、学院流、大商路流”进行本地评分、解释适合/不适合原因，并输出玩家可在游戏内查看的数据位置。

## Windows 本机安装状态

当前已安装到：

```text
C:\Users\张三一\Documents\My Games\Sid Meier's Civilization VI\Mods\Obelisk
```

源目录：

```text
C:\Users\张三一\Documents\CIV VI\civVI_obelisk\civ6-mod\Obelisk
```

测试状态：

```text
Passed owner validation in Windows Civ VI.
```

## 当前验证清单

验证版本：
Windows Civ VI 战略地图评分边界版

验证目标：
确认可见性边界内的地图评分不会导致崩溃或明显卡顿，且 UI 仍保持紧凑摘要。

本轮必测项：

[ ] 1. 操作：读取当前存档，等待 10-20 秒
    预期：游戏不崩溃、不卡死，Obelisk 正常出现
    实际：待验证

[ ] 2. 操作：打开 Obelisk，点击“后台状态”
    预期：不崩溃；已采集文案包含“战略地图评分”；不出现地图 raw dump
    实际：待验证

## 最近验证记录

### 2026-06-14

- 本轮新增后台-only 字段：战略地图评分边界版，包括已揭示地块、可见地块、本方地块、近城扩张候选、边境压力和综合评分。
- 读取边界：只使用 `PlayersVisibility[localPlayerID]:IsRevealed/IsVisible` 允许的地块；不读取隐藏资源或敌方隐藏单位。
- 验证结果：Windows Civ VI 战略地图评分边界版通过，用户确认 ok。

### 2026-06-14

- 本轮新增后台-only 字段：间谍容量、总数、任务中、待命、被俘、返程中数量和样本（名称、任务、城市、剩余回合或被俘文明）。
- 读取依据：官方 UI 使用 `unit:GetSpyOperation()`、`unit:GetSpyOperationEndTurn()`、`playerDiplomacy:GetSpyCapacity()`、`GetNumSpiesOffMap()`、`GetNthCapturedSpy()`。
- 验证结果：Windows Civ VI 间谍后台字段版通过，用户确认 ok。

### 2026-06-14

- 本轮新增后台-only 字段：总督点数、已花费点数、可任命/可晋升状态、总督样本（名称、所在城市、已就位或建立剩余回合）。
- 读取依据：官方 UI 使用 `player:GetGovernors()`、`GetGovernorList()`、`governor:GetAssignedCity()`、`governor:IsEstablished()`。
- 验证结果：Windows Civ VI 总督后台字段版通过，用户确认“有总督”。

### 2026-06-14

- 本轮新增后台-only 字段：
  - 商路明细样本：起点、终点、收益样本、剩余回合字段尝试读取、进入本方城市商路数量。
  - 科技/市政候选：可选项、进度、剩余回合、尤里卡/鼓舞状态。
  - 城邦详情：城邦类型、使者、宗主、任务数量。
  - 胜利深层指标：文化游客、宗教城市、外交胜利点、科技胜利项目进度样本。
- 战略地图评分边界版已接入，待 Windows Civ VI 实机验证。
- 验证结果：Windows Civ VI 后台数据扩展版通过。

### 2026-06-14

- 验证环境：Windows 本机 Civilization VI。
- 验证结果：通过。
- 通过项：
  - 读取当前存档等待 10-20 秒后不崩溃，Obelisk 正常出现。
  - 点击“后台状态”不崩溃，已采集文案包含“科技/市政候选、城邦、胜利深层指标、商路明细”。
  - 点击“当前数据”“规则建议”“城市总览”不崩溃，不出现长 raw dump，原有摘要仍可读。

### 2026-06-14

- 用户发现 bug：6 文明局中实际已遇见 2 个文明，但后台状态显示已见文明数为 9。
- 原因判断：旧逻辑只按 `HasMet()` 统计所有已见玩家，城邦等非主要玩家也被算入“文明”。
- 修复方式：`metCivilizations` 改为复用按 `IsMajor()` 过滤后的 `majorContacts`。
- 待验证：后台状态中的已见文明数应显示 2。

### 2026-06-14

- 验证环境：Windows 本机 Civilization VI。
- 验证结果：通过。
- 通过项：
  - 进入/读取存档等待 10-20 秒后不崩溃，Obelisk 正常出现。
  - 点击“后台状态”不崩溃，紧凑状态出现，已采集里包含“全城忠诚”。
  - 点击“城市总览”不出现逐城忠诚度原始长列表。

## 云端同步状态

当前注意事项：

- 本地仓库是通过 GitHub 分支 zip 恢复后 `git init` 得到的工作区，不是完整 `git clone` 历史。
- 之前 `git clone` 访问 GitHub 时出现连接重置/超时。
- 已另建正常 clone 工作区 `C:\Users\张三一\Documents\CIV VI\civVI_obelisk_git`，并创建本地提交 `f1b6d1e Document Windows validation workflow`。
- 当前提交已领先远端 1 个提交，但 `git push` 因 GitHub 443 连接超时尚未完成。
- 后续要推送到云端，需要完成其中一种方式：
  1. 网络恢复后重新 `git clone` 正常仓库，再迁移当前改动。
  2. 在当前工作区建立首个提交并 force/push 到远端分支，只有在确认不会覆盖远端历史时才可做。
  3. 使用 GitHub connector/API 创建提交，绕过本机 git 网络问题。

推荐策略：

- 优先恢复正常 `git clone` 历史。
- 不在未确认远端状态时强推。
- 每轮本地改动完成后先记录本文档，再处理提交和推送。

## 下一步

1. 将真实 Lua Beacon 快照字段映射到 `obelisk_knowledge` matcher 所需的标准 state。
2. 设计 AI 回答链路：当前快照数据 + 底层规则 + 玩家攻略检索 + 可解释建议。
3. 后续开始逐批采集网络玩家攻略，并先进入 `knowledge/review/` 做规则校验。
4. 后续按真实提问暴露的数据缺口继续补专项字段。
5. 解决 GitHub push 连接超时问题。
