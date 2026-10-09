---
title: "npm 恢复官方"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureMirrorNpmReset; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureMirrorNpmReset`
- 当前分类：换源 · 恢复官方源
- 源配置：`config/feature.json`
- 源配置 SHA-256：`956400006e36b3841c7816500199907bb57de94c98a0f05b1e9ee4737a8ab03c`
- 固定动作：`Mirror.Npm.Official`

恢复 npm 官方源 registry.npmjs.org。

## 配置定义

```json
{
  "WPFFeatureMirrorNpmReset": {
    "Content": "npm 恢复官方",
    "Description": "恢复 npm 官方源 registry.npmjs.org。",
    "category": "换源 · 恢复官方源",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "Action": "Mirror.Npm.Official"
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
