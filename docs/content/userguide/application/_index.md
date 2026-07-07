---
title: 应用
weight: 3
prev: /userguide/getting-started/
next: /userguide/tweaks/
---

在「应用（Applications）」标签页里，你可以在一个地方完成对受支持应用的安装、升级、卸载和查看。Winutil 依赖包管理器来完成这些操作，因此可用的结果取决于 WinGet 能在你系统上检测和管理到什么。

{{< tabs >}}

  {{< tab name="安装与更新" selected=true >}}
    * 选择你想安装或升级的应用。
        * 对于当前尚未安装的程序，此操作会安装它们。
        * 对于已经安装的程序，此操作会将它们更新到最新版本。
    * 点击 `Install/Upgrade Selected`（安装/升级所选）按钮，开始安装或升级流程。

    {{< image src="images/install-pics/installation" alt="安装或升级所选应用" >}}
  {{< /tab >}}

  {{< tab name="全部升级" >}}
    * 直接按下 `Upgrade All`（全部升级）按钮。
    * 这会升级每一个受支持的已安装程序，无需逐个勾选。

    {{< image src="images/install-pics/install-apps" alt="升级全部应用" >}}
  {{< /tab >}}

  {{< tab name="卸载" >}}
    * 选择你想卸载的程序。
    * 点击 `Uninstall Selected`（卸载所选）按钮将其移除。

    {{< image src="images/install-pics/uninstall-apps" alt="卸载所选应用" >}}
  {{< /tab >}}

  {{< tab name="显示已安装应用" >}}
    * 点击 `Show Installed Apps`（显示已安装应用）按钮。
    * 这会扫描并选中 WinGet 支持的已安装应用。

    {{< image src="images/install-pics/show-installed-apps" alt="显示已安装应用" >}}
  {{< /tab >}}

  {{< tab name="清除选择" >}}
    * 点击 `Clear Selection`（清除选择）按钮。
    * 这会清空当前所有的勾选。

    {{< image src="images/install-pics/clear-selection-apps" alt="清除应用勾选" >}}
  {{< /tab >}}
{{< /tabs >}}

> [!TIP]
> 如果你找不到某个应用，按 `Ctrl + F` 搜索它的名称。列表会随着你的输入实时筛选。

> [!NOTE]
> `Show Installed Apps`（显示已安装应用）只会选中 WinGet 能识别的软件。通过非受支持来源安装的应用可能不会出现。

> [!IMPORTANT]
> 在卸载或升级应用之前，请先关闭正在运行的程序。某些包可能仍会要求输入，或在其来源不可用时失败。
