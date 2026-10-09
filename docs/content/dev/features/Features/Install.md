---
title: "安装/启用所选功能"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: features/WPFFeatureInstall; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFFeatureInstall`
- 当前分类：功能
- 源配置：`config/feature.json`
- 源配置 SHA-256：`56ea30c4ec708287321e017ee42c1e6316d3d197cafba238138466e020d5d4f5`

## 配置定义

```json
{
  "WPFFeatureInstall": {
    "Content": "安装/启用所选功能",
    "category": "功能",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFeatureInstall",
    "link": "https://winutil.christitus.com/dev/features/features/install"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFFeatureInstall.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFFeatureInstall {
    <# Installs the reviewed selection and always releases the shared task state. #>
    if ($sync.ProcessRunning) {
        Write-Warning '当前有任务正在运行，请等待结束后再安装 Windows 功能。'
        return
    }
    $features = @($sync.selectedFeatures)
    if (-not $features.Count) { Write-Warning '请先选择要安装的 Windows 功能。'; return }

    # Create delegates on the UI runspace; the worker only publishes data.
    $sync.FeatureProgressValue = 0.01
    $sync.FeatureOperationError = ''
    $sync.FeatureProgressAction = [action]{
        Set-WinUtilTaskbaritem -state 'Normal' -value $sync.FeatureProgressValue -overlay 'logo'
    }
    $sync.FeatureFinishedAction = [action]{
        if ($sync.FeatureOperationError) {
            Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
            Show-WinUtilTweakDialog -Title 'Windows 功能安装未完成' -Message ("$($sync.FeatureOperationError)`n已执行的功能可能部分生效，请查看控制台日志后重试。") | Out-Null
        } else {
            Set-WinUtilTaskbaritem -state 'None' -overlay 'checkmark'
            Write-Host 'Windows 功能处理结束；部分更改可能需要重启。'
        }
    }
    # Reserve before dispatch so repeated clicks cannot queue another installation.
    $sync.ProcessRunning = $true
    try {
        $null = Invoke-WPFRunspace -ParameterList (, @('Features', $features)) -ScriptBlock {
            param([string[]]$Features)
            try {
                $sync.Form.Dispatcher.Invoke($sync.FeatureProgressAction)
                for ($index = 0; $index -lt $Features.Count; $index++) {
                    Invoke-WinUtilFeatureInstall $Features[$index]
                    $sync.FeatureProgressValue = ($index + 1) / [double]$Features.Count
                    $sync.Form.Dispatcher.Invoke($sync.FeatureProgressAction)
                }
            } catch {
                $sync.FeatureOperationError = $_.Exception.Message
                Write-Warning "Windows 功能安装未完成：$($sync.FeatureOperationError)"
            } finally {
                try { $sync.Form.Dispatcher.Invoke($sync.FeatureFinishedAction) }
                catch { Write-Warning "无法显示 Windows 功能安装结果：$($_.Exception.Message)" }
                finally { $sync.ProcessRunning = $false }
            }
        } -ErrorAction Stop
    } catch {
        $sync.FeatureOperationError = "无法启动后台任务：$($_.Exception.Message)"
        Write-Warning $sync.FeatureOperationError
        try { $sync.FeatureFinishedAction.Invoke() }
        catch { Write-Warning "无法显示 Windows 功能安装结果：$($_.Exception.Message)" }
        finally { $sync.ProcessRunning = $false }
    }
}
```
