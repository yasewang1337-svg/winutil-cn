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
- 源配置 SHA-256：`3e7f3f2dc0b37b3a858d3faf8151aa53c1ffd5a9bc1baa24e82ad364a5a28952`

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

    # Create the delegate on the UI runspace; workers pass an immutable error snapshot.
    $sync.OOSUErrorAction = [action[string]] {
        param($Message)
        $null = Show-WinUtilTweakDialog -Title 'O&O ShutUp10++ 启动失败' -Message $Message
    }
    # Reserve only this tool before dispatch so rapid clicks cannot start another copy.
    $sync.OOSURunning = $true
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
