<div align="center">
  <img src="docs/assets/images/holha-logo.svg" alt="Holha1337 — WinUtil 中文汉化 · 首席维护者" width="760">
</div>

<h1 align="center">Chris Titus Tech's Windows Utility（中文汉化版）</h1>

<p align="center"><b>汉化作者 · 首席维护者：<a href="https://github.com/yasewang1337-svg">Holha1337</a></b></p>

[![Version](https://img.shields.io/github/v/release/ChrisTitusTech/winutil?color=%230567ff&label=Latest%20Release&style=for-the-badge)](https://github.com/ChrisTitusTech/winutil/releases/latest)
![Downloads](https://img.shields.io/github/downloads/ChrisTitusTech/winutil/winutil.ps1?label=Total%20Downloads&style=for-the-badge)
[![Discord](https://dcbadge.limes.pink/api/server/https://discord.gg/RUbZUZyByQ?theme=default-inverted&style=for-the-badge)](https://discord.gg/RUbZUZyByQ)

一套精心整理的 Windows 系统任务合集：一键**安装**软件、用**优化项**给系统瘦身、用**配置**排查故障、并管理 **Windows 更新**。每次重装 Windows 后跑一遍，快速回到顺手的状态。

![标题界面](/docs/assets/images/Title-Screen.png)

> 💙 **给中国开发者的一句话**
>
> 能为中国开发者提供更好的帮助，是我最开心的事情。这个汉化版会一直维护下去，未来会更好。

---

## 快速开始

> **WinUtil 必须以管理员身份运行**，因为它会对系统进行全局修改。

以管理员身份打开 PowerShell 或 Terminal（终端），然后运行：

**稳定版（推荐）**
```ps1
irm https://christitus.com/win | iex
```

**开发版**
```ps1
irm https://christitus.com/windev | iex
```

### 如何打开管理员终端

- **开始菜单：** 右键点击「开始」→ 选择 *Windows PowerShell（管理员）* 或 *终端（管理员）*
- **搜索：** 按下 `Windows 键`，输入 `PowerShell` 或 `Terminal`，然后按 `Ctrl + Shift + Enter`

---

## 自动化 / 预设

无需手动勾选，直接套用一份预定义好的配置：

```powershell
& ([ScriptBlock]::Create((irm https://christitus.com/win))) -Preset Standard
```

| 预设 | 说明 |
|--------|-------------|
| `Standard`（标准） | 适合大多数用户的均衡默认配置 |
| `Minimal`（精简） | 改动最小、人人适用 |
| `Advanced`（高级） | 面向高级用户的深度优化 |

想看每个预设具体做了什么，请见：
https://github.com/ChrisTitusTech/winutil/blob/main/config/preset.json

---

## 构建与开发

请参见 https://github.com/ChrisTitusTech/winutil/blob/main/.github/CONTRIBUTING.md

---

## 相关资源

- [官方文档](https://winutil.christitus.com/)
- [YouTube 教程视频](https://www.youtube.com/watch?v=6UQZ5oQg8XA)
- [ChrisTitus.com 文章](https://christitus.com/windows-tool/)
- [已知问题](https://winutil.christitus.com/knownissues/)
- [反馈问题](https://github.com/ChrisTitusTech/winutil/issues)

---

## 支持项目

- 点一颗 ⭐ 就是对作者最好的支持！
- 打包好的 EXE 版本售价 $10 @ https://www.cttstore.com/windows-toolbox

## 赞助者

以下是通过每月捐助支持本项目持续运转的赞助者。

<!-- sponsors --><a href="https://github.com/dwelfusius"><img src="https:&#x2F;&#x2F;github.com&#x2F;dwelfusius.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/mews-se"><img src="https:&#x2F;&#x2F;github.com&#x2F;mews-se.png" width="60px" alt="User avatar: Martin Stockzell" /></a><a href="https://github.com/jdiegmueller"><img src="https:&#x2F;&#x2F;github.com&#x2F;jdiegmueller.png" width="60px" alt="User avatar: Jason A. Diegmueller" /></a><a href="https://github.com/robertsandrock"><img src="https:&#x2F;&#x2F;github.com&#x2F;robertsandrock.png" width="60px" alt="User avatar: RMS" /></a><a href="https://github.com/paulsheets"><img src="https:&#x2F;&#x2F;github.com&#x2F;paulsheets.png" width="60px" alt="User avatar: Paul" /></a><a href="https://github.com/djones369"><img src="https:&#x2F;&#x2F;github.com&#x2F;djones369.png" width="60px" alt="User avatar: Dave J  (WhamGeek)" /></a><a href="https://github.com/anthonymendez"><img src="https:&#x2F;&#x2F;github.com&#x2F;anthonymendez.png" width="60px" alt="User avatar: Anthony Mendez" /></a><a href="https://github.com/FatBastard0"><img src="https:&#x2F;&#x2F;github.com&#x2F;FatBastard0.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/DursleyGuy"><img src="https:&#x2F;&#x2F;github.com&#x2F;DursleyGuy.png" width="60px" alt="User avatar: DursleyGuy" /></a><a href="https://github.com/DwayneTheRockLobster1"><img src="https:&#x2F;&#x2F;github.com&#x2F;DwayneTheRockLobster1.png" width="60px" alt="User avatar: " /></a><a href="https://github.com/KieraKujisawa"><img src="https:&#x2F;&#x2F;github.com&#x2F;KieraKujisawa.png" width="60px" alt="User avatar: Kiera Meredith" /></a><a href="https://github.com/andrewpayne68"><img src="https:&#x2F;&#x2F;github.com&#x2F;andrewpayne68.png" width="60px" alt="User avatar: Andrew P" /></a><!-- sponsors -->

---

## 汉化作者

<div align="center">
  <a href="https://github.com/yasewang1337-svg">
    <img src="https://github.com/yasewang1337-svg.png" width="120" alt="Holha1337" style="border-radius:50%">
  </a>
  <h3>Holha1337</h3>
  <p><b>WinUtil 中文汉化 · 首席维护者</b></p>
  <p>能为中国开发者提供更好的帮助，是我最开心的事情。未来会更好。💙</p>
</div>

## 上游贡献者

[![Contributors](https://contrib.rocks/image?repo=ChrisTitusTech/winutil)](https://github.com/ChrisTitusTech/winutil/graphs/contributors)

感谢每一位为上游项目付出时间与精力的贡献者。继续加油 🍻
