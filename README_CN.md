# CodexUsageFloat

[English](README.md) · **简体中文**

一款 macOS 菜单栏工具，随时查看 Codex 剩余额度、重置时间和 Token 用量。

[下载最新版](https://github.com/pspgbhu/CodexUsageFloat/releases/latest) · [问题反馈](https://github.com/pspgbhu/CodexUsageFloat/issues)

<p align="center">
  <img src="docs/images/codex-usage-float-panel.png" alt="CodexUsageFloat 中文面板：Plus 示例额度、近 30 天 Token 用量图表与显示设置" width="340">
</p>

- **额度一目了然**：查看订阅类型、余额、剩余额度与重置时间。
- **近 30 天用量**：将鼠标移到图表上，查看每天的 Token 使用情况。
- **自选显示方式**：选择菜单栏指标，或将指标移到可拖动的桌面浮窗。
- **自动更新**：默认每 30 秒刷新，支持手动刷新、登录时启动和中英文界面。

预览使用 Plus 示例数据。实际显示的额度周期取决于订阅类型及 Codex 返回的数据。

## 安装

需要 **macOS 13 或更新版本**，并已在 `/Applications`（应用程序）中安装和登录 Codex 客户端 `ChatGPT.app` 或 `Codex.app`。发布安装包兼容 Apple Silicon 和 Intel Mac。

1. 从 [Releases](https://github.com/pspgbhu/CodexUsageFloat/releases/latest) 下载 `.dmg` 安装包。
2. 打开安装包，将 `CodexUsageFloat.app` 拖入「应用程序」。若下载 `.zip`，解压后将应用移入同一位置。
3. 打开 CodexUsageFloat，点击菜单栏图标查看用量。

应用不显示 Dock 图标。默认开启「登录时启动」，可在面板中关闭。

## 使用

| 操作 | 方法 |
| --- | --- |
| 打开用量面板 | 点击菜单栏图标 |
| 立即刷新 | 点击面板顶部的刷新按钮；底部显示上次成功更新时间和刷新间隔 |
| 选择显示指标 | 在面板的「状态栏指标」中选择额度、重置时间或余额；选择「仅显示图标」可隐藏文字 |
| 开启桌面浮窗 | 打开「浮窗展示」并拖动到合适位置；所选指标移到浮窗，菜单栏保留图标 |
| 切换语言或退出 | 右键点击菜单栏图标或浮窗 |
| 查看某天的 Token 用量 | 将鼠标移到图表中对应日期的列上 |

### 如何理解数据

- **额度百分比表示剩余比例。** 当前面板为 Plus 显示 5 小时和周额度，为 Pro 显示周额度；其他套餐根据 Codex 返回的已识别周期展示，缺失的数值显示为不可用。
- **余额与额度百分比分开显示。** 数值余额最多保留两位小数。
- **Token 图表展示历史使用量，不代表剩余 Token。** 图表覆盖含今天在内的近 30 天，合计仅累加已上报日期的数据；未上报的日期不按零计算。
- **过期提示表示最近一次刷新失败。** 面板保留之前成功获取的数值，直到刷新成功。数据的新鲜程度也取决于 Codex 的上报情况。

## 常见问题

| 遇到的情况 | 处理方式 |
| --- | --- |
| 提示需要登录或数据不可用 | 打开 Codex 客户端，确认已登录，再刷新面板 |
| 客户端更新后无法刷新 | 更新并重新打开 CodexUsageFloat；应用兼容 ChatGPT 当前的内嵌 Codex CLI 目录及旧版程序路径 |
| 提示数据可能过期 | 检查网络及 Codex 客户端是否正常，再刷新；当前数值来自上次成功获取的数据 |
| macOS 提示无法验证开发者 | 确认下载来自本项目 Releases；对于未公证的版本，尝试打开后，在「系统设置 → 隐私与安全性」中选择「仍要打开」 |
| 移动应用后无法登录自启 | 从新位置打开应用，将「登录时启动」关闭后重新开启 |

若问题可复现，请在 [Issues](https://github.com/pspgbhu/CodexUsageFloat/issues) 中提供 macOS、Codex 客户端和 CodexUsageFloat 的版本、复现步骤及可见错误。分享截图或日志前，请移除账号信息和凭据。

## 更新与卸载

**更新**：先退出 CodexUsageFloat，从 [Releases](https://github.com/pspgbhu/CodexUsageFloat/releases/latest) 下载新版并替换原应用，再重新打开。保持安装位置不变，避免登录启动项指向旧位置。

**卸载**：在面板中关闭「登录时启动」，退出应用，再从「应用程序」中删除。

## 数据与隐私

CodexUsageFloat 通过本机 Codex app server，使用客户端已有的登录状态获取账号与用量信息，无需在本工具中填写密码或 API Key。应用保存显示偏好，将获取的用量保留在内存中，不另存登录凭据或用量历史。

本工具专注于 Codex。Token 用量由 Codex 提供，不通过分析对话内容估算。

## 从源码构建

需要支持 Swift tools version 5.9 或更高版本的 macOS Swift 工具链；运行测试还需要 XCTest。

```bash
git clone https://github.com/pspgbhu/CodexUsageFloat.git
cd CodexUsageFloat
swift build -c release
swift test
scripts/package-app.sh
open dist/CodexUsageFloat.app
```

打包脚本生成 `dist/CodexUsageFloat.app`，并在 SwiftPM 构建失败时回退到直接使用 `swiftc` 编译。回退只负责打包，不会执行测试；若 `swift test` 提示缺少 XCTest，请使用包含 XCTest 的 Xcode 工具链。

| 目录 | 用途 |
| --- | --- |
| `Sources/AgentUsageCore` | 通用用量模型、provider 协议、Codex app-server 客户端与响应映射 |
| `Sources/CodexUsageFloat` | SwiftUI/AppKit 界面、偏好设置和登录启动项管理 |
| `Tests/AgentUsageCoreTests` | 核心模型、格式化、协议和程序路径探测测试 |
| `scripts/` | 应用打包、发布产物生成及 LaunchAgent 安装与卸载 |

修改代码前请阅读 [AGENTS.md](AGENTS.md)；签名、公证与发布流程见[发布说明](docs/releasing.md)。
