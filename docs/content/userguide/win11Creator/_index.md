---
title: Win11 创建器
weight: 8
prev: /userguide/automation/
---

## 使用 Winutil 的 Win11 创建器

Winutil 内置了一个 **Win11 创建器（Win11 Creator）** 工具，让你能拿一份官方 Windows 11 ISO，产出一个自定义、已瘦身的版本。生成的镜像可以移除遥测、绕过硬件要求检查，并开箱即用地启用本地账户设置。你可以把结果导出为一个新的 ISO 文件，或直接写入 U 盘。

{{< image src="images/win11creator-tab-new" alt="Winutil 中的 Win11 创建器标签页" >}}

> [!IMPORTANT]
> 开始之前，你需要一份来自[微软官网](https://www.microsoft.com/en-us/software-download/windows11)的**官方 Windows 11 ISO**。不支持自定义、修改过或非官方的 ISO。整个过程会占用约 10–15 GB 的临时磁盘空间，请确保有足够空间。

> [!NOTE]
> 此流程面向全新安装 Windows，而非对现有安装进行就地升级。

---

### 第 1 步 —— 选择你的官方 Windows 11 ISO

1. 打开 Winutil，进入 **Win11 Creator（Win11 创建器）** 标签页。
2. 点击 **Browse（浏览）**，选择你来自微软的**官方 Windows 11 ISO 文件**（必须 4 GB 或更大）。不支持自定义或修改过的 ISO。
3. 选择后，文件路径和大小会显示在屏幕上。

---

### 第 2 步 —— 挂载并校验

1. 点击 **Mount & Verify ISO（挂载并校验 ISO）**。
2. Winutil 会挂载该 ISO，检查是否存在有效的 `install.wim` 或 `install.esd`，并读取可用的版本（家庭版、专业版、企业版等）。
3. 校验通过后，从下拉菜单中选择你想要的**版本**——如果可用，默认会选中专业版（Pro）。

> [!NOTE]
> 这一步大约需要 10–30 秒，取决于你的硬盘速度。

---

### 第 3 步 —— 运行修改

点击 **Run Windows ISO Modification and Creator（运行 Windows ISO 修改与创建）** 以开始自定义流程。Winutil 会：

**应用与组件移除：**
- **移除 40 多个捆绑应用** —— Clipchamp、Teams、Copilot、Dev Home、新版 Outlook、Bing 系应用、纸牌，等等
- 从镜像中**删除 OneDrive 安装程序**

**系统自定义：**
- **绕过硬件检查** —— 移除对 TPM、安全启动、CPU、内存和存储要求的强制，使该 ISO 能安装到不受支持的硬件上
- **启用本地账户设置** —— 注入一份 `autounattend.xml`，在 OOBE（开箱体验）期间跳过微软账户界面
- **禁用 BitLocker 和设备加密** —— 移除开机时的额外开销
- **禁用聊天图标** —— 移除任务栏上的聊天按钮
- **剔除未用的版本** —— 只保留你选中的版本，每移除一个版本可节省 1–2 GB
- **清理组件存储** —— 运行 DISM 清理，再回收 300–800 MB

**隐私与遥测优化：**
- **禁用遥测** —— 广告 ID、量身定制的体验、输入个性化、语音在线隐私
- **禁用云内容功能** —— 应用建议、Microsoft Store 推荐
- **移除遥测计划任务** —— CEIP、Appraiser、WaaSMedic 等
- **禁用 OneDrive 文件夹备份** —— 阻止自动备份到云端
- **阻止 DevHome 和 Outlook 在安装后被安装**
- **阻止 Teams 安装** —— 屏蔽 OOBE 之后的自动安装
- **阻止新版 Outlook 邮件应用安装**
- **在 OOBE 期间禁用 Windows 更新** —— 首次登录时自动重新启用
- **禁用 Copilot 和搜索框建议**

**可选：驱动注入**
- 如果启用，它会把你当前系统里的所有驱动注入到 install.wim 和 boot.wim ——对于在缺少驱动的机器上进行离线安装很有用。这是第 3 步中的一个可选复选框。

一个实时日志会随着每一步的完成展示进度。这个阶段通常需要 **10–30 分钟**，取决于磁盘速度。接近尾声的 WIM 卸载是最慢的部分，所以运行期间不要关闭 Winutil。

---

### 第 4 步 —— 导出你的成果

修改完成后，选择如何保存你的镜像：

{{< tabs >}}

  {{< tab name="另存为 ISO" selected=true >}}
  1. 点击 **Save as an ISO File（保存为 ISO 文件）**。
  2. 选择一个保存位置（默认是你的桌面，文件名为 `Win11_Modified_yyyyMMdd.iso`）。
  3. Winutil 使用 `oscdimg.exe` 构建一个 BIOS/UEFI 双启动的可引导 ISO。

  > [!NOTE]
  > 需要 `oscdimg.exe`（Windows ADK 的一部分）。如果找不到，Winutil 会尝试通过 winget 自动安装它。若失败，请手动安装：`winget install -e --id Microsoft.OSCDIMG`


  {{< /tab >}}

  {{< tab name="写入 U 盘" >}}
  1. 点击 **Write Directly to a USB Drive（直接写入 U 盘）**。
  2. 从下拉菜单中选择你的 U 盘（如果没出现，点击 **Refresh（刷新）**）。
  3. 点击 **Erase & Write to USB（擦除并写入 U 盘）** 并确认警告——**该 U 盘上的所有数据都将被永久擦除**。
  4. Winutil 会把 U 盘格式化为 GPT，带一个 512 MB 的 EFI 分区，并复制修改后的 Windows 文件。

  > [!WARNING]
  > 确认前，请再三核对你选的是正确的 U 盘。此操作无法撤销。

  **U 盘最小容量：** 建议 8 GB。写入需要 10–20 分钟。
  {{< /tab >}}

{{< /tabs >}}

---

### 第 5 步 —— 清理（可选）

点击 **Clean & Reset（清理并重置）**，删除临时工作目录（约 10–15 GB），并把工具恢复到初始状态，准备处理新的 ISO。删除任何东西之前，都会先请你确认。

---

### 修改后的 ISO 有何不同

当你用修改后的 ISO 安装 Windows 11 时：

- **无需微软账户** —— 在安装过程中直接创建本地账户
- **无硬件检查** —— 可安装到没有 TPM 2.0、安全启动或受支持 CPU 的机器上
- **默认启用深色模式**
- **空的任务栏和开始菜单** —— 没有固定的应用，聊天图标已移除
- **OOBE 期间禁用 Windows 更新** —— 首次登录时自动重新启用，避免打断安装
- **禁用 BitLocker** —— 移除首次启动时的额外开销

---

### 故障排查

| 问题 | 解决办法 |
|---------|-----|
| "install.wim not found"（找不到 install.wim） | 不是有效的 Windows 11 ISO —— 从微软重新下载一份 |
| "oscdimg.exe not found"（找不到 oscdimg.exe） | 运行 `winget install -e --id Microsoft.OSCDIMG` 后重试 |
| U 盘没出现 | 插好它，等几秒，然后点击 **Refresh（刷新）** |
| 修改似乎卡住了 | WIM 卸载这一步很慢——至少等 10 分钟，再判断它是否真的卡死 |
| "Access Denied"（拒绝访问）错误 | 确认 Winutil 是以管理员身份运行的 |

---

## 相关资源

- 从[微软](https://www.microsoft.com/en-us/software-download/windows11)下载官方 Windows 11 安装介质。
- 如果你更喜欢用别的工具来写入成品 ISO，常见选择包括 [Rufus](https://rufus.ie/) 或 [Ventoy](https://www.ventoy.net/)。

> [!NOTE]
> 始终从微软官方来源，或 Rufus/UUP Dump 这类可信工具下载 Windows ISO，以避免被篡改的镜像。

> [!NOTE]
> 较新的 Windows 11 ISO 在旧版本的 Ventoy 上可能无法正确启动——使用前请确保 Ventoy 已更新到最新。如果更新后问题依旧，这属于 Ventoy 的兼容性限制，超出了 Winutil 的控制范围。
