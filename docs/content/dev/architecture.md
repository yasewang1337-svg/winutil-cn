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

## Windows 镜像子系统

Windows 镜像页用于制作 Windows 10 / 11 x64 客户端安装介质，独立于软件包与系统设置任务运行。**WinUtil 的宿主支持范围仍为 Windows 11**；制作目标支持 Windows 10 不等于工具可以在 Windows 10 上运行。本段按 2026-10-09 的实现核对。

### 组件与职责

核心函数位于 `functions/private/`：

| 文件 | 职责 |
| --- | --- |
| `Initialize-WinUtilISOControls.ps1` | 初始化微软下载页的 Windows 10 / 11 选择与按钮事件。现有 `WPFWin11ISO*` 控件名保留，用于兼容事件分发。 |
| `Invoke-WinUtilISO.ps1` | 选择与挂载源 ISO、读取版本、启动制作运行空间、导出 ISO、清理本次工作目录。 |
| `Get-WinUtilISOImageProfile.ps1` | 从详细 DISM 元数据判断系统、架构、版本与索引；检查可选驱动注入的宿主代际；统一检查原生程序退出码。 |
| `New-WinUtilISOWorkspace.ps1` | 创建受保护的独立工作目录，读写制作状态清单，校验后清理本次目录。 |
| `Initialize-WinUtilISOContents.ps1` | 复制安装文件，把所选 WIM / ESD 版本导出为可修改、只有索引 1 的 `install.wim`。 |
| `Install-WinUtilISOAnswerFile.ps1` | 校验应答 XML 的架构与脚本路径，写入 ISO 应答文件及受限路径内的安装脚本。 |
| `Invoke-WinUtilISOScript.ps1` | 对已挂载的镜像应用对应 Windows 版本的配置；可选注入同代际本机驱动。 |
| `Invoke-WinUtilISOUSB.ps1` | 列出 USB 数据盘、确认擦除、创建 GPT / FAT32 安装介质并复制文件。 |
| `Assert-WinUtilISOUSBTarget.ps1` | 写入前复核磁盘身份、系统盘标记、可写状态、容量和 FAT32 单文件限制。 |

`Compile.ps1` 把 `tools/autounattend.xml` 与 `tools/autounattend-win10.xml` 分别嵌入生成脚本；汉化构建也将两个模板纳入独立构建目录。制作运行空间会显式载入所需辅助函数，不依赖调用者会话自动继承函数定义。

### 输入与版本分流

工具读取每个安装版本的详细元数据，接受 x64 客户端镜像：Windows 10 为 19041–19045 版本族（2004–22H2），Windows 11 构建号为 22000 及以后。x86、ARM64、Windows Server、名称与版本不匹配、混合 Windows 10 / 11 的安装镜像会被拒绝。还会检查安装 WIM / ESD、`boot.wim` 与启动文件是否存在。

这些检查用于避免选错制作方案，**不证明 ISO 来自微软或未被修改**。用户仍需从官方渠道下载并核对哈希；单凭名称、元数据或文件布局无法鉴定来源。

- **Windows 10**：写入独立、精简的 amd64 应答配置，保留预装应用、离线注册表与计划任务，不执行 Windows 11 的硬件检查、任务栏、AppX 精简或组件存储清理方案。
- **Windows 11**：使用现有应答模板，按源码名单移除部分预装应用，写入安装脚本，应用离线注册表与任务调整，并清理组件存储。此方案包含硬件检查、本地账户、隐私与设备加密等设置；具体效果取决于源镜像版本。
- **驱动注入**：默认关闭。开启后导出当前主机驱动，注入 `install.wim` 和 `boot.wim` 索引 2；要求主机与目标同属 Windows 10 或 Windows 11 且均为 x64。因此在当前受支持的 Windows 11 主机上制作 Windows 10 镜像时，应保持关闭。

Windows 11 离线注册表以每次独立的 `HKLM\WinUtilISO_<GUID>_<Hive>` 名称挂载，在 `finally` 中逐一卸载，避免固定名称与其他任务冲突。工具不承诺这些修改可以完整撤销；需要重新选择源 ISO 制作其他方案。

### 制作与导出流程

```text
选择源 ISO → 挂载并读取全部版本元数据 → 选择版本
    ↓
创建 %ProgramData%\WinUtil-Tool-<GUID>
写入 winutil-iso.json，状态 Preparing
    ↓
复制安装文件（跳过原 install.wim / install.esd / install*.swm）
导出所选版本 → sources\install.wim，索引 1
    ↓
挂载索引 1 → Windows 10 或 Windows 11 配置 → 保存并卸载
    ├─ 失败：标记 Failed，保留工作目录和日志，可清理后重新开始
    └─ 成功：标记 Completed，开放保存 ISO / 写入 U 盘
            ↓
       保存 ISO 或写入 U 盘 → 用户确认后清理本次目录
```

工作目录复用 `New-WinUtilToolWorkspace` 的管理员 / SYSTEM 访问控制。清单记录源 ISO、目标系统、版本索引、架构、创建时间与状态；修改日志写入目录内的 `WinUtil_ISO.log`。所需空间与耗时取决于源镜像、展开后的镜像、驱动和输出文件，没有固定的压缩后容量或节省空间保证。

`Invoke-WinUtilISOCheckExistingWork` 只检查**当前会话已持有且标记 Completed 的工作目录**。工具不再扫描旧 TEMP 目录推断任务归属或完成状态。制作失败后保留目录供检查，清理入口独立于成功输出区域；清理只卸载本次 `wim_mount` / `boot_mount`，校验目录、清单与链接后删除本次工作副本。程序只主动卸载本次自行挂载的源 ISO。

保存 ISO 前再次检查 Completed 状态，禁止覆盖源 ISO 或把输出写进将被清理的工作目录。工具优先查找本机 OSCDIMG，缺失时询问是否通过 WinGet 安装；成功要求进程退出码为 0 且输出文件非空。默认文件名为 `Win10_Modified_yyyyMMdd.iso` 或 `Win11_Modified_yyyyMMdd.iso`。

写入 U 盘前检查当前磁盘的 UniqueId、序列号、编号、容量、USB 类型与系统 / 启动盘标记，并要求用户确认擦除。随后创建 GPT 和不超过约 32 GB 的 FAT32 分区，面向 UEFI 启动；较大的 `install.wim` 分割为 SWM，其余超过 FAT32 单文件限制的文件会在擦除前拒绝。原生复制与格式化操作会检查退出码，容量检查同时在擦除前和复制前进行。

以上描述是代码路径与保护措施；静态校验、模拟测试及界面预览不能替代真实镜像导出、USB 启动和目标设备安装验证。用户操作说明见 [Windows 10 / 11 镜像指南](https://github.com/yasewang1337-svg/winutil-cn/blob/main/docs/content/userguide/win11Creator/_index.md)。

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

- [贡献指南](https://github.com/yasewang1337-svg/winutil-cn/blob/main/docs/content/CONTRIBUTING.md) —— 如何贡献代码
- [用户指南](https://github.com/yasewang1337-svg/winutil-cn/blob/main/docs/content/userguide/_index.md) —— 面向最终用户的文档
- [Windows 镜像指南](https://github.com/yasewang1337-svg/winutil-cn/blob/main/docs/content/userguide/win11Creator/_index.md) —— 制作 Windows 10 / 11 x64 安装介质
- [FAQ](https://github.com/yasewang1337-svg/winutil-cn/blob/main/docs/content/faq.md) —— 常见问题

## 更多资源

- **GitHub 仓库**：[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)
- **PowerShell 文档**：[Microsoft Docs](https://docs.microsoft.com/powershell/)
- **WPF 指南**：[WPF Documentation](https://docs.microsoft.com/dotnet/desktop/wpf/)

---

**最后更新**：2026 年 1 月
**维护者**：Chris Titus Tech 及贡献者
