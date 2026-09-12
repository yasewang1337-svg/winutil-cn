function Get-WinUtilPackageExitResult {
    <#
    Exit-code sources:
    https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h
    https://docs.chocolatey.org/en-us/choco/commands/install/#exit-codes
    https://docs.chocolatey.org/en-us/choco/commands/uninstall/#exit-codes
    Unknown nonzero codes remain failures; localized console text is never parsed as success.
    #>
    param(
        [ValidateSet('Winget', 'Choco')][string]$Manager,
        [ValidateSet('Install', 'Uninstall', 'UpgradeAll')][string]$Action,
        [AllowNull()][Nullable[int]]$ExitCode
    )
    $status = 'Failed'
    $reason = '未取得进程退出码，无法确认操作结果。请查看日志后再决定是否重试。'
    $needsReboot = $false
    $hex = ''
    if ($null -ne $ExitCode) {
        $hex = '0x' + [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$ExitCode), 0).ToString('X8')
        $reason = "软件包管理器返回错误（$ExitCode / $hex）。请查看此项日志。"
        if ($ExitCode -eq 0) {
            $status = 'Succeeded'
            $reason = '软件包管理器报告操作成功。'
            if ($Action -eq 'UpgradeAll') { $reason = '整批更新命令执行成功；逐个软件的处理情况请查看日志。' }
        } elseif ($ExitCode -eq 3010 -or $ExitCode -eq 1641) {
            $status = 'RebootRequired'; $needsReboot = $true
            $reason = '软件包管理器报告成功，需要重启电脑完成更改。请先保存工作。'
        } elseif ($Manager -eq 'Choco') {
            if ($Action -eq 'Uninstall' -and $ExitCode -in @(1605, 1614)) {
                $status = 'Skipped'; $reason = '软件未安装或已经卸载，无需再次卸载。'
            } elseif ($ExitCode -in @(350, 1604)) {
                $needsReboot = $true; $reason = '电脑有待完成的重启，本次操作未完成。请保存工作、重启后重试。'
            }
        } else {
            switch ($hex) {
                '0x8A15002B' { $status = 'Skipped'; $reason = '没有适用的更新，已跳过。' }
                '0x8A150061' { $status = 'Skipped'; $reason = '软件已经安装，已跳过。' }
                '0x8A15010D' { $status = 'Skipped'; $reason = '软件已经安装，已跳过。' }
                '0x8A150109' { $status = 'RebootRequired'; $needsReboot = $true; $reason = '安装已完成，需要重启电脑才能生效。请先保存工作。' }
                '0x8A15010B' { $status = 'RebootRequired'; $needsReboot = $true; $reason = '安装程序报告已开始重启，请保存尚未保存的工作。' }
                '0x8A15010A' { $needsReboot = $true; $reason = '需要先重启电脑才能安装。本次尚未完成，请重启后重试。' }
                '0x8A150014' { $reason = '未找到匹配的软件。卸载时也可能是未安装；请检查软件列表和包编号。' }
                '0x8A150011' { $reason = '下载文件的校验不匹配，已停止。请稍后重试，不要跳过校验。' }
                '0x8A150008' { $reason = '下载失败，请检查网络连接后重试。' }
                '0x8A150107' { $reason = '网络不可用，请恢复网络连接后重试。' }
                '0x8A150045' { $reason = '无法连接软件源，请检查网络后重试。' }
                '0x8A150105' { $reason = '磁盘空间不足，请释放空间后重试。' }
                '0x8A150101' { $reason = '软件正在使用中，请关闭相关窗口后重试。' }
                '0x8A150102' { $reason = '另一个安装程序正在运行，请等待结束后重试。' }
                '0x8A150103' { $reason = '需要修改的文件正在使用中，请关闭相关程序后重试。' }
                '0x8A150019' { $reason = '此操作需要管理员权限，请以管理员身份重新打开工具。' }
                '0x8A15010C' { $reason = '安装已取消，未确认完成。' }
                '0x8A15002C' { $reason = '整批更新中存在失败项。请查看日志；未提供逐项结果，请勿将整批更新当作全部成功。' }
                '0x8A150050' { $status = 'Skipped'; $reason = '无法确认当前版本，已跳过；可使用软件自身的更新功能。' }
                '0x8A150068' { $status = 'Skipped'; $reason = '此软件已被固定版本，已跳过。' }
            }
        }
    }
    $labels = @{ Succeeded = '成功'; Failed = '失败'; Skipped = '已跳过'; RebootRequired = '需重启' }
    [pscustomobject]@{ Status = $status; StatusText = $labels[$status]; Reason = $reason; NeedsReboot = $needsReboot; ExitCodeHex = $hex }
}
