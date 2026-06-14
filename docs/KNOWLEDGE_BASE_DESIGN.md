# Project Obelisk 知识库结构设计

本文档定义 Project Obelisk 的知识库结构。目标是让 AI 在回答玩家问题时，同时利用：

1. 当前游戏快照：玩家这一局现在发生了什么。
2. 游戏规则知识：文明 6 本身稳定、可验证的机制。
3. 玩家攻略经验：来自社区、视频、论坛、Wiki、个人复盘的策略建议。

知识库不是简单的文本堆积。每条攻略都必须带有适用条件、可信度、来源和结论类型，避免 AI 把过期攻略或特定场景经验当成通用规则。

## 总体分层

### Layer 0：游戏规则层

用途：记录 Civilization VI 本身的稳定规则和机制。

特点：

- 尽量来自游戏内文本、官方规则、Civilopedia、可验证数据表或稳定 Wiki。
- 低主观性，高可信度。
- 用来回答“机制是什么”“为什么会这样”。
- 规则层优先级高于玩家攻略层。

示例内容：

- 尤里卡/鼓舞如何减少科技/市政成本。
- 宜居度、住房、忠诚度、宗教压力的基础规则。
- 区域相邻加成规则。
- 城邦使者、宗主奖励、外交能见度规则。
- 胜利条件的触发机制。

### Layer 1：机制解释层

用途：把规则转换成玩家能理解的解释和判断模板。

特点：

- 仍然偏客观，但可以包含一些经验化阈值。
- 用来解释“这个数值意味着什么”。
- 可以被多个攻略条目复用。

示例内容：

- “科技落后但文化领先”通常意味着政策/政体可能能补经济，但军事科技风险上升。
- “住房不足”会限制人口增长，影响区域槽位和产出扩张。
- “商路容量未用满”通常代表经济、外交、道路、城邦收益有机会。

### Layer 2：玩家攻略层

用途：记录玩家经验、打法、优先级建议、文明/地图/胜利类型策略。

特点：

- 主观性更强，必须带来源、适用条件和可信度。
- 不能直接覆盖规则层。
- AI 使用时应表述为“经验建议”，不是硬规则。
- 同一问题可以检索多条攻略，再综合当前局面给建议。

示例内容：

- “神标盘古早期优先铺 3-4 城，比早奇观更稳定。”
- “文化胜利中期要提前规划国家公园、摇滚乐队、开放边境和商路。”
- “德国适合利用汉萨相邻构建高锤城市群。”

## 攻略条目结构

玩家攻略不建议只存 Markdown 段落。推荐使用结构化条目，每条条目表达一个相对独立的经验判断。

### 字段定义

```yaml
id: tip_early_expansion_001
type: heuristic
title: 早期扩张优先级
summary: 前 50-80 回合通常应优先保证城市数量，而不是过早投入高成本奇观。
body: >
  在多数标准速度对局中，早期城市数量决定区域槽位、人口、产出和战略资源覆盖。
  如果当前只有 1-2 城且周围仍有可扩张空间，继续铺城通常比早期奇观更稳。

game_scope:
  game: Civilization VI
  ruleset: Gathering Storm
  speed: Standard
  difficulty: ["Emperor", "Immortal", "Deity"]
  map_types: ["Pangaea", "Continents", "Default"]

applicability:
  phases: ["Ancient", "Classical"]
  victory_types: ["Science", "Culture", "Domination", "General"]
  civilizations: ["Any"]
  conditions:
    - city_count <= 2
    - revealed_expansion_candidates > 0
    - at_war_count == 0

recommendation:
  action: prioritize_expansion
  priority: high
  advice: 优先造/买移民，确保 3-4 城基础盘。
  avoid: 不要在扩张空间充足时过早投入高成本奇观。

evidence:
  rationale:
    - 城市数量会扩大区域槽位和总产出上限。
    - 早期高成本奇观会占用关键生产力窗口。
  counter_examples:
    - 如果首都极高锤且奇观有明确胜利路线价值，可以例外。
    - 如果周围无安全扩张空间，应优先军事或防守。

source:
  url: https://example.com/source
  author: example_author
  collected_at: 2026-06-14
  source_type: forum_post

quality:
  confidence: medium
  consensus: common
  freshness: stable
  verified_by_owner: false

retrieval:
  tags:
    - early_game
    - expansion
    - city_count
    - production_priority
  keywords:
    - 铺城
    - 移民
    - 早期扩张
    - 奇观
```

## 条目类型

### `rule`

稳定规则。适合 Layer 0。

用于：

- 游戏机制说明。
- 数值公式。
- 胜利条件。
- UI 指标解释。

### `explanation`

机制解释。适合 Layer 1。

用于：

- 把规则翻译成玩家语言。
- 解释某个状态为什么危险或有利。
- 帮 AI 生成原因说明。

### `heuristic`

经验规则。适合 Layer 2。

用于：

- “通常应该……”
- “大多数情况下……”
- “如果满足这些条件，优先……”

### `build_order`

开局或阶段路线。

用于：

- 文明专属开局。
- 胜利类型路线。
- 特定地图/难度打法。

### `anti_pattern`

常见错误。

用于：

- 过早造奇观。
- 商路容量闲置。
- 不触发尤里卡硬研高成本科技。
- 城市过密或过疏。

### `case_study`

具体复盘案例。

用于：

- 保存玩家局面和决策结果。
- 作为参考，不作为通用规则。

## 攻略条目的核心设计原则

### 1. 必须有适用条件

攻略最容易出错的地方是脱离上下文。每条攻略都应尽量写清：

- 游戏阶段。
- 胜利目标。
- 文明或领袖。
- 难度。
- 地图类型。
- 是否战争中。
- 城市数量、科技/文化状态、经济状态等局面条件。

如果适用条件不清楚，`confidence` 必须降低。

### 2. 必须区分结论和依据

不要只存“应该做 X”。要拆成：

- 当前满足什么条件。
- 为什么这条经验适用。
- 建议做什么。
- 有哪些例外。

AI 回答时需要用这些字段生成“可解释建议”，而不是只给命令。

### 3. 必须保留反例

文明 6 的攻略通常有大量例外。反例字段非常重要。

示例：

- “早期别造奇观”有例外：埃及、秦始皇、特定文化胜利路线、高锤首都。
- “多铺城”有例外：忠诚压力极大、战争威胁、地块质量太差。

### 4. 必须保留来源和可信度

来源不只是版权和引用问题，也是质量控制问题。

建议记录：

- URL。
- 作者。
- 收集时间。
- 来源类型：Wiki、论坛、Bilibili、YouTube、Reddit、Steam guide、个人复盘。
- 是否被用户确认有效。
- 是否存在版本风险。

## 检索时如何使用

AI 回答问题时，不应该把所有知识库内容塞进 prompt。推荐流程：

1. 从当前快照提取查询信号：
   - 时代、城市数、产出、科技/文化差距、胜利方向、战争状态、商路、城邦、总督、间谍、地图评分。
2. 生成检索查询：
   - 用户问题关键词。
   - 当前局面标签。
   - 可能相关的机制标签。
3. 检索候选条目：
   - 先规则层，再机制解释层，再玩家攻略层。
4. 过滤不适用条目：
   - 版本不匹配。
   - 文明/时代/胜利类型明显不匹配。
   - 条件与当前快照冲突。
5. 生成回答：
   - 先说当前局面事实。
   - 再引用适用的规则/攻略经验。
   - 最后给 1-3 条行动建议。

## 推荐目录结构

```text
knowledge/
  rules/
    core_mechanics.yaml
    yields.yaml
    districts.yaml
    victory_conditions.yaml
  explanations/
    early_game_economy.yaml
    science_vs_culture_gap.yaml
    loyalty_and_expansion.yaml
  tips/
    early_expansion.yaml
    science_victory.yaml
    culture_victory.yaml
    domination_victory.yaml
    civilization_germany.yaml
  sources/
    sources.yaml
```

## 最小可行版本

第一版不需要做复杂数据库。可以先用 YAML/JSON 文件：

1. 先写 30-50 条高频攻略。
2. 每条都带 `tags`、`conditions`、`confidence`、`source`。
3. Python Consul 读取这些文件并做关键词 + 标签检索。
4. 后续再升级到向量检索或 SQLite。

优先收集的攻略主题：

- 新手通用：铺城、住房、宜居、商路、尤里卡、区域。
- 科技胜利：学院、工业区、太空项目、伟人。
- 文化胜利：剧院、旅游、国家公园、摇滚乐队、开放边境。
- 宗教胜利：信仰经济、使徒晋升、宗教压力。
- 战争：科技窗口、单位升级、攻城、厌战。
- 文明专项：德国、日本、俄罗斯、巴比伦、韩国、罗马等高频文明。

## 产品判断

当前游戏快照数据已经足够支撑知识库驱动回答的 MVP。后续不应继续盲目全量接入 Civ VI API。

正确方向是：

1. 当前快照负责“这一局现在是什么状态”。
2. 知识库负责“玩家经验认为这种状态意味着什么”。
3. AI 负责“结合两者给出可解释建议”。
4. 如果真实提问暴露出数据缺口，再补专项数据模块。
