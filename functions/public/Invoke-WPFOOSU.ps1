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
