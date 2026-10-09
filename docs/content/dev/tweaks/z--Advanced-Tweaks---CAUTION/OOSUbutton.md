---
title: "运行 O&O ShutUp10++（隐私工具）"
description: "当前源配置生成的开发参考"
generated: true
---

<!-- winutil-devdocs: tweaks/WPFOOSUbutton; schema=1 -->

> 本页由 tools/devdocs-generator.ps1 生成，请修改源配置或函数后重新生成。目录保留历史 URL，实际分类以本页为准。

- 稳定 ID：`WPFOOSUbutton`
- 当前分类：z__高级优化 - 谨慎
- 源配置：`config/tweaks.json`
- 源配置 SHA-256：`09ebd3bfcdbb4a45f67506a5c926f7f468d1da38a2a95e8accaa0d9f7e062fa9`

本页描述实现，不代表推荐勾选。历史恢复仅覆盖工具实际记录的设置；配置中的 OriginalValue / OriginalType 不等于这台电脑的修改前状态。应用、文件及脚本其他改动不保证可恢复。

## 配置定义

```json
{
  "WPFOOSUbutton": {
    "Content": "运行 O&O ShutUp10++（隐私工具）",
    "category": "z__高级优化 - 谨慎",
    "panel": "1",
    "Type": "Button",
    "link": "https://winutil.christitus.com/dev/tweaks/z--advanced-tweaks---caution/oosubutton"
  }
}
```

## 入口函数

来源：`functions/public/Invoke-WPFOOSU.ps1`。这里只展示入口，其他被调用函数以仓库源码为准。

```powershell
function Invoke-WPFOOSU {
    if ($sync.OOSURunning) {
        Write-Warning 'O&O ShutUp10++ 正在准备或运行，请先关闭已打开的工具。'
        return
    }

    # Reserve before the modal dialog as it can process another button click.
    $sync.OOSURunning = $true
    try {
        $message = @'
将从 O&O 官方下载域名 dl5.oo-software.com 获取 ShutUp10++，验证有效数字签名及 O&O Software GmbH 发布者后，以当前管理员权限打开。

WinUtil 不会自动选择或应用 O&O 设置。请在第三方工具中了解影响后自行选择；其中改动无法通过 WinUtil 的操作历史恢复。

关闭 O&O 后会清理本次下载的临时文件。是否继续下载并打开？
'@
        if (-not (Show-WinUtilTweakDialog -Title '下载并打开 O&O ShutUp10++' -Message $message -Confirm)) {
            $sync.OOSURunning = $false
            return
        }
    } catch {
        $sync.OOSURunning = $false
        Write-Warning "无法确认 O&O ShutUp10++ 操作，尚未开始下载。$($_.Exception.Message)"
        return
    }

    # Create the delegate on the UI runspace; workers pass an immutable error snapshot.
    $sync.OOSUErrorAction = [action[string]] {
        param($Message)
        $null = Show-WinUtilTweakDialog -Title 'O&O ShutUp10++ 启动失败' -Message $Message
    }
    try {
        $null = Invoke-WPFRunspace -ErrorAction Stop -ScriptBlock {
            try {
                Write-Host '正在下载并验证 O&O ShutUp10++；验证通过后将打开工具。'
                $null = Invoke-WinUtilVerifiedTool -Tool OOSU -ErrorAction Stop
            } catch {
                $message = "O&O ShutUp10++ 未成功完成。`r`n$($_.Exception.Message)"
                Write-Warning $message
                if ($sync.Form) {
                    try {
                        # Do not make a worker wait for a dialog or a closing UI thread.
                        $null = $sync.Form.Dispatcher.BeginInvoke(
                            [action[string]]$sync.OOSUErrorAction, [object[]]@($message)
                        )
                    } catch {
                        Write-Warning "无法显示 O&O 错误窗口：$($_.Exception.Message)"
                    }
                }
            } finally {
                $sync.OOSURunning = $false
            }
        }
    } catch {
        $sync.OOSURunning = $false
        $message = "无法启动 O&O ShutUp10++ 后台任务。`r`n$($_.Exception.Message)"
        Write-Warning $message
        if ($sync.Form) {
            $null = Show-WinUtilTweakDialog -Title 'O&O ShutUp10++ 启动失败' -Message $message
        }
    }
}
```
