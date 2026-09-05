# 发布说明

本文档供维护者使用，记录自动发布所需的仓库配置与验证步骤。

## GitHub Actions secrets

以下 Actions secrets 都是可选配置：

- `MACOS_CERTIFICATE`：Developer ID Application `.p12` 文件的 Base64 内容。
- `MACOS_CERTIFICATE_PASSWORD`：导出 `.p12` 时设置的密码。
- `APPLE_ID`：用于 Apple 公证的 Apple ID。
- `APPLE_TEAM_ID`：Apple Developer Team ID。
- `APPLE_APP_SPECIFIC_PASSWORD`：Apple ID 的 app-specific password。

完全不配置这些 secrets 时，工作流仍会创建使用 ad-hoc 签名、未经 Apple 公证的 Release。用户首次打开时需要在“系统设置 → 隐私与安全性”中手动允许。证书和公证凭据都配置完整时，工作流会自动签名并公证；证书必须包含有效的 `Developer ID Application` 签名身份。

## 创建 Release

将发布提交合并到 `master` 后创建并推送符合 `vX.Y.Z` 格式的标签：

```bash
git tag v0.2.0
git push origin v0.2.0
```

工作流将运行测试、构建包含 `arm64` 和 `x86_64` 的通用应用，然后创建 GitHub Release。配置 Apple 凭据时还会完成应用及 DMG 的签名和公证。最终附件包括：

- `CodexUsageFloat-<version>-universal.dmg`
- `CodexUsageFloat-<version>-universal.zip`
- `checksums.txt`

GitHub Actions 页面也支持对已经存在的版本标签手动运行 Release 工作流。重复运行时会覆盖该 Release 的同名附件。

## 本地验证安装包

不提供 Apple 凭据时，可以在本机生成仅用于验证的 ad-hoc 签名产物：

```bash
APP_VERSION=0.2.0 BUILD_NUMBER=2 scripts/create-release-artifacts.sh
```

本地产物写入 `dist/release/`。未经过 Developer ID 签名和 Apple 公证的产物需要用户在 macOS 的“隐私与安全性”设置中手动放行。
