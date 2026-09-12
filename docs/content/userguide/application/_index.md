---
title: 应用
weight: 3
prev: /userguide/getting-started/
next: /userguide/tweaks/
---

在软件页面集中选择需要的应用，查看计划后安装、更新或卸载。WinUtil CN 通过 WinGet 或 Chocolatey 执行，实际可用性取决于软件源、安装程序和本机状态。

以下旧截图帮助识别相应功能区域；当前版本会先显示操作计划，再返回执行结果，按钮名称与截图可能不同。

{{< tabs >}}

  {{< tab name="安装与更新" selected=true >}}
    * 选择你想安装或升级的应用。
        * 对于当前尚未安装的程序，此操作会安装它们。
        * 对于已经安装的程序，由包管理器判断可用更新或跳过。
    * 点击安装/升级所选按钮，核对弹出的软件清单与操作范围后确认执行。

    {{< image src="images/screenshots/install-pics/installation" alt="安装或升级所选应用" >}}
  {{< /tab >}}

  {{< tab name="全部升级" >}}
    * 打开“查看全部升级操作”，先阅读范围说明再确认。
    * 此入口尝试升级包管理器可识别的软件，范围不限当前勾选；未知版本、固定版本等情况可能被跳过。它只提供整批结果和日志，不是逐软件待更新列表。

    {{< image src="images/screenshots/install-pics/install-apps" alt="升级全部应用" >}}
  {{< /tab >}}

  {{< tab name="卸载" >}}
    * 选择你想卸载的程序。
    * 点击卸载所选按钮，核对清单后确认移除。

    {{< image src="images/screenshots/install-pics/uninstall-apps" alt="卸载所选应用" >}}
  {{< /tab >}}

  {{< tab name="显示已安装应用" >}}
    * 点击“显示已装应用”按钮。
    * 扫描当前所选包管理器可识别、且能匹配软件目录的已安装项目。

    {{< image src="images/screenshots/install-pics/show-installed-apps" alt="显示已安装应用" >}}
  {{< /tab >}}

  {{< tab name="清除选择" >}}
    * 点击 `Clear Selection`（清除选择）按钮。
    * 这会清空当前所有的勾选。

    {{< image src="images/screenshots/install-pics/clear-selection-apps" alt="清除应用勾选" >}}
  {{< /tab >}}
{{< /tabs >}}

## 查看结果与重试

所选软件的安装或卸载会逐项显示成功、失败、跳过或需要重启，以及包管理器返回的原因。存在失败项时可以仅重试失败项，已成功的软件不会在这次重试中重复处理。结果以退出码为依据，不代表所有应用内部功能都已验证。

结果窗口可打开日志目录 `%LOCALAPPDATA%\WinUtil-CN\Logs\Packages`。更新或卸载不提供自动版本回退；需要重启时先保存工作，再按提示处理。

> [!TIP]
> 如果你找不到某个应用，按 `Ctrl + F` 搜索它的名称。列表会随着你的输入实时筛选。

> [!NOTE]
> “显示已装应用”使用偏好中选择的 WinGet 或 Chocolatey；无法被该包管理器识别或未匹配软件目录的应用可能不会出现。

> [!IMPORTANT]
> 在卸载或升级应用之前，请先关闭正在运行的程序。某些包可能仍会要求输入，或在其来源不可用时失败。
