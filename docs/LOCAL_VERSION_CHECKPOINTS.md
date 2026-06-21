# Project Obelisk 本地版本回退点

本文档记录本地开发阶段的可回退版本点。GitHub 网络恢复前，先以本地 Git commit/tag 作为版本保存；之后统一推送分支和 tag。

## 当前版本

### v0.5.0-dev-expanded-consul

- 状态：本地 dev tag 版本点，已通过自动测试，待 Windows Civ VI 实机验收。
- 目标提交：创建 tag 时的本地最新提交。
- 功能范围：
  - 本地知识库扩展到 8 个流派：小马流、学院流、大商路流、征服流、宗教流、文化流、工业流、扩张流。
  - 游戏内 Lua 兜底评分器同步支持 8 个流派。
  - Python Consul 新增玩家回答编排层。
  - Python Consul 新增 `ai-context` 输出，用于后续大模型回答。
  - Python Consul 新增本地 HTTP 服务 `/health` 和 `/answer`。
- 回退方式：

```powershell
git checkout v0.5.0-dev-expanded-consul
```

如需把当前分支强制回退到该版本：

```powershell
git reset --hard v0.5.0-dev-expanded-consul
```

### v0.4.0-local-strategy-loop

- 状态：本地 tag 版本点。
- 目标提交：创建 tag 时的本地最新提交。
- 验收状态：Windows Civ VI 本机验收通过。
- 功能范围：
  - 游戏内顶部透明提问条。
  - 下拉回答框。
  - 连续输入问题修复。
  - 游戏内本地知识评分器。
  - 小马流、学院流、大商路流评分、排序、阻断原因、下一步检查项。
  - 不依赖 Python 服务或大模型即可运行。
- 回退方式：

```powershell
git checkout v0.4.0-local-strategy-loop
```

如需把当前分支强制回退到该版本：

```powershell
git reset --hard v0.4.0-local-strategy-loop
```

注意：`reset --hard` 会丢弃当前未提交改动，执行前必须确认没有需要保留的工作区文件。

## 历史关键提交

- `82dcbe1 Complete local strategy answer loop`：第一版游戏内产品闭环。
- `84ea11c Map Obelisk snapshots to knowledge state`：Lua 快照到知识库标准 state 的 Python 映射层。
- `7a9c413 Implement in-game question bar UI`：顶部输入条和下拉回答框。
- `c65cb29 Add local knowledge matcher MVP`：Python 本地知识库 matcher MVP。

## 后续版本规则

- 小修复：`v0.4.x-local-*`
- 新增本地能力但不接 AI：`v0.5.0-local-*`
- 接入 AI 回答链路后：`v0.6.0-ai-*`
- 每次用户实机验收通过后再创建 tag。
- GitHub 恢复后统一推送：

```powershell
git push origin codex/civ6-ingame-ui
git push origin --tags
```
