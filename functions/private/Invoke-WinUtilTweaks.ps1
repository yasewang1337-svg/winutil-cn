function Invoke-WinUtilTweaks {
    <#
    .SYNOPSIS Applies one tweak with a saved snapshot and an explicit result.
    .PARAMETER ApplyDefault
        Applies a toggle's configured off-state as a new recorded change, not historical undo.
    #>
    param($CheckBox, $undo = $false, $KeepServiceStartup = $true, [switch]$ApplyDefault)
    if ($undo) { return Restore-WinUtilTweakHistory -TweakId $CheckBox }
    $tweak = $sync.configs.tweaks.$CheckBox
    $result = [pscustomobject]@{ TweakId = $CheckBox; Name = $tweak.Content; Status = 'Failed'; Message = ''; HistoryId = $null }
    if (-not $tweak) { $result.Message = '找不到该优化项。'; return $result }
    $scriptName = 'InvokeScript'
    if ($ApplyDefault) { $scriptName = 'UndoScript' }
    $record = [pscustomobject]@{
        SchemaVersion = 1; Id = [guid]::NewGuid().ToString('N'); TweakId = $CheckBox; Name = $tweak.Content
        CreatedAt = [DateTime]::UtcNow.ToString('o'); Status = 'Pending'; Message = ''; Restored = $false
        LimitedRecovery = [bool]($tweak.$scriptName -or ($tweak.appx -and -not $ApplyDefault)); Entries = @()
    }
    $skippedServices = @()
    try {
        foreach ($entry in $tweak.registry) {
            $record.Entries += Get-WinUtilTweakRegistryState -Path $entry.Path -Name $entry.Name
        }
        foreach ($entry in $tweak.service) {
            $service = Get-Service -Name $entry.Name -ErrorAction Stop
            $startup = $service.StartType.ToString()
            if ($KeepServiceStartup -and -not $ApplyDefault -and $startup -ne $entry.OriginalType) {
                $skippedServices += $entry.Name
                continue
            }
            $delayed = Get-WinUtilTweakRegistryState -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($entry.Name)" -Name 'DelayedAutoStart'
            $record.Entries += [pscustomobject]@{ Kind = 'Service'; Name = $entry.Name; StartupType = $startup; DelayedAutoStart = $delayed; State = 'Pending' }
        }
        # Failure here stops the tweak before any changes are made.
        Save-WinUtilTweakHistory -Record $record
        $result.HistoryId = $record.Id
        foreach ($snapshot in $record.Entries) {
            $snapshot.State = 'Applying'
            Save-WinUtilTweakHistory -Record $record
            if ($snapshot.Kind -eq 'Registry') {
                $entry = $tweak.registry | Where-Object {
                    ($_.Path -replace '^HKU:', 'Registry::HKEY_USERS') -eq $snapshot.Path -and $_.Name -eq $snapshot.Name
                } | Select-Object -First 1
                $value = $entry.Value
                if ($ApplyDefault) { $value = $entry.OriginalValue }
                Set-WinUtilRegistry -Name $entry.Name -Path $entry.Path -Type $entry.Type -Value $value
            } else {
                $entry = $tweak.service | Where-Object Name -EQ $snapshot.Name | Select-Object -First 1
                $startup = $entry.StartupType
                if ($ApplyDefault) { $startup = $entry.OriginalType }
                Set-WinUtilService -Name $entry.Name -StartupType $startup
            }
            $snapshot.State = 'Applied'
            Save-WinUtilTweakHistory -Record $record
        }
        foreach ($script in $tweak.$scriptName) {
            # The previous wrapper swallowed errors and made failed scripts look successful.
            Invoke-Command -ScriptBlock ([scriptblock]::Create($script)) -ErrorAction Stop | Out-Host
        }
        if (-not $ApplyDefault) {
            foreach ($app in $tweak.appx) { Remove-WinUtilAPPX -Name $app -ErrorAction Stop | Out-Host }
        }
        $result.Status = 'Success'
        $result.Message = '设置已写入；可在操作历史中查看本次修改前的记录。'
        if ($record.LimitedRecovery) {
            $result.Status = 'Unverified'
            $result.Message = '脚本执行结束；其效果未逐项核验。仅登记的注册表值和服务启动配置支持历史恢复，应用、文件和其他脚本改动不在恢复范围内。'
        }
        if ($CheckBox -eq 'WPFTweaksRestorePoint') {
            $result.Status = 'Success'
            $result.Message = '已创建并确认新的系统还原点。系统还原需在 Windows 中操作。'
        }
        if ($skippedServices.Count) {
            $result.Status = 'Partial'
            $result.Message += " 保留已自定义的服务启动方式：$($skippedServices -join '、')。"
        }
        $record.Status = $result.Status; $record.Message = $result.Message
        Save-WinUtilTweakHistory -Record $record
    } catch {
        $result.Status = 'Failed'
        $result.Message = "操作中止：$($_.Exception.Message) 已尝试的设置可能部分生效，请查看操作历史。"
        $record.Status = 'Failed'; $record.Message = $result.Message
        if ($result.HistoryId) {
            try { Save-WinUtilTweakHistory -Record $record } catch { Write-Warning "保存执行结果失败；修改前快照仍保留。$($_.Exception.Message)" }
        }
        Write-Warning "$($result.Name)：$($result.Message)"
    }
    return $result
}
