# LightoffReading

**语言：** [English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

<p align="center">
  <img src="Assets/AppIcon.png" alt="LightoffReading app icon" width="112">
</p>

LightoffReading 是一个轻量的 macOS 菜单栏应用，可以把屏幕整体变暗，并在鼠标附近保留一块柔和的阅读聚光区域。

它适合在夜间、强光环境、长网页、PDF、文档和密集文字阅读时使用。应用常驻在菜单栏中，提供浮动控制面板，也可以用全局快捷键快速开关阅读灯。

需要 macOS 13 或更高版本。公开发布版本是 universal macOS app，同时支持 Apple Silicon 和 Intel Mac。

## 安装

### 使用终端快速安装

```sh
curl -fsSL https://raw.githubusercontent.com/andrewLi1994/LightoffReading/main/scripts/install-latest.sh | bash
```

这个命令会下载最新版本，把 app 复制到 `/Applications`，然后自动打开。

### 实验性 Codex Alpha

Codex 集成是实验性的开发者通道，会安装到和稳定版相同的位置：

```text
/Applications/LightoffReading.app
```

安装 alpha 会替换稳定版；重新安装稳定版也会替换 alpha。

```sh
curl -fsSL https://raw.githubusercontent.com/andrewLi1994/LightoffReading/experiment/codex-status-light/scripts/install-codex-alpha.sh | bash
```

alpha 不会自动启用 Codex hooks。打开 LightoffReading 菜单栏项目，选择 `Enable Codex Integration...`，然后在 Codex 中运行 `/hooks`，检查并信任 LightoffReading hooks 一次。

Codex 状态灯使用蓝色表示正在工作，黄色表示需要用户注意，绿色表示完成高光。黄色包括权限审批 hook，也包括 `request_user_input` / `Awaiting response` 这类等待用户选择或回复的状态。权限审批以 Codex hooks 为主路径；`request_user_input` 由轻量的本地 session observer 检测，它只 tail 当前活跃的 Codex JSONL session 文件，如果日志格式变化会静默降级。

本地 receiver 也支持可选 agent id，例如 `/state/running?agent=a`。多 agent 场景下，任一 agent 需要用户注意时整体显示黄光；否则任一 agent 还在运行时整体显示蓝光；某个 agent 完成时可以播放绿色 done 高光，然后回到当前聚合状态。

菜单里也会显示本地 Codex receiver 是否正在监听 `127.0.0.1:38561`，并提供 `Send Test Status` 子菜单，可以不用打开终端就测试 `Running`、`Needs Attention`、`Done` 和 `Idle`。

### 不使用终端安装

1. 打开最新发布页面：
   https://github.com/andrewLi1994/LightoffReading/releases/latest

2. 下载 `LightoffReading.zip`。

3. 解压后，把 `LightoffReading.app` 移动到 `/Applications` 文件夹。

从 `/Applications` 打开 LightoffReading。打开后，它会出现在 macOS 菜单栏里。

如果 macOS 第一次打开时阻止运行，请打开系统设置，并在“隐私与安全性”里允许该应用。

## 功能

- 让屏幕变暗，同时保留一块柔和的可见阅读区域。
- 阅读区域会跟随鼠标位置。
- 支持横向条形、椭圆和其他聚光形状。
- 提供紧凑浮动 HUD，用于快速开关和切换形状。
- 提供展开 HUD，用于调整宽度、高度、边缘柔和度、变暗程度和位置偏移。
- 支持全局快捷键，默认是 `Control-Option-Command-/`。
- 使用 macOS 偏好设置在本地保存配置。

## 隐私

LightoffReading 不包含分析统计、遥测、账号系统或后台网络上报。

应用只会在你的 Mac 本地保存快捷键和视觉设置。安装脚本只会通过 GitHub 下载最新发布版本。

## 使用

启动后，LightoffReading 会出现在 macOS 菜单栏。

- 使用 `Control-Option-Command-/` 开关阅读灯。
- 使用浮动 HUD 开关阅读灯或切换形状。
- 从菜单栏项目里点击 `Show Floating HUD` 可以重新打开控制面板。
- 使用 `Set Shortcut...` 可以录制新的快捷键。

首次启动时，应用会在菜单栏图标下方显示一次简短提示，帮助用户找到控制入口。

## 支持

LightoffReading 是开源项目。如果它对你有帮助，可以通过 GitHub Sponsors 支持：

https://github.com/sponsors/andrewLi1994

## 构建

```sh
bash scripts/build-app.sh
```

脚本会生成：

```text
.build/release/LightoffReading.app
```

默认情况下，app bundle 会包含 universal binary。更快的本机架构构建方式：

```sh
UNIVERSAL_BUILD=0 bash scripts/build-app.sh
```

版本号规则：

- 设置了 `APP_VERSION` 环境变量时，优先使用它。
- 在 GitHub Actions 的 tag 构建中，`v1.2.3` 会变成 app 版本 `1.2.3`。
- 其他情况下，构建脚本会使用本地最新的 `v*` git tag。
- 如果无法解析版本号，构建会失败，而不是自动编造一个版本号。

## 本地运行

```sh
open .build/release/LightoffReading.app
```

## 从源码安装

适合贡献者，或者想从源码构建的用户：

```sh
git clone https://github.com/andrewLi1994/LightoffReading.git
cd LightoffReading
bash scripts/install.sh
```

脚本会构建 app，复制到 `/Applications/LightoffReading.app`，在存在本地隔离属性时移除它，并打开应用。

## 打包发布版本

创建发布资源：

```sh
bash scripts/package-release.sh
```

脚本会生成：

```text
dist/LightoffReading.zip
dist/LightoffReading.zip.sha256
```

推送 `v*` tag 后，GitHub Actions 会自动构建并发布 release asset。

```sh
git tag v0.1.0
git push origin v0.1.0
```

## 签名和公证

`scripts/build-app.sh` 会为本地使用创建 ad-hoc signed app。如果想在 Mac App Store 之外提供更顺滑的公开下载体验，建议打包 Developer ID 签名并经过 notarization 的版本。

示例：

```sh
BUNDLE_ID="com.yourname.LightoffReading" \
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notarytool-profile-name" \
bash scripts/package-release.sh
```

如果 app 没有经过 Developer ID 签名和 notarization，macOS Gatekeeper 可能会要求用户在第一次打开时手动批准。

## 许可证

LightoffReading 使用 MIT License 发布。
