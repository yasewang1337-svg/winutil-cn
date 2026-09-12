function Restore-WinUtilTweakHistory {
    <# .SYNOPSIS Restores the latest recorded values, never guessed configuration defaults. #>
    param([string]$TweakId)
    $tweak = $sync.configs.tweaks.$TweakId
    $result = [pscustomobject]@{ TweakId = $TweakId; Name = $tweak.Content; Status = 'Skipped'; Message = ''; HistoryId = $null }
    $record = Get-WinUtilTweakHistory -TweakId $TweakId | Where-Object { -not $_.Restored } | Select-Object -First 1
    if (-not $record) {
        $result.Message = '没有本工具记录的修改前状态，已跳过。不会用通用默认值覆盖你的设置。'
        Write-Warning "$($result.Name)：$($result.Message)"
        return $result
    }
    $result.HistoryId = $record.Id
    try {
        $entries = @($record.Entries)
        [array]::Reverse($entries)
        foreach ($entry in $entries) {
            if ($entry.State -notin @('Applying', 'Applied')) { continue }
            if ($entry.Kind -eq 'Registry') {
                $allowed = @($tweak.registry | Where-Object {
                    ($_.Path -replace '^HKU:', 'Registry::HKEY_USERS') -eq $entry.Path -and $_.Name -eq $entry.Name
                })
                if (-not $allowed.Count) { throw "当前配置不再包含记录项 $($entry.Name)，请手动核对。" }
                $value = '<RemoveEntry>'
                if ($entry.Exists) { $value = $entry.Value }
                Set-WinUtilRegistry -Path $entry.Path -Name $entry.Name -Type $entry.ValueType -Value $value -LiteralValue:([bool]$entry.Exists)
            } elseif ($entry.Kind -eq 'Service') {
                if ($entry.Name -notin @($tweak.service | ForEach-Object Name)) { throw "当前配置不再包含服务 $($entry.Name)。" }
                Set-WinUtilService -Name $entry.Name -StartupType $entry.StartupType
                $delayed = $entry.DelayedAutoStart
                $value = '<RemoveEntry>'
                if ($delayed.Exists) { $value = $delayed.Value }
                Set-WinUtilRegistry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Name)" -Name 'DelayedAutoStart' -Type $delayed.ValueType -Value $value -LiteralValue:([bool]$delayed.Exists)
            } else { throw '记录包含不支持的设置类型。' }
            $entry.State = 'Restored'
            Save-WinUtilTweakHistory -Record $record
        }
        $record.Restored = $true
        $result.Status = 'Success'
        $result.Message = '已恢复本次记录中的注册表值和服务启动配置；新增的空注册表键会保留。'
        if ($record.LimitedRecovery) {
            $result.Status = 'Partial'
            $result.Message = '已恢复有快照的设置；应用、文件及脚本的其他改动未恢复。需要时请使用 Windows 系统还原或重新安装相关应用。'
        }
        if (-not @($record.Entries | Where-Object State -EQ 'Restored').Count) {
            $result.Status = 'Skipped'
            $result.Message = '这条记录没有已尝试的可恢复设置，未修改当前系统。应用、文件及脚本的其他改动需要手动处理。'
        }
        $record.Status = 'Restored'; $record.Message = $result.Message
        Save-WinUtilTweakHistory -Record $record
    } catch {
        $result.Status = 'Failed'
        $result.Message = "恢复未完成：$($_.Exception.Message) 可修复原因后重试，已恢复项会跳过。"
    }
    return $result
}
