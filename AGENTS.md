# Agent 指令

## 项目概览

本项目是 `AgentUsageFloat`，一个用于显示代码智能体用量状态的 macOS 菜单栏工具。

当前实现通过 `CodexUsageProvider` 支持 Codex，但应用设计上预留了后续支持更多代码智能体的能力。

## 架构规则

- 通用用量模型和协议放在 `Sources/AgentUsageCore`。
- UI 代码放在 `Sources/AgentUsageFloat`。
- UI 必须依赖通用的 `UsageProvider` 协议，不能直接依赖 Codex 专用的 payload。
- Codex 专用的 API 形状、JSON-RPC 方法和响应映射应放在 `CodexUsageProvider`、`CodexPayloads` 和 `CodexUsageMapper` 中。
- 未来新增 provider 时，应添加自己的 provider 实现和 mapper，不要围绕智能体名称扩展 UI 条件分支。

## 命名规则

- 项目、包、应用 bundle、可执行文件和 LaunchAgent 都使用 `AgentUsageFloat`。
- 核心模块名为 `AgentUsageCore`。
- `Codex*` 命名只适用于 Codex provider 的实现细节和 Codex 专用测试。
- 不要重新引入 `CodexUsageFloat` 或 `CodexUsageCore` 作为项目级名称。
- 现存的 `com.local.codex-usage-float`、`CodexUsageFloat.app` 和旧版 `codexCLIPath` 引用只用于迁移清理。除非有意退役迁移路径，否则不要移除它们。

## 构建与验证

首选命令：

```bash
swift build -c release
swift test
scripts/package-app.sh
```

在这台机器上，`swift build` 和 `swift test` 可能会在编译前失败，因为 Command Line Tools 无法响应：

```text
xcrun --sdk macosx --show-sdk-platform-path
```

`scripts/package-app.sh` 会有意回退到直接使用 `swiftc` 编译。除非本地工具链问题已修复且不再需要该回退逻辑，否则请保留它。

当 SwiftPM 受阻时，可使用以下验证命令：

```bash
swiftc -typecheck Sources/AgentUsageCore/*.swift
swiftc -emit-module -enable-testing -module-name AgentUsageCore Sources/AgentUsageCore/*.swift -emit-module-path /tmp/AgentUsageCore.swiftmodule -parse-as-library
swiftc -typecheck -parse-as-library -I /tmp Sources/AgentUsageFloat/*.swift
scripts/package-app.sh
DRY_RUN=1 PLIST_PATH=/tmp/com.local.agent-usage-float.plist scripts/install-launch-agent.sh
```

## 隐私与数据处理

- 不要直接读取 `~/.codex/auth.json`。
- 不要持久化 token、cookie、邮箱地址或原始 provider 响应。
- 集成检查只能打印已脱敏的布尔值或状态，不能打印余额、邮箱、token 或完整 JSON payload。

## LaunchAgent 规则

- 当前 LaunchAgent label：`com.local.agent-usage-float`。
- 为支持从原项目名升级，安装和卸载路径中应保留旧的 `com.local.codex-usage-float` 清理逻辑。
- 如果应用路径发生变化，应重新生成或重新安装 LaunchAgent，使其指向当前应用 bundle。

## UI 规则

- 状态栏标题显示主要剩余百分比，格式如 `P 58%`。
- 浮动面板只有在 provider 专用值被标准化为 `UsageSnapshot` 后，才可以显示这些值。
- 不要捏造剩余 token 数；Codex 当前提供的是历史 token 使用量，而不是 token 剩余额度。
