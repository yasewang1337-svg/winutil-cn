---
title: "pip 恢复官方"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorPipReset; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorPipReset`
- 当前分类：换源 · 恢复官方源
- 源配置：`config/feature.json`
- 源配置 SHA-256：`6460128039e8fab2f6e81d750496f65cc7ca181cc0dbf062c7de56c813e31777`
- 固定动作：`Mirror.Pip.Official`

移除 pip 的 global.index-url 与 global.trusted-host 设置，使用其余配置或默认源；不会还原此前自定义地址。

## 配置定义

```json
{
  "WPFFeatureMirrorPipReset": {
    "Content": "pip 恢复官方",
    "Description": "移除 pip 的 global.index-url 与 global.trusted-host 设置，使用其余配置或默认源；不会还原此前自定义地址。",
    "category": "换源 · 恢复官方源",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "Action": "Mirror.Pip.Official"
  }
}
```

## 入口函数

来源：`functions/private/Invoke-WinUtilFeatureAction.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WinUtilFeatureAction {
    <# Fixed system-panel targets and mirror operations; no script text from JSON. #>
    param([Parameter(Mandatory)][string]$Action)
    $systemDirectory = [Environment]::SystemDirectory
    switch -CaseSensitive -Exact ($Action) {
        'Panel.Control' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ErrorAction Stop }
        'Panel.Computer' { Start-Process -FilePath (Join-Path $systemDirectory 'mmc.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'compmgmt.msc')) -ErrorAction Stop }
        'Panel.Network' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'ncpa.cpl')) -ErrorAction Stop }
        'Panel.Power' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'powercfg.cpl')) -ErrorAction Stop }
        'Panel.Printer' { Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}' -ErrorAction Stop }
        'Panel.Region' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'intl.cpl')) -ErrorAction Stop }
        'Panel.Restore' { Start-Process -FilePath (Join-Path $systemDirectory 'rstrui.exe') -ErrorAction Stop }
        'Panel.Sound' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'mmsys.cpl')) -ErrorAction Stop }
        'Panel.System' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'sysdm.cpl')) -ErrorAction Stop }
        'Panel.Timedate' { Start-Process -FilePath (Join-Path $systemDirectory 'control.exe') -ArgumentList ('"{0}"' -f (Join-Path $systemDirectory 'timedate.cpl')) -ErrorAction Stop }
        'Mirror.Pip.CN' { Invoke-WinUtilMirrorAction -Tool Pip }
        'Mirror.Pip.Official' { Invoke-WinUtilMirrorAction -Tool Pip -Reset }
        'Mirror.Npm.CN' { Invoke-WinUtilMirrorAction -Tool Npm }
        'Mirror.Npm.Official' { Invoke-WinUtilMirrorAction -Tool Npm -Reset }
        'Mirror.Yarn.CN' { Invoke-WinUtilMirrorAction -Tool Yarn }
        'Mirror.Yarn.Official' { Invoke-WinUtilMirrorAction -Tool Yarn -Reset }
        'Mirror.Conda.CN' { Invoke-WinUtilMirrorAction -Tool Conda }
        'Mirror.Conda.Official' { Invoke-WinUtilMirrorAction -Tool Conda -Reset }
        'Mirror.Go.CN' { Invoke-WinUtilMirrorAction -Tool Go }
        'Mirror.Go.Official' { Invoke-WinUtilMirrorAction -Tool Go -Reset }
        default { throw "不支持的按钮动作：$Action。" }
    }
}
```
