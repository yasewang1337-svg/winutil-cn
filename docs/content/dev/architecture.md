---
title: 架构与设计
weight: 1
toc: true
---

## 概述

Winutil 是一款基于 PowerShell、带有 WPF（Windows Presentation Foundation）图形界面的 Windows 实用工具。本文档解释它的架构、代码结构，以及各组件如何协同工作。

## 高层架构

```
┌─────────────────────────────────────────────────────┐
│                    Winutil GUI                      │
│              (WPF XAML Interface)                   │
└──────────────────┬──────────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
┌────────▼──────┐   ┌───────▼────────┐
│  Public APIs  │   │  Private APIs  │
│  (User-facing)│   │   (Internal)   │
└───────┬───────┘   └───────┬────────┘
        │                   │
        └────────┬──────────┘
                 │
    ┌────────────▼────────────┐
    │   Configuration Files   │
    │  (JSON definitions)     │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │   External Tools        │
    │  (WinGet, Chocolatey)   │
    └─────────────────────────┘
```

## 项目结构

### 目录布局

```
winutil/
├── Compile.ps1                 # 合并所有文件的构建脚本
├── winutil.ps1                 # 编译产物（自动生成）
├── scripts/
│   ├── main.ps1               # 入口点与 GUI 初始化
│   └── start.ps1              # 启动逻辑
├── functions/
│   ├── private/               # 内部辅助函数
│   │   ├── Get-WinUtilVariables.ps1
│   │   ├── Install-WinUtilWinget.ps1
│   │   └── ...
│   ├── public/                # 面向用户的函数
│   │   ├── Initialize-WPFUI.ps1
│   │   └── ...
├── config/                    # JSON 配置文件
│   ├── applications.json      # 应用定义
│   ├── tweaks.json           # 优化项定义
│   ├── feature.json          # Windows 功能定义
│   └── preset.json           # 预设配置
├── xaml/
│   └── inputXML.xaml         # GUI 布局定义
└── docs/                     # 文档
```

### 关键组件

#### 1. Compile.ps1
**用途**：将所有分散的脚本文件合并成单个 `winutil.ps1` 用于分发。

**流程**：
1. 读取 `/functions/` 中的所有函数文件
2. 纳入配置 JSON 文件
3. 嵌入 XAML GUI 定义
4. 合并成单个脚本
5. 输出 `winutil.ps1`

**为什么这么做**：让分发更简单（单文件），并缩短加载时间。

#### 2. scripts/main.ps1
**用途**：初始化 GUI 和事件系统的入口点。

**职责**：
- 加载 XAML 并创建 WPF 窗口
- 初始化界面元素
- 设置事件处理器
- 加载配置
- 复选框（用于选项）
- 列表框（用于选择）

## Win11 创建器架构

**Win11 创建器（Win11 Creator）** 是 Winutil 内部一个专门的子系统，用于创建自定义的 Windows 11 ISO。它独立于主体的软件包安装与优化项系统运行。

### Win11 创建器组件

**核心函数**（`functions/private/`）：
- `Invoke-WinUtilISO.ps1`：主编排器，包含所有 Win11 创建器函数
  - `Invoke-WinUtilISOBrowse`：ISO 文件选择对话框
  - `Invoke-WinUtilISOMountAndVerify`：校验并挂载 ISO，确认它是官方 Windows 11
  - `Invoke-WinUtilISOModify`：在后台运行空间（runspace）中启动修改
  - `Invoke-WinUtilISOExport`：处理 ISO 和 U 盘导出
  - `Invoke-WinUtilISOCheckExistingWork`：恢复未完成的工作会话
  - `Invoke-WinUtilISOCleanAndReset`：清理临时目录并重置界面

- `Invoke-WinUtilISOScript.ps1`：对已挂载的 install.wim 应用修改
  - 移除预置的 AppX 包（40 多个捆绑应用）
  - （可选）从当前系统注入驱动
  - 移除 OneDrive 安装文件
  - 应用离线注册表优化（硬件绕过、隐私、遥测、OOBE）
  - 删除遥测计划任务定义
  - 预置来自 autounattend.xml 的安装脚本
  - 移除未使用的 Windows 版本
  - 通过 DISM 清理组件存储

### Win11 创建器数据流

```
User selects official Windows 11 ISO
    ↓
Invoke-WinUtilISOBrowse → OpenFileDialog, validates file size
    ↓
Invoke-WinUtilISOMountAndVerify
    ├─ Mount ISO via Mount-DiskImage
    ├─ Verify install.wim or install.esd exists
    ├─ Check for "Windows 11" in image metadata
    ├─ Extract available editions (Home, Pro, Enterprise, etc.)
    └─ Store ISO path, drive letter, WIM path, image info in $sync
    ↓
User optionally enables the Driver Injection checkbox
    ↓
Invoke-WinUtilISOModify (runs in background runspace)
    ├─ Create work directory: ~WinUtil_Win11ISO_[timestamp]
    ├─ Copy ISO contents to disk (~5-6 GB)
    ├─ Mount install.wim at selected edition/index
    ├─ Invoke-WinUtilISOScript:
    │   ├─ Remove 40+ bloat AppX packages
    │   ├─ Export and inject drivers (if enabled)
    │   ├─ Remove OneDrive setup
    │   ├─ Load offline registry hives
    │   ├─ Apply 50+ registry tweaks (hardware bypass, privacy, telemetry, OOBE, etc.)
    │   ├─ Delete telemetry scheduled task files
    │   ├─ Pre-stage setup scripts from autounattend.xml to C:\Windows\Setup\Scripts\
    │   └─ Unload registry hives
    ├─ DISM /Cleanup-Image /StartComponentCleanup /ResetBase (saves 300-800 MB)
    ├─ Dismount and save the modified install.wim (~10+ minutes, slowest step)
    ├─ Export selected edition only (removes all other editions, saves 1-2 GB each)
    ├─ Dismount source ISO
    └─ Report completion, enable export options
    ↓
Invoke-WinUtilISOExport (user chooses output)
    ├─ Option 1: Save as ISO
    │   ├─ Build bootable ISO via oscdimg.exe (BIOS/UEFI dual-boot)
    │   └─ Output: Win11_Modified_[date].iso (2.5-3.5 GB)
    │
    └─ Option 2: Write to USB
        ├─ Format USB as GPT
        ├─ Create 512 MB EFI partition
        ├─ Copy modified ISO contents
        └─ Output: Bootable USB (minimum 8 GB)
    ↓
Invoke-WinUtilISOCleanAndReset (optional)
    └─ Delete temp working directory (~10-15 GB)
    └─ Reset UI to initial state
```

### Win11 创建器的校验与安全

**ISO 校验**：
- 只接受官方微软 Windows 11 ISO
- 校验 install.wim 或 install.esd 是否存在
- 检查镜像元数据中是否含有 "Windows 11" 字样
- 拒绝自定义、修改过或非 Windows 11 的 ISO

**工作会话恢复**：
- 自动检测上次会话遗留的未完成工作
- 允许直接恢复到第 4 步（导出），而无需重跑第 1–3 步
- 防止重复修改

**修改安全性**：
- 所有注册表改动都记录在脚本中（可逆）
- 原始 ISO 从不被修改；只操作工作副本
- 记录到 `WinUtil_Win11ISO.log` 以便调试
- DISM 负责镜像卸载，出错时自动清理

### Win11 创建器的注册表优化

`Invoke-WinUtilISOScript` 函数会应用 **50 多项离线注册表优化**：

**硬件绕过**：
- 绕过 TPM 2.0 检查
- 绕过安全启动要求
- 绕过 CPU 兼容性检查
- 绕过内存要求
- 绕过存储检查

**隐私与遥测**：
- 禁用广告 ID
- 禁用量身定制的体验
- 禁用输入个性化
- 禁用语音在线隐私
- 禁用云内容建议
- 禁用应用建议订阅
- 移除 CEIP、Appraiser、WaaSMedic 等

**OOBE 与安装**：
- 启用本地账户设置
- 跳过微软账户要求
- 默认深色模式
- 空的任务栏和开始菜单

**安装后的安装项**：
- 阻止 DevHome 自动安装
- 阻止新版 Outlook 邮件应用安装
- 阻止 Teams 自动安装

**系统功能**：
- 禁用 BitLocker 和设备加密
- 从任务栏禁用聊天图标
- 禁用 OneDrive 文件夹备份
- 禁用 Copilot
- 在 OOBE 期间禁用 Windows 更新（首次登录时重新启用）

### 驱动注入功能

**可选增强**：启用后，会从正在运行的系统导出所有驱动，并注入到以下两处：
- `install.wim`（主操作系统镜像）
- `boot.wim` 索引 2（Windows 安装 PE 环境）

**使用场景**：在缺少驱动的系统上启用离线安装。

### 磁盘空间要求

- **临时工作目录**：约 10-15 GB
- **原始 ISO**：4-6 GB
- **修改后的 ISO**：2.5-3.5 GB
- **总共需要**：约 25 GB 以保证操作安全

## 数据流

### 应用安装流程

```
User clicks "Install"
    ↓
Get-WinUtilCheckBoxes → Retrieves selected apps
    ↓
For each selected app:
    ↓
Check if WinGet/Choco is installed
    ↓
Install-WinUtilWinget/Choco (if needed)
    ↓
Install-WinUtilProgramWinget/Choco → Install app
    ↓
Update UI with progress
    ↓
Display completion message
```

### 优化项应用流程

```
User selects tweaks and clicks "Run Tweaks"
    ↓
Get-WinUtilCheckBoxes → Get selected tweaks
    ↓
For each selected tweak:
    ↓
Load tweak definition from tweaks.json
    ↓
Invoke-WPFTweak → Apply registry/service changes
    ↓
Log changes
    ↓
Store original values (for undo)
    ↓
Update UI
    ↓
Display completion
```

### 撤销优化项流程

```
User selects tweaks and clicks "Undo"
    ↓
Get-WinUtilCheckBoxes → Get selected tweaks
    ↓
For each tweak:
    ↓
Retrieve "OriginalState" from tweak definition
    ↓
Invoke-WPFUndoTweak → Restore original values
    ↓
Remove from the applied tweaks log
    ↓
Update UI
```

## 配置文件格式

### applications.json 结构

```json {filename="config/applications.json"}
{
  "WPFInstall<AppName>": {
    "category": "Browsers",
    "choco": "googlechrome",
    "content": "Google Chrome",
    "description": "Google Chrome browser",
    "link": "https://chrome.google.com",
    "winget": "Google.Chrome"
  }
}
```

**字段**：
- `category`：位于「安装」标签页的哪个区域
- `content`：GUI 中的显示名称
- `description`：工具提示/描述文本
- `winget`：WinGet 包 ID
- `choco`：Chocolatey 包名
- `link`：官方网站

### tweaks.json 结构

```json {filename="config/tweaks.json"}
{
  "WPFTweaksTelemetry": {
    "Content": "Disable Telemetry",
    "Description": "Disables Microsoft Telemetry",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
        "Name": "AllowTelemetry",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  }
}
```

**字段**：
- `Content`：显示名称
- `Description`：它的作用
- `category`：Essential（基础）/Advanced（高级）/Customize（个性化）
- `registry`：要进行的注册表改动
- `service`：要更改的服务
- `OriginalValue/State`：用于撤销功能

## PowerShell 运行空间（Runspace）

Winutil 使用 PowerShell 运行空间，让 GUI 保持响应：

```powershell
# Create runspace
$sync.runspace = [runspacefactory]::CreateRunspace()
$sync.runspace.Open()
$sync.runspace.SessionStateProxy.SetVariable("sync", $sync)

# Run code in background
$powershell = [powershell]::Create().AddScript($scriptblock)
$powershell.Runspace = $sync.runspace
$handle = $powershell.BeginInvoke()
```

**为什么**：防止在长时间运行的操作期间界面卡死。

## WPF 事件处理

事件通过 XAML 元素名称来接线：

```powershell
# Get all named elements
$sync.keys | ForEach-Object {
    if($sync.$_.GetType().Name -eq "Button") {
        $sync.$_.Add_Click({
            $button = $sync.$($args[0].Name)
            & "Invoke-$($args[0].Name)"
        })
    }
}
```

**约定**：名为 `WPFInstallButton` 的按钮会调用函数 `Invoke-WPFInstallButton`。

## 包管理器集成

### WinGet 集成

```powershell
# Check if installed
if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Install-WinUtilWinget
}

# Install package
winget install --id $app.winget --silent --accept-source-agreements
```

### Chocolatey 集成

```powershell
# Check if installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Install-WinUtilChoco
}

# Install package
choco install $app.choco -y
```

## 错误处理

Winutil 使用 PowerShell 的错误处理：

```powershell
try {
    # Attempt operation
    Invoke-SomeOperation
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    # Log error
    Add-Content -Path $logfile -Value "ERROR: $_"
}
```

**日志记录**：错误和操作都会被记录下来以便调试。

## 配置加载

启动时，Winutil 加载所有配置：

```powershell
# Load JSON configs
$sync.configs = @{}
$sync.configs.applications = Get-Content "config/applications.json" | ConvertFrom-Json
$sync.configs.tweaks = Get-Content "config/tweaks.json" | ConvertFrom-Json
$sync.configs.features = Get-Content "config/feature.json" | ConvertFrom-Json
```

**Sync 哈希表**：`$sync` 哈希表在各运行空间之间共享状态。

## 界面更新模式

界面更新必须发生在 UI 线程上：

```powershell
$sync.form.Dispatcher.Invoke([action]{
    $sync.WPFStatusLabel.Content = "Installing..."
}, "Normal")
```

**为什么**：WPF 要求界面更新在主线程上进行。

## 添加新功能

### 添加一个新应用

1. 编辑 `config/applications.json`：
```json {filename="config/applications.json"}
{
  "WPFInstallNewApp": {
    "category": "Utilities",
    "content": "New App",
    "description": "Description of new app",
    "winget": "Publisher.AppName",
    "choco": "appname"
  }
}
```

2. 重新编译：`.\Compile.ps1`
3. 该应用会自动出现在「安装」标签页

### 添加一个新优化项

1. 编辑 `config/tweaks.json`：
```json {filename="config/tweaks.json"}
{
  "WPFTweaksNewTweak": {
    "Content": "New Tweak",
    "Description": "What it does",
    "category": "Essential Tweaks",
    "registry": [
      {
        "Path": "HKLM:\\Path\\To\\Key",
        "Name": "ValueName",
        "Type": "DWord",
        "Value": "1",
        "OriginalValue": "0"
      }
    ]
  }
}
```

2. 重新编译：`.\Compile.ps1`
3. 该优化项会出现在「优化项」标签页

### 添加一个新函数

1. 在 `functions/public/` 或 `functions/private/` 中创建文件：
```powershell
# functions/public/Invoke-WPFNewFeature.ps1
function Invoke-WPFNewFeature {
    <#
    .SYNOPSIS
    Does something new
    #>
    # Implementation
}
```

2. 文件命名必须含有 "WPF" 或 "Winutil" 才会被加载
3. 重新编译：`.\Compile.ps1`

## 测试

### 手动测试

```powershell
# Compile and run with -run flag
.\Compile.ps1 -run
```

### 自动化测试

测试位于 `/pester/`：
- `configs.Tests.ps1`：校验 JSON 配置
- `functions.Tests.ps1`：测试 PowerShell 函数

运行测试：
```powershell
Invoke-Pester
```

## 构建流程

### 开发构建

```powershell
.\Compile.ps1
```

在根目录输出 `winutil.ps1`。

### 生产发布

1. 在 Git 中打上发布标签
2. GitHub Actions 构建并上传 `winutil.ps1`
3. 发布出现在 GitHub Releases
4. 用户通过 `irm christitus.com/win` 下载

## 依赖

**必需**：
- PowerShell 5.1+
- .NET Framework 4.5+
- Windows 11

**可选（自动安装）**：
- WinGet（Windows 包管理器）
- Chocolatey

## 性能考量

**优化策略**：
- 延迟加载配置（仅在需要时）
- 对长时间操作使用运行空间
- 缓存昂贵的查询
- 尽量减少注册表读写
- 尽可能批量操作

## 安全考量

**安全措施**：
- 所有操作都有日志
- 为撤销功能备份注册表
- 不存储任何凭据
- 开源（可审计）
- 数字签名（未来）

## 贡献准则

**代码规范**：
- 使用规范的 PowerShell cmdlet 命名（动词-名词，Verb-Noun）
- 包含基于注释的帮助（comment-based help）
- 遵循现有代码风格
- 在提 PR 前充分测试
- 记录重要改动

**文件命名**：
- 公共函数：`Invoke-WPF*.ps1` 或 `Invoke-Winutil*.ps1`
- 私有函数：`Get-WinUtil*.ps1` 或 `动词-WinUtil*.ps1`
- 必须含有 "WPF" 或 "Winutil" 才会被加载

## 未来架构规划

**路线图设想**：
- 面向社区扩展的插件系统
- 配置导入/导出
- 配置的云同步
- 增强的日志仪表盘
- 模块化编译（选择需要的功能）

## 相关文档

- [贡献指南](../../contributing/) —— 如何贡献代码
- [用户指南](../../userguide/) —— 面向最终用户的文档
- [Win11 创建器指南](../../userguide/win11creator/) —— 构建自定义 Windows 11 ISO
- [FAQ](../../faq/) —— 常见问题

## 更多资源

- **GitHub 仓库**：[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)
- **PowerShell 文档**：[Microsoft Docs](https://docs.microsoft.com/powershell/)
- **WPF 指南**：[WPF Documentation](https://docs.microsoft.com/dotnet/desktop/wpf/)

---

**最后更新**：2026 年 1 月
**维护者**：Chris Titus Tech 及贡献者
